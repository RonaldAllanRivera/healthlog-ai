-- Test helper functions for pgTAP tests.
-- Installs a lightweight subset of supabase_test_helpers (canonical
-- implementations from https://github.com/usebasejump/supabase-test-helpers)
-- so that RLS tests can create synthetic users and switch auth context.
--
-- SECURITY: these functions can fabricate users and impersonate identities.
-- If callable by anon or authenticated in production, a logged-in user
-- could escalate themselves to any other user. We mitigate two ways:
--   1. Every dangerous function requires the session variable
--      `app.testing = 'true'` to be set, otherwise it raises.
--   2. Tests set `app.testing = true` at the start of each file.
-- Production code will never set this variable, so calls fail safely.

create schema if not exists tests;
grant usage on schema tests to anon, authenticated, service_role;

-- Internal guard called by every dangerous helper. Raises if not in test mode.
create or replace function tests.assert_test_mode()
returns void
language plpgsql
as $$
begin
  if current_setting('app.testing', true) is distinct from 'true' then
    raise exception
      'tests.* helpers may only be called when app.testing = ''true''. '
      'This protects production from impersonation attacks.';
  end if;
end;
$$;

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
  perform tests.assert_test_mode();
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
  perform tests.assert_test_mode();
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

-- Grant execute to the standard Supabase roles. The session-variable guard
-- (tests.assert_test_mode) is the actual security boundary, not these grants.
grant execute on all functions in schema tests to anon, authenticated, service_role;
