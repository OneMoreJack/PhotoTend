create table public.marketing_rate_limit_events (
  id bigint generated always as identity primary key,
  email_hash text not null,
  source_hash text not null,
  occurred_at timestamptz not null default now(),
  constraint rate_limit_email_hash_length check (char_length(email_hash) = 64),
  constraint rate_limit_source_hash_length check (char_length(source_hash) = 64)
);

create index marketing_rate_limit_email_idx
  on public.marketing_rate_limit_events (email_hash, occurred_at desc);
create index marketing_rate_limit_source_idx
  on public.marketing_rate_limit_events (source_hash, occurred_at desc);

alter table public.marketing_rate_limit_events enable row level security;
revoke all on public.marketing_rate_limit_events from anon, authenticated;

create or replace function public.check_waitlist_rate_limit(
  input_email_hash text,
  input_source_hash text,
  window_seconds integer default 3600,
  email_limit integer default 3,
  source_limit integer default 20
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  window_start timestamptz := now() - make_interval(secs => window_seconds);
  email_attempts integer;
  source_attempts integer;
begin
  if char_length(input_email_hash) <> 64
    or char_length(input_source_hash) <> 64
    or window_seconds < 1
    or email_limit < 1
    or source_limit < 1 then
    return false;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(input_email_hash || input_source_hash, 0));

  delete from public.marketing_rate_limit_events
  where occurred_at < now() - interval '24 hours';

  select count(*) into email_attempts
  from public.marketing_rate_limit_events
  where email_hash = input_email_hash and occurred_at > window_start;

  select count(*) into source_attempts
  from public.marketing_rate_limit_events
  where source_hash = input_source_hash and occurred_at > window_start;

  if email_attempts >= email_limit or source_attempts >= source_limit then
    return false;
  end if;

  insert into public.marketing_rate_limit_events (email_hash, source_hash)
  values (input_email_hash, input_source_hash);

  return true;
end;
$$;

revoke all on function public.check_waitlist_rate_limit(text, text, integer, integer, integer)
  from public, anon, authenticated;
grant execute on function public.check_waitlist_rate_limit(text, text, integer, integer, integer)
  to service_role;
