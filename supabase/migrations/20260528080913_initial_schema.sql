-- Initial schema for healthlog-ai.
-- Creates profiles, bp_readings, meal_logs, subscriptions, usage_tracking.
-- Enables RLS with strict per-user isolation.
-- Auto-creates profile on user signup via trigger.
-- Schedules monthly cleanup of old usage_tracking rows via pg_cron.

create extension if not exists "pgcrypto";
create extension if not exists "pg_cron";

-- ============================================================================
-- profiles
-- ============================================================================
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- bp_readings
-- ============================================================================
create table public.bp_readings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  systolic int not null check (systolic between 40 and 300),
  diastolic int not null check (diastolic between 30 and 200),
  pulse int check (pulse between 20 and 250),
  notes text,
  image_url text,
  created_at timestamptz not null default now()
);
create index bp_readings_user_created_idx
  on public.bp_readings (user_id, created_at desc);

-- ============================================================================
-- meal_logs
-- ============================================================================
create table public.meal_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  description text,
  image_url text,
  estimated_calories int check (estimated_calories >= 0),
  raw_ai_response jsonb,
  created_at timestamptz not null default now()
);
create index meal_logs_user_created_idx
  on public.meal_logs (user_id, created_at desc);

-- ============================================================================
-- subscriptions
-- One row per user (enforced by unique(user_id)).
-- Writes only via service role (no insert/update/delete policies for users).
-- ============================================================================
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  stripe_customer_id text unique,
  stripe_subscription_id text unique,
  plan text not null default 'free'
    check (plan in ('free', 'basic', 'pro')),
  status text not null default 'active'
    check (status in ('active', 'canceled', 'past_due')),
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- usage_tracking
-- One row per (user, month). Lazy-created on first scan of a month.
-- Writes only via service role.
-- ============================================================================
create table public.usage_tracking (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  month text not null check (month ~ '^\d{4}-\d{2}$'),
  bp_scans_used int not null default 0 check (bp_scans_used >= 0),
  meal_scans_used int not null default 0 check (meal_scans_used >= 0),
  reset_at timestamptz,
  created_at timestamptz not null default now(),
  unique(user_id, month)
);

-- ============================================================================
-- Triggers
-- ============================================================================

-- Auto-create profile when a new auth user is created.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Generic updated_at maintenance.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger subscriptions_set_updated_at
  before update on public.subscriptions
  for each row execute function public.set_updated_at();

-- ============================================================================
-- Row Level Security
-- ============================================================================
alter table public.profiles enable row level security;
alter table public.bp_readings enable row level security;
alter table public.meal_logs enable row level security;
alter table public.subscriptions enable row level security;
alter table public.usage_tracking enable row level security;

-- profiles
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- bp_readings
create policy "bp_readings_select_own" on public.bp_readings
  for select using (auth.uid() = user_id);
create policy "bp_readings_insert_own" on public.bp_readings
  for insert with check (auth.uid() = user_id);
create policy "bp_readings_update_own" on public.bp_readings
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "bp_readings_delete_own" on public.bp_readings
  for delete using (auth.uid() = user_id);

-- meal_logs
create policy "meal_logs_select_own" on public.meal_logs
  for select using (auth.uid() = user_id);
create policy "meal_logs_insert_own" on public.meal_logs
  for insert with check (auth.uid() = user_id);
create policy "meal_logs_update_own" on public.meal_logs
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "meal_logs_delete_own" on public.meal_logs
  for delete using (auth.uid() = user_id);

-- subscriptions: select-only for users; writes via service role.
create policy "subscriptions_select_own" on public.subscriptions
  for select using (auth.uid() = user_id);

-- usage_tracking: select-only for users; writes via service role.
create policy "usage_tracking_select_own" on public.usage_tracking
  for select using (auth.uid() = user_id);

-- ============================================================================
-- pg_cron: monthly cleanup of usage_tracking rows older than 6 months.
-- ============================================================================
select cron.schedule(
  'cleanup_old_usage_tracking',
  '0 0 1 * *',
  $$delete from public.usage_tracking
    where month < to_char(now() - interval '6 months', 'YYYY-MM')$$
);
