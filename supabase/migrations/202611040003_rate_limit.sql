create table public.api_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  bucket timestamptz not null,
  requests integer not null,
  primary key(user_id,bucket)
);
alter table public.api_usage enable row level security;
revoke all on public.api_usage from public, anon, authenticated;
create function public.check_api_rate() returns void
language plpgsql security definer set search_path = '' as $$
declare total integer;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  insert into public.api_usage(user_id,bucket,requests)
    values(auth.uid(),date_trunc('minute',now()),1)
    on conflict(user_id,bucket) do update set requests=public.api_usage.requests+1
    returning requests into total;
  if total > 120 then raise exception 'Rate limit exceeded' using errcode='42501'; end if;
  delete from public.api_usage where user_id=auth.uid() and bucket < now()-interval '1 hour';
end;
$$;
revoke all on function public.check_api_rate() from public, anon, authenticated;
