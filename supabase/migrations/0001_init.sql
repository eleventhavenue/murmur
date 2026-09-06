-- Murmur cloud schema.
-- Apply with: supabase db push   (or paste into the Supabase SQL editor)
--
-- Three tables back the Pro tier: a profile per user, one subscription row per
-- user, and one license key per user that the desktop app exchanges for cloud
-- voice access. Everything is created automatically when a user signs up, so a
-- fresh signup already has a usable free-tier row.

-- ---------------------------------------------------------------- extensions
create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------- utilities
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Human-readable, unambiguous key: MURMUR-XXXX-XXXX-XXXX-XXXX.
-- Crockford-ish alphabet with I, L, O and U removed so keys can be read aloud
-- and typed without confusion.
create or replace function public.generate_license_key()
returns text
language plpgsql
as $$
declare
  alphabet constant text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  result text := 'MURMUR';
  i int;
begin
  for i in 1..16 loop
    if i % 4 = 1 then
      result := result || '-';
    end if;
    result := result || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
  end loop;
  return result;
end;
$$;

-- ------------------------------------------------------------------ profiles
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text,
  full_name  text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profiles_email_idx on public.profiles (email);

-- ------------------------------------------------------------- subscriptions
create table if not exists public.subscriptions (
  id                     uuid primary key default gen_random_uuid(),
  user_id                uuid not null unique references auth.users(id) on delete cascade,
  plan                   text not null default 'free'
                           check (plan in ('free', 'pro', 'pro_plus')),
  status                 text not null default 'active'
                           check (status in ('active', 'trialing', 'past_due', 'canceled', 'incomplete')),
  stripe_customer_id     text unique,
  stripe_subscription_id text unique,
  current_period_start   timestamptz,
  current_period_end     timestamptz,
  cancel_at_period_end   boolean not null default false,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

create index if not exists subscriptions_customer_idx on public.subscriptions (stripe_customer_id);

-- -------------------------------------------------------------- license keys
create table if not exists public.license_keys (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  key          text not null unique default public.generate_license_key(),
  plan         text not null default 'free'
                 check (plan in ('free', 'pro', 'pro_plus')),
  is_active    boolean not null default true,
  activated_at timestamptz,
  last_seen_at timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists license_keys_user_idx on public.license_keys (user_id);
create index if not exists license_keys_key_idx  on public.license_keys (key);

-- ------------------------------------------------------------ webhook events
-- Stripe retries webhooks. Recording processed event ids makes handling
-- idempotent, so a retry cannot issue a second license key.
create table if not exists public.webhook_events (
  id           text primary key,
  type         text not null,
  processed_at timestamptz not null default now()
);

-- ------------------------------------------------------------------ triggers
drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists subscriptions_updated_at on public.subscriptions;
create trigger subscriptions_updated_at before update on public.subscriptions
  for each row execute function public.set_updated_at();

drop trigger if exists license_keys_updated_at on public.license_keys;
create trigger license_keys_updated_at before update on public.license_keys
  for each row execute function public.set_updated_at();

-- Every new auth user gets a profile, a free subscription and a license key.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;

  insert into public.subscriptions (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  insert into public.license_keys (user_id, plan, is_active)
  values (new.id, 'free', true);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------- RLS
-- Users read their own rows and nothing else. All writes happen server-side
-- through the service role key, which bypasses RLS.
alter table public.profiles      enable row level security;
alter table public.subscriptions enable row level security;
alter table public.license_keys  enable row level security;
alter table public.webhook_events enable row level security;

drop policy if exists "own profile readable" on public.profiles;
create policy "own profile readable" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "own profile updatable" on public.profiles;
create policy "own profile updatable" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "own subscription readable" on public.subscriptions;
create policy "own subscription readable" on public.subscriptions
  for select using (auth.uid() = user_id);

drop policy if exists "own license keys readable" on public.license_keys;
create policy "own license keys readable" on public.license_keys
  for select using (auth.uid() = user_id);

-- webhook_events is service-role only: no policies means no client access.
