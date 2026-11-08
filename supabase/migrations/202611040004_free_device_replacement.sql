-- Allow Free-plan users to automatically replace an active device that has been
-- inactive for more than 7 days (e.g., after reinstalling the app), preventing
-- permanent self-lockout while preserving the 1-active-device limit for active sessions.
create or replace function public.account_api(action text, payload jsonb default '{}') returns jsonb
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
