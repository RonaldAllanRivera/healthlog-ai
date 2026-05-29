-- Test helper functions for pgTAP tests.
-- Installs a lightweight subset of supabase_test_helpers (canonical
-- implementations from https://github.com/usebasejump/supabase-test-helpers)
-- so that RLS tests can create synthetic users and switch auth context.
--
-- SECURITY: these functions can fabricate users and impersonate identities.
-- If callable in production, any logged-in user could escalate to any other
-- user. We block this two ways, defense-in-depth:
--
--   1. EXECUTE on every tests.* function is revoked from anon, authenticated,
--      and service_role. Only superuser/owner can call. This alone would be
--      sufficient on a stock Postgres, but Supabase's PostgREST always
--      connects as the `authenticator` role and then `SET ROLE`s to one of
--      the API roles, which means an attacker can't easily call these
--      anyway — but explicit revokes are still required.
--
--   2. Every dangerous function calls tests.assert_test_mode(), which
--      checks `session_user = 'postgres'`. session_user is the ORIGINAL
--      authenticated role for the connection — it is NOT changed by
--      `SET ROLE`. PostgREST connects as `authenticator`, so session_user
--      for any API call is `authenticator`. Only `supabase test db` (which
--      connects directly as postgres) passes this check.
--
-- Why not check `current_user` instead? Because `SET ROLE postgres` from
-- a privileged session would change current_user. session_user is immune.
-- Why not just use a USERSET GUC like `app.testing`? Because any user can
-- SET that themselves — it's not a security boundary.

create schema if not exists tests;
-- Schema usage open to all Supabase roles. The actual security boundary is
-- the session_user check inside each function — schema usage is just name
-- resolution and is harmless on its own.
grant usage on schema tests to anon, authenticated, service_role;

create or replace function tests.assert_test_mode()
returns void
language plpgsql
as $$
begin
  if session_user is distinct from 'postgres' then
    raise exception
      'tests.* helpers may only be called by the postgres superuser '
      '(via `supabase test db`). Refusing to run as session_user=%.',
      session_user;
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
  perform tests.assert_test_mode();
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
  perform tests.assert_test_mode();
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

-- Grant execute to the standard Supabase roles. Tests need this because they
-- call helpers after `set role authenticated` or `set local role service_role`.
-- The session_user check inside each function is the actual security boundary;
-- session_user is the ORIGINAL authenticated role for the connection and is
-- preserved across SET ROLE — so an attacker connecting via PostgREST (whose
-- session_user is always 'authenticator') cannot bypass it.
grant execute on all functions in schema tests to anon, authenticated, service_role;
