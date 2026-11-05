-- Baseline tables. Privileged writes require server-side code; no client can
-- assign a role, change account status, or grant an entitlement.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text,
  avatar_url text,
  role text not null default 'user' check (role in ('user', 'admin')),
  account_status text not null default 'pending_verification'
    check (account_status in ('pending_verification', 'active', 'suspended', 'banned')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_login_at timestamptz
);
create index profiles_email_idx on public.profiles (lower(email));

create table public.user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  device_id uuid not null,
  platform text not null check (platform in ('android', 'ios', 'extension')),
  device_name text,
  app_version text,
  last_seen_at timestamptz not null default now(),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (user_id, device_id)
);
create index user_devices_user_idx on public.user_devices(user_id);

create table public.user_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  plan text not null default 'free' check (plan in ('free', 'premium')),
  status text not null default 'active' check (status in ('active', 'revoked', 'expired')),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.feature_flags (
  id uuid primary key default gen_random_uuid(),
  feature_key text not null unique,
  enabled boolean not null default false,
  minimum_plan text not null default 'free' check (minimum_plan in ('free', 'premium')),
  updated_at timestamptz not null default now()
);
create table public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references public.profiles(id),
  action text not null,
  target_user_id uuid references public.profiles(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index admin_audit_logs_created_idx on public.admin_audit_logs(created_at desc);

alter table public.profiles enable row level security;
alter table public.user_devices enable row level security;
alter table public.user_entitlements enable row level security;
alter table public.feature_flags enable row level security;
alter table public.admin_audit_logs enable row level security;

revoke all on public.profiles, public.user_devices, public.user_entitlements,
  public.feature_flags, public.admin_audit_logs from anon, authenticated;
grant select on public.profiles, public.user_devices, public.user_entitlements,
  public.feature_flags to authenticated;
grant update (display_name, avatar_url) on public.profiles to authenticated;

create policy profiles_read_own on public.profiles for select to authenticated
  using ((select auth.uid()) = id);
create policy profiles_edit_own on public.profiles for update to authenticated
  using ((select auth.uid()) = id and account_status = 'active')
  with check ((select auth.uid()) = id and account_status = 'active');
create policy devices_read_own on public.user_devices for select to authenticated
  using ((select auth.uid()) = user_id and exists
    (select 1 from public.profiles p where p.id = (select auth.uid()) and p.account_status = 'active'));
create policy entitlements_read_own on public.user_entitlements for select to authenticated
  using ((select auth.uid()) = user_id and exists
    (select 1 from public.profiles p where p.id = (select auth.uid()) and p.account_status = 'active'));
create policy flags_read_active on public.feature_flags for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.account_status = 'active'));

create function public.create_user_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, email, account_status)
    values (new.id, coalesce(new.email, ''),
      case when new.email_confirmed_at is null then 'pending_verification' else 'active' end);
  insert into public.user_entitlements (user_id) values (new.id);
  return new;
end;
$$;
revoke all on function public.create_user_profile() from public, anon, authenticated;
create trigger create_user_profile after insert on auth.users
  for each row execute function public.create_user_profile();

create function public.sync_user_email() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.profiles set email = coalesce(new.email, ''),
    account_status = case
      when account_status = 'pending_verification' and new.email_confirmed_at is not null
      then 'active' else account_status end,
    updated_at = now()
  where id = new.id;
  return new;
end;
$$;
revoke all on function public.sync_user_email() from public, anon, authenticated;
create trigger sync_user_email after update of email, email_confirmed_at on auth.users
  for each row execute function public.sync_user_email();
