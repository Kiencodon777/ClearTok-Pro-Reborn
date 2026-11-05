-- Run as the database owner after manually verifying the operator's user UUID.
-- Supply psql -v admin_id='UUID'. No default account or password is created.
begin;
update public.profiles set role = 'admin'
  where id = :'admin_id'::uuid and account_status = 'active';
insert into public.admin_audit_logs(admin_id,action,target_user_id)
  select id,'bootstrap_admin',id from public.profiles
  where id = :'admin_id'::uuid and role = 'admin' and account_status = 'active';
commit;
