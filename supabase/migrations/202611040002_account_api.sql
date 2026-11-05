create function public.account_api(action text, payload jsonb default '{}') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor public.profiles;
  entitlement public.user_entitlements;
  device public.user_devices;
  result jsonb;
  maximum integer;
begin
  perform public.check_api_rate();
  select * into actor from public.profiles where id = auth.uid() for update;
  if actor.id is null or actor.account_status <> 'active' then
    raise exception 'Account unavailable' using errcode = '42501';
  end if;
  select * into entitlement from public.user_entitlements where user_id = actor.id;
  if payload ? 'feature' and actor.role <> 'admin' and not exists (
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
    maximum := case when actor.role = 'admin' then 10
      when entitlement.plan = 'premium' and entitlement.status = 'active'
        and (entitlement.expires_at is null or entitlement.expires_at > now()) then 5 else 1 end;
    if device.id is null and (select count(*) from public.user_devices
      where user_id = actor.id and is_active) >= maximum then
      raise exception 'Device limit reached' using errcode = '42501';
    end if;
    insert into public.user_devices(user_id, device_id, platform, device_name, app_version)
      values (actor.id, (payload->>'device_id')::uuid, payload->>'platform',
        left(payload->>'device_name', 100), left(payload->>'app_version', 40))
      on conflict (user_id, device_id) do update set last_seen_at = now();
    update public.profiles set last_login_at = now() where id = actor.id;
  elsif action = 'revoke_device' then
    update public.user_devices set is_active = false where user_id = actor.id
      and id = (payload->>'id')::uuid;
  elsif action <> 'current' then
    raise exception 'Unknown action' using errcode = '22023';
  end if;
  return jsonb_build_object('profile', to_jsonb(actor), 'entitlement', to_jsonb(entitlement),
    'effective_plan', case when entitlement.plan = 'premium' and entitlement.status = 'active'
      and (entitlement.expires_at is null or entitlement.expires_at > now()) then 'premium' else 'free' end,
    'devices', coalesce((select jsonb_agg(to_jsonb(d)) from public.user_devices d
      where d.user_id = actor.id), '[]'::jsonb),
    'features', coalesce((select jsonb_agg(to_jsonb(f)) from public.feature_flags f), '[]'::jsonb));
end;
$$;
revoke all on function public.account_api(text,jsonb) from public, anon;
grant execute on function public.account_api(text,jsonb) to authenticated;

create function public.admin_api(action text, payload jsonb default '{}') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  target uuid;
  result jsonb;
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
    values(actor,action,target, jsonb_build_object('source','admin_api'));
  return coalesce(result,'{"ok":true}'::jsonb);
end;
$$;
revoke all on function public.admin_api(text,jsonb) from public, anon;
grant execute on function public.admin_api(text,jsonb) to authenticated;

insert into public.feature_flags(feature_key,enabled,minimum_plan)
  values ('repost',true,'free'),('unlike',true,'free'),('unfollow',true,'free');
