-- Converges a database created before supabase/migrations existed.
--
-- 0001 is written as a fresh install and uses `create table if not exists`,
-- which does nothing to a table that already exists but is missing columns.
-- The production database was created by hand, so it has profiles,
-- subscriptions and license_keys but not necessarily every column the site
-- now writes. This adds whatever is absent. It is safe to run repeatedly and
-- on a database that 0001 already created.

-- ------------------------------------------------------------- subscriptions
alter table public.subscriptions
  add column if not exists plan                   text default 'free',
  add column if not exists status                 text default 'active',
  add column if not exists stripe_customer_id     text,
  add column if not exists stripe_subscription_id text,
  add column if not exists current_period_start   timestamptz,
  add column if not exists current_period_end     timestamptz,
  add column if not exists cancel_at_period_end   boolean not null default false,
  add column if not exists created_at             timestamptz not null default now(),
  add column if not exists updated_at             timestamptz not null default now();

-- One subscription per user, so upserts and lookups stay unambiguous.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'subscriptions_user_id_key'
  ) then
    alter table public.subscriptions add constraint subscriptions_user_id_key unique (user_id);
  end if;
end $$;

create index if not exists subscriptions_customer_idx
  on public.subscriptions (stripe_customer_id);

-- -------------------------------------------------------------- license keys
alter table public.license_keys
  add column if not exists plan         text default 'free',
  add column if not exists is_active    boolean not null default true,
  add column if not exists activated_at timestamptz,
  add column if not exists last_seen_at timestamptz,
  add column if not exists created_at   timestamptz not null default now(),
  add column if not exists updated_at   timestamptz not null default now();

-- Existing rows may predate generated keys.
update public.license_keys
   set key = public.generate_license_key()
 where key is null or key = '';

create index if not exists license_keys_user_idx on public.license_keys (user_id);
create index if not exists license_keys_key_idx  on public.license_keys (key);

-- ------------------------------------------------------------------ profiles
alter table public.profiles
  add column if not exists email      text,
  add column if not exists full_name  text,
  add column if not exists avatar_url text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create index if not exists profiles_email_idx on public.profiles (email);

-- Backfill profiles for anyone who signed up before the trigger existed, so
-- the webhook's email lookup can find them.
insert into public.profiles (id, email)
select u.id, u.email
  from auth.users u
  left join public.profiles p on p.id = u.id
 where p.id is null;

insert into public.subscriptions (user_id)
select u.id
  from auth.users u
  left join public.subscriptions s on s.user_id = u.id
 where s.user_id is null;
