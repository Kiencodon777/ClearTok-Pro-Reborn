-- Run only in staging as database owner. All fixture data is rolled back.
begin;
insert into auth.users(id,email,email_confirmed_at) values
('00000000-0000-4000-8000-0000000000a1','rls-a@test.invalid',now()),
('00000000-0000-4000-8000-0000000000b1','rls-b@test.invalid',now()),
('00000000-0000-4000-8000-0000000000c1','rls-admin@test.invalid',now());
update public.profiles set role='admin' where id='00000000-0000-4000-8000-0000000000c1';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-0000000000a1',true);
do $$
begin
  if (select count(*) from public.profiles) <> 1 then raise exception 'RLS ownership failed'; end if;
  update public.profiles set display_name='forbidden' where id='00000000-0000-4000-8000-0000000000b1';
  if found then raise exception 'Cross-user update succeeded'; end if;
  begin
    update public.profiles set role='admin';
    raise exception 'Role escalation succeeded';
  exception when insufficient_privilege then null; end;
  begin
    update public.user_entitlements set plan='premium';
    raise exception 'Premium escalation succeeded';
  exception when insufficient_privilege then null; end;
  begin
    perform public.admin_api('users');
    raise exception 'Admin authorization failed';
  exception when insufficient_privilege then null; end;
  perform public.account_api('register_device','{"device_id":"00000000-0000-4000-8000-0000000000a1","platform":"android"}');
  begin
    perform public.account_api('register_device','{"device_id":"00000000-0000-4000-8000-0000000000b1","platform":"ios"}');
    raise exception 'Device limit failed';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-0000000000c1',true);
select public.admin_api('premium','{"user_id":"00000000-0000-4000-8000-0000000000a1","plan":"premium","expires_at":"2000-01-01T00:00:00Z"}');
do $$
begin
  if jsonb_array_length(public.admin_api('logs')) < 1 then raise exception 'Audit insert missing'; end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-0000000000a1',true);
do $$
declare device uuid;
begin
  if public.account_api('current')->>'effective_plan' <> 'free' then raise exception 'Premium expiry failed'; end if;
  select id into strict device from public.user_devices;
  perform public.account_api('revoke_device',jsonb_build_object('id',device));
  begin
    perform public.account_api('register_device','{"device_id":"00000000-0000-4000-8000-0000000000a1","platform":"android"}');
    raise exception 'Revoked device accepted';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-0000000000c1',true);
select public.admin_api('status','{"user_id":"00000000-0000-4000-8000-0000000000a1","status":"suspended"}');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-0000000000a1',true);
do $$
begin
  begin
    perform public.account_api('current');
    raise exception 'Suspended account accepted';
  exception when insufficient_privilege then null; end;
end $$;
rollback;
select 'PASS: staging RLS, role/Premium denial, device limit/revoke, expiry, suspension and audit; fixtures rolled back' as result;
