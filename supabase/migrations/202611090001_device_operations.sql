create table public.account_operations (
  user_id uuid not null,
  operation_id uuid not null,
  device_id uuid not null,
  feature text not null,
  quota_day date not null,
  metered boolean not null,
  status text not null check (status in ('reserved','consumed','released')),
  primary key (user_id, operation_id),
  foreign key (user_id, device_id) references public.user_devices(user_id, device_id) on delete cascade
);
create index account_operations_quota_idx on public.account_operations(user_id, quota_day)
  where metered and status <> 'released';
alter table public.account_operations enable row level security;
revoke all on public.account_operations from public, anon, authenticated;

create function public.account_device_limit(p public.profiles, e public.user_entitlements)
returns integer language sql stable set search_path = '' as $$
  select case when p.role = 'admin' then 10
    when e.plan = 'premium' and e.status = 'active'
      and (e.expires_at is null or e.expires_at > now()) then 5 else 1 end;
$$;
revoke all on function public.account_device_limit(public.profiles, public.user_entitlements)
  from public, anon, authenticated;

create or replace function public.account_api(action text, payload jsonb default '{}') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor public.profiles;
  entitlement public.user_entitlements;
  device public.user_devices;
  op public.account_operations;
  op_id uuid;
  installation uuid;
  today date;
  remaining integer;
  maximum integer;
begin
  perform public.check_api_rate();
  select * into actor from public.profiles where id = auth.uid() for update;
  if actor.id is null or actor.account_status <> 'active' then
    raise exception 'Account unavailable' using errcode = '42501';
  end if;
  select * into entitlement from public.user_entitlements where user_id = actor.id;
  maximum := public.account_device_limit(actor, entitlement);
  today := (clock_timestamp() at time zone 'Asia/Ho_Chi_Minh')::date;
  if maximum = 1 then
    select greatest(0, 20 - count(*)) into remaining from public.account_operations
      where user_id = actor.id and quota_day = today and metered and status <> 'released';
  end if;
  if action <> 'settle_operation' and payload ? 'feature' and actor.role <> 'admin' and not exists (
    select 1 from public.feature_flags f where f.feature_key = payload->>'feature' and f.enabled
      and (f.minimum_plan = 'free' or (entitlement.plan = 'premium' and entitlement.status = 'active'
        and (entitlement.expires_at is null or entitlement.expires_at > now())))
  ) then raise exception 'Feature unavailable' using errcode = '42501'; end if;
  if action = 'register_device' then
    select * into device from public.user_devices where user_id = actor.id
      and device_id = (payload->>'device_id')::uuid;
    -- A revoked installation cannot silently reactivate itself.
    if device.id is not null and not device.is_active then
      raise exception 'Device revoked' using errcode = '42501';
    end if;
    if device.id is null and (select count(*) from public.user_devices
      where user_id = actor.id and is_active) >= maximum then
      -- Automatically deactivate stale devices inactive for > 7 days so Free users
      -- who reinstall the app are not permanently locked out.
      update public.user_devices
        set is_active = false
        where user_id = actor.id
          and is_active
          and last_seen_at < now() - interval '7 days';
      if (select count(*) from public.user_devices
        where user_id = actor.id and is_active) >= maximum then
        raise exception 'Device limit reached' using errcode = '42501';
      end if;
    end if;
    insert into public.user_devices(user_id, device_id, platform, device_name, app_version)
      values (actor.id, (payload->>'device_id')::uuid, payload->>'platform',
        left(payload->>'device_name', 100), left(payload->>'app_version', 40))
      on conflict (user_id, device_id) do update set last_seen_at = now(),
        platform = excluded.platform,
        device_name = coalesce(excluded.device_name, public.user_devices.device_name),
        app_version = coalesce(excluded.app_version, public.user_devices.app_version);
    update public.profiles set last_login_at = now() where id = actor.id;
  elsif action in ('reserve_operation','settle_operation') then
    installation := (payload->>'device_id')::uuid;
    op_id := (payload->>'operation_id')::uuid;
    if op_id is null or installation is null or coalesce(payload->>'feature','') = '' then
      raise exception 'Missing operation fields' using errcode = '22023';
    end if;
    select * into device from public.user_devices where user_id = actor.id
      and device_id = installation for update;
    if device.id is null or (action = 'reserve_operation' and not device.is_active) then
      raise exception 'Device unavailable' using errcode = '42501';
    end if;
    select * into op from public.account_operations where user_id = actor.id and operation_id = op_id;
    if found and (op.device_id <> installation or op.feature <> payload->>'feature') then
      raise exception 'Operation identity mismatch' using errcode = '22023';
    end if;
    if action = 'reserve_operation' and op.operation_id is null then
      if remaining = 0 then
        raise exception 'QUOTA_EXHAUSTED' using errcode = 'PT409';
      end if;
      insert into public.account_operations values
        (actor.id, op_id, installation, payload->>'feature', today, maximum = 1, 'reserved')
        returning * into op;
      remaining := remaining - 1;
    elsif action = 'settle_operation' then
      if op.operation_id is null or coalesce(payload->>'outcome','') not in ('consumed','released') then
        raise exception 'Invalid settlement' using errcode = '22023';
      end if;
      if op.status = 'reserved' then
        update public.account_operations set status = payload->>'outcome'
          where user_id = actor.id and operation_id = op_id returning * into op;
        if op.status = 'released' and op.metered and op.quota_day = today then
          remaining := remaining + 1;
        end if;
      elsif op.status <> payload->>'outcome' then
        raise exception 'Operation already settled' using errcode = '22023';
      end if;
    end if;
    return jsonb_build_object('status',op.status,'quota_remaining',remaining);
  elsif action = 'revoke_device' then
    update public.user_devices set is_active = false where user_id = actor.id
      and id = (payload->>'id')::uuid;
  elsif action <> 'current' then
    raise exception 'Unknown action' using errcode = '22023';
  end if;
  return jsonb_build_object('quota_remaining', remaining, 'profile', to_jsonb(actor), 'entitlement', to_jsonb(entitlement),
    'effective_plan', case when entitlement.plan = 'premium' and entitlement.status = 'active'
      and (entitlement.expires_at is null or entitlement.expires_at > now()) then 'premium' else 'free' end,
    'devices', coalesce((select jsonb_agg(to_jsonb(d)) from public.user_devices d
      where d.user_id = actor.id), '[]'::jsonb),
    'features', coalesce((select jsonb_agg(to_jsonb(f)) from public.feature_flags f), '[]'::jsonb));
end;
$$;
revoke all on function public.account_api(text,jsonb) from public, anon;
grant execute on function public.account_api(text,jsonb) to authenticated;

create or replace function public.admin_api(action text, payload jsonb default '{}') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  target uuid;
  result jsonb;
  device public.user_devices;
  maximum integer;
begin
  perform public.check_api_rate();
  if not exists (select 1 from public.profiles where id = actor
    and role = 'admin' and account_status = 'active') then
    raise exception 'Administrator required' using errcode = '42501';
  end if;
  if action = 'dashboard' then
    select jsonb_build_object('total_users',count(*),
      'new_users_7_days',count(*) filter (where created_at >= now()-interval '7 days'),
      'active_users',count(*) filter (where account_status='active'),
      'locked_users',count(*) filter (where account_status in ('suspended','banned')),
      'premium_users',(select count(*) from public.user_entitlements where plan='premium'
        and status='active' and (expires_at is null or expires_at>now())),
      'active_devices',(select count(*) from public.user_devices where is_active))
      into result from public.profiles;
  elsif action = 'users' then
    select coalesce(jsonb_agg(to_jsonb(p)), '[]'::jsonb) into result from
      (select * from public.profiles where email ilike '%' || left(coalesce(payload->>'search',''),100) || '%'
        order by created_at desc limit 100) p;
  elsif action = 'details' then
    target := (payload->>'user_id')::uuid;
    select jsonb_build_object('profile', to_jsonb(p),
      'entitlement', (select to_jsonb(e) from public.user_entitlements e where e.user_id = target),
      'devices', coalesce((select jsonb_agg(to_jsonb(d)) from public.user_devices d where d.user_id = target),'[]'::jsonb))
      into result from public.profiles p where p.id = target;
  elsif action = 'devices' then
    select coalesce(jsonb_agg(to_jsonb(d)), '[]'::jsonb) into result from
      (select * from public.user_devices order by last_seen_at desc limit 100) d;
  elsif action = 'entitlements' then
    select coalesce(jsonb_agg(to_jsonb(e)), '[]'::jsonb) into result from
      (select * from public.user_entitlements order by updated_at desc limit 100) e;
  elsif action = 'flags' then
    select coalesce(jsonb_agg(to_jsonb(f)), '[]'::jsonb) into result from public.feature_flags f;
  elsif action = 'logs' then
    select coalesce(jsonb_agg(to_jsonb(l)), '[]'::jsonb) into result from
      (select * from public.admin_audit_logs order by created_at desc limit 100) l;
  elsif action = 'status' then
    target := (payload->>'user_id')::uuid;
    if target = actor then raise exception 'Cannot change own status'; end if;
    if payload->>'status' not in ('active','suspended','banned') then raise exception 'Invalid status'; end if;
    update public.profiles set account_status = payload->>'status', updated_at = now() where id = target;
    if not found then raise exception 'User not found'; end if;
  elsif action = 'premium' then
    target := (payload->>'user_id')::uuid;
    if payload->>'plan' not in ('free','premium') then raise exception 'Invalid plan'; end if;
    update public.user_entitlements set plan = payload->>'plan', status = 'active',
      expires_at = nullif(payload->>'expires_at','')::timestamptz, updated_at = now() where user_id = target;
    if not found then raise exception 'Entitlement not found'; end if;
  elsif action = 'restore_device' then
    select user_id into target from public.user_devices where id = (payload->>'id')::uuid;
    select public.account_device_limit(p,e) into maximum from public.profiles p
      join public.user_entitlements e on e.user_id = p.id where p.id = target for update of p,e;
    select * into device from public.user_devices where id = (payload->>'id')::uuid for update;
    if not found or maximum is null then raise exception 'Device not found'; end if;
    if not device.is_active then
      if (select count(*) from public.user_devices where user_id = target and is_active) >= maximum then
        raise exception 'Device limit reached' using errcode = '42501', detail =
          (select coalesce(jsonb_agg(jsonb_build_object('device_name',d.device_name,'platform',d.platform)), '[]'::jsonb)::text
            from public.user_devices d where d.user_id = target and d.is_active);
      end if;
      update public.user_devices set is_active = true, last_seen_at = now() where id = device.id;
    end if;
  elsif action = 'revoke_device' then
    update public.user_devices set is_active = false where id = (payload->>'id')::uuid returning user_id into target;
    if not found then raise exception 'Device not found'; end if;
  elsif action = 'flag' then
    if payload->>'feature_key' !~ '^[a-z_]{1,60}$' then raise exception 'Invalid feature'; end if;
    insert into public.feature_flags(feature_key,enabled,minimum_plan)
      values(payload->>'feature_key',(payload->>'enabled')::boolean,payload->>'minimum_plan')
      on conflict (feature_key) do update set enabled = excluded.enabled,
        minimum_plan = excluded.minimum_plan, updated_at = now();
  else raise exception 'Unknown action' using errcode = '22023';
  end if;
  insert into public.admin_audit_logs(admin_id,action,target_user_id,metadata)
    values(actor,action,target, jsonb_strip_nulls(jsonb_build_object('source','admin_api','device_id',device.device_id)));
  return coalesce(result,'{"ok":true}'::jsonb);
end;
$$;
revoke all on function public.admin_api(text,jsonb) from public, anon;
grant execute on function public.admin_api(text,jsonb) to authenticated;
