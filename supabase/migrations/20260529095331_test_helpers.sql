-- Test helper functions for pgTAP tests.
-- Installs a lightweight subset of supabase_test_helpers (canonical
-- implementations from https://github.com/usebasejump/supabase-test-helpers)
-- so that RLS tests can create synthetic users and switch auth context.
--
-- These helpers are only used in the test suite (supabase test db) and are
-- safe to ship in all environments because they live in the `tests` schema
-- and carry no production data.

-- Create the tests schema and grant access to Supabase roles.
create schema if not exists tests;
grant usage on schema tests to anon, authenticated, service_role;

-- Revoke all function-level access from public within tests schema.
alter default privileges in schema tests revoke execute on functions from public;

-- ============================================================================
-- tests.create_supabase_user
-- Creates a test user in auth.users identified by a text tag stored in
-- raw_user_meta_data. Returns the new user's UUID.
-- ============================================================================
create or replace function tests.create_supabase_user(
  identifier text,
  email text default null,
  phone text default null,
  metadata jsonb default null
)
returns uuid
security definer
set search_path = auth, pg_temp
language plpgsql
as $$
declare
  user_id uuid;
begin
  user_id := gen_random_uuid();
  insert into auth.users (
    id,
    email,
    phone,
    raw_user_meta_data,
    raw_app_meta_data,
    encrypted_password,
    created_at,
    updated_at,
    confirmation_sent_at,
    is_super_admin,
    role
  )
  values (
    user_id,
    coalesce(email, concat(user_id, '@test.com')),
    phone,
    jsonb_build_object('test_identifier', identifier) || coalesce(metadata, '{}'::jsonb),
    '{}'::jsonb,
    '',
    now(),
    now(),
    now(),
    false,
    'authenticated'
  );
  return user_id;
end;
$$;

-- ============================================================================
-- tests.get_supabase_user
-- Returns user JSON for the given test identifier.
-- ============================================================================
create or replace function tests.get_supabase_user(identifier text)
returns json
security definer
set search_path = auth, pg_temp
language plpgsql
as $$
declare
  supabase_user json;
begin
  select json_build_object(
    'id', id,
    'email', email,
    'phone', phone,
    'raw_user_meta_data', raw_user_meta_data,
    'raw_app_meta_data', raw_app_meta_data
  )
  into supabase_user
  from auth.users
  where raw_user_meta_data ->> 'test_identifier' = identifier
  limit 1;

  if supabase_user is null then
    raise exception 'User with identifier % not found', identifier;
  end if;

  return supabase_user;
end;
$$;

-- ============================================================================
-- tests.get_supabase_uid
-- Returns the UUID of the test user identified by identifier.
-- ============================================================================
create or replace function tests.get_supabase_uid(identifier text)
returns uuid
security definer
set search_path = auth, pg_temp
language plpgsql
as $$
declare
  supabase_user uuid;
begin
  select id
  into supabase_user
  from auth.users
  where raw_user_meta_data ->> 'test_identifier' = identifier
  limit 1;

  if supabase_user is null then
    raise exception 'User with identifier % not found', identifier;
  end if;

  return supabase_user;
end;
$$;

-- ============================================================================
-- tests.authenticate_as
-- Sets the current role to `authenticated` and configures the JWT claims
-- to simulate being logged in as the named test user.
-- ============================================================================
create or replace function tests.authenticate_as(identifier text)
returns void
language plpgsql
as $$
declare
  user_data json;
begin
  user_data := tests.get_supabase_user(identifier);

  if user_data is null or user_data ->> 'id' is null then
    raise exception 'User with identifier % not found', identifier;
  end if;

  perform set_config('role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub',           user_data ->> 'id',
      'email',         user_data ->> 'email',
      'phone',         user_data ->> 'phone',
      'user_metadata', user_data -> 'raw_user_meta_data',
      'app_metadata',  user_data -> 'raw_app_meta_data'
    )::text,
    true
  );
end;
$$;

-- ============================================================================
-- tests.clear_authentication
-- Resets to the anon role and clears JWT claims.
-- ============================================================================
create or replace function tests.clear_authentication()
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

-- Grant execute on all tests.* functions to the roles used in tests.
grant execute on all functions in schema tests to anon, authenticated, service_role;
