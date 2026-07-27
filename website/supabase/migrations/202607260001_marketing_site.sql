create extension if not exists pgcrypto;

create table public.waitlist_entries (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  platform text not null check (platform in ('android', 'macos', 'ios')),
  locale text not null check (locale in ('zh-CN', 'en')),
  source text not null check (char_length(source) between 1 and 64),
  status text not null default 'active'
    check (status in ('active', 'unsubscribed', 'blocked')),
  consent_at timestamptz not null,
  last_email_sent_at timestamptz,
  unsubscribe_token_hash text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint waitlist_email_normalized
    check (email = lower(btrim(email))),
  constraint waitlist_email_length
    check (char_length(email) between 3 and 320)
);

create table public.releases (
  id uuid primary key default gen_random_uuid(),
  platform text not null check (platform in ('android', 'macos', 'ios')),
  version text not null check (char_length(version) between 1 and 64),
  storage_path text not null unique,
  checksum_sha256 text,
  status text not null default 'draft'
    check (status in ('draft', 'active', 'retired')),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (platform, version)
);

create unique index releases_one_active_platform
  on public.releases (platform)
  where status = 'active';

create table public.download_grants (
  id uuid primary key default gen_random_uuid(),
  waitlist_entry_id uuid not null
    references public.waitlist_entries(id) on delete cascade,
  release_id uuid not null
    references public.releases(id) on delete restrict,
  token_hash text not null unique,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint download_grant_expiry_after_creation
    check (expires_at > created_at)
);

create table public.download_events (
  id uuid primary key default gen_random_uuid(),
  download_grant_id uuid
    references public.download_grants(id) on delete set null,
  result text not null
    check (result in ('redirected', 'expired', 'revoked', 'invalid', 'missing_file')),
  request_fingerprint text,
  occurred_at timestamptz not null default now()
);

create table public.email_events (
  id uuid primary key default gen_random_uuid(),
  waitlist_entry_id uuid
    references public.waitlist_entries(id) on delete set null,
  provider_message_id text,
  provider_event_id text not null unique,
  event_type text not null
    check (event_type in (
      'sent',
      'delivered',
      'delivery_delayed',
      'failed',
      'bounced',
      'complained',
      'clicked',
      'suppressed'
    )),
  occurred_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index waitlist_entries_status_platform_idx
  on public.waitlist_entries (status, platform);
create index download_grants_entry_idx
  on public.download_grants (waitlist_entry_id);
create index download_grants_expiry_idx
  on public.download_grants (expires_at)
  where revoked_at is null;
create index download_events_grant_idx
  on public.download_events (download_grant_id, occurred_at desc);
create index email_events_message_idx
  on public.email_events (provider_message_id)
  where provider_message_id is not null;

alter table public.waitlist_entries enable row level security;
alter table public.releases enable row level security;
alter table public.download_grants enable row level security;
alter table public.download_events enable row level security;
alter table public.email_events enable row level security;

revoke all on public.waitlist_entries from anon, authenticated;
revoke all on public.releases from anon, authenticated;
revoke all on public.download_grants from anon, authenticated;
revoke all on public.download_events from anon, authenticated;
revoke all on public.email_events from anon, authenticated;

insert into storage.buckets (id, name, public, file_size_limit)
values ('releases', 'releases', false, 524288000)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit;
