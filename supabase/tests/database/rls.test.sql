-- RLS isolation tests for healthlog-ai.
-- Verifies that user A cannot read or write user B's data on every table,
-- and that subscriptions/usage_tracking writes are blocked for normal users.

-- Unlock the test helpers. The migration's tests.* functions check this
-- session variable and refuse to run otherwise — protecting production.
set app.testing = 'true';

begin;
select plan(26);

-- Create two synthetic users using Supabase's auth test helpers.
-- These helpers come from the `supabase_test_helpers` extension which
-- `supabase test db` installs automatically.
select tests.create_supabase_user('alice');
select tests.create_supabase_user('bob');

-- Authenticate as alice and insert data.
select tests.authenticate_as('alice');

insert into public.bp_readings (user_id, systolic, diastolic, pulse)
  values (tests.get_supabase_uid('alice'), 120, 80, 70);

insert into public.meal_logs (user_id, description, estimated_calories)
  values (tests.get_supabase_uid('alice'), 'apple', 95);

-- Update alice's profile (created by trigger).
update public.profiles set full_name = 'Alice'
  where id = tests.get_supabase_uid('alice');

-- ============================================================================
-- profiles
-- ============================================================================
select results_eq(
  $$select full_name from public.profiles$$,
  $$values ('Alice'::text)$$,
  'alice sees her own profile'
);

select tests.authenticate_as('bob');
select is_empty(
  $$select 1 from public.profiles where full_name = 'Alice'$$,
  'bob cannot see alice profile'
);

update public.profiles set full_name = 'Pwned'
  where id = tests.get_supabase_uid('alice');
select is_empty(
  $$select 1 from public.profiles where full_name = 'Pwned'$$,
  'bob cannot update alice profile'
);

-- ============================================================================
-- bp_readings
-- ============================================================================
select tests.authenticate_as('alice');
select results_eq(
  $$select count(*)::int from public.bp_readings$$,
  $$values (1)$$,
  'alice sees her own bp_reading'
);

select tests.authenticate_as('bob');
select results_eq(
  $$select count(*)::int from public.bp_readings$$,
  $$values (0)$$,
  'bob cannot see alice bp_reading'
);

update public.bp_readings set systolic = 999
  where user_id = tests.get_supabase_uid('alice');
select tests.authenticate_as('alice');
select results_eq(
  $$select systolic from public.bp_readings$$,
  $$values (120)$$,
  'bob cannot update alice bp_reading'
);

select tests.authenticate_as('bob');
delete from public.bp_readings where user_id = tests.get_supabase_uid('alice');
select tests.authenticate_as('alice');
select results_eq(
  $$select count(*)::int from public.bp_readings$$,
  $$values (1)$$,
  'bob cannot delete alice bp_reading'
);

-- bob inserting under alice's user_id should fail RLS WITH CHECK.
select tests.authenticate_as('bob');
prepare bob_insert as
  insert into public.bp_readings (user_id, systolic, diastolic)
  values (tests.get_supabase_uid('alice'), 100, 60);
select throws_ok(
  'bob_insert',
  '42501',
  'new row violates row-level security policy for table "bp_readings"',
  'bob cannot insert bp_reading for alice'
);

-- bob CAN insert for himself.
insert into public.bp_readings (user_id, systolic, diastolic)
  values (tests.get_supabase_uid('bob'), 110, 75);
select results_eq(
  $$select count(*)::int from public.bp_readings$$,
  $$values (1)$$,
  'bob can insert his own bp_reading'
);

-- ============================================================================
-- meal_logs
-- ============================================================================
select tests.authenticate_as('alice');
select results_eq(
  $$select count(*)::int from public.meal_logs$$,
  $$values (1)$$,
  'alice sees her own meal_log'
);

select tests.authenticate_as('bob');
select results_eq(
  $$select count(*)::int from public.meal_logs$$,
  $$values (0)$$,
  'bob cannot see alice meal_log'
);

update public.meal_logs set estimated_calories = 9999
  where user_id = tests.get_supabase_uid('alice');
select tests.authenticate_as('alice');
select results_eq(
  $$select estimated_calories from public.meal_logs$$,
  $$values (95)$$,
  'bob cannot update alice meal_log'
);

select tests.authenticate_as('bob');
delete from public.meal_logs where user_id = tests.get_supabase_uid('alice');
select tests.authenticate_as('alice');
select results_eq(
  $$select count(*)::int from public.meal_logs$$,
  $$values (1)$$,
  'bob cannot delete alice meal_log'
);

prepare bob_insert_meal as
  insert into public.meal_logs (user_id, description)
  values (tests.get_supabase_uid('alice'), 'pwn');
select tests.authenticate_as('bob');
select throws_ok(
  'bob_insert_meal',
  '42501',
  'new row violates row-level security policy for table "meal_logs"',
  'bob cannot insert meal_log for alice'
);

-- ============================================================================
-- subscriptions: writes blocked for normal users entirely.
-- We use the service role to seed a row for alice, then verify she can read it
-- but not insert/update/delete.
-- ============================================================================
set local role service_role;
insert into public.subscriptions (user_id, plan, status)
  values (tests.get_supabase_uid('alice'), 'pro', 'active');
reset role;

select tests.authenticate_as('alice');
select results_eq(
  $$select plan from public.subscriptions$$,
  $$values ('pro'::text)$$,
  'alice sees her own subscription'
);

select tests.authenticate_as('bob');
select results_eq(
  $$select count(*)::int from public.subscriptions$$,
  $$values (0)$$,
  'bob cannot see alice subscription'
);

-- alice attempts to insert her own subscription (already exists, but RLS blocks first).
prepare alice_insert_sub as
  insert into public.subscriptions (user_id, plan)
  values (tests.get_supabase_uid('alice'), 'pro');
select tests.authenticate_as('alice');
select throws_ok(
  'alice_insert_sub',
  '42501',
  'new row violates row-level security policy for table "subscriptions"',
  'alice cannot insert her own subscription (must go via service role)'
);

-- alice attempts to upgrade herself.
update public.subscriptions set plan = 'pro'
  where user_id = tests.get_supabase_uid('alice');
-- No rows updated because no UPDATE policy exists. Confirm the row is unchanged
-- (it was already 'pro' from service role, but we're asserting the operation was
-- silently filtered, not that it succeeded). Use a stronger check: a separate
-- field. Reset to 'free' via service role first.
set local role service_role;
update public.subscriptions set plan = 'free'
  where user_id = tests.get_supabase_uid('alice');
reset role;
select tests.authenticate_as('alice');
update public.subscriptions set plan = 'pro'
  where user_id = tests.get_supabase_uid('alice');
select results_eq(
  $$select plan from public.subscriptions$$,
  $$values ('free'::text)$$,
  'alice cannot update her own subscription plan'
);

-- alice attempts to delete her subscription.
delete from public.subscriptions where user_id = tests.get_supabase_uid('alice');
select results_eq(
  $$select count(*)::int from public.subscriptions$$,
  $$values (1)$$,
  'alice cannot delete her own subscription'
);

-- ============================================================================
-- usage_tracking: writes blocked for normal users entirely.
-- ============================================================================
set local role service_role;
insert into public.usage_tracking (user_id, month, bp_scans_used)
  values (tests.get_supabase_uid('alice'), '2026-05', 3);
reset role;

select tests.authenticate_as('alice');
select results_eq(
  $$select bp_scans_used from public.usage_tracking$$,
  $$values (3)$$,
  'alice sees her own usage_tracking'
);

select tests.authenticate_as('bob');
select results_eq(
  $$select count(*)::int from public.usage_tracking$$,
  $$values (0)$$,
  'bob cannot see alice usage_tracking'
);

prepare alice_zero_usage as
  update public.usage_tracking set bp_scans_used = 0
  where user_id = tests.get_supabase_uid('alice');
select tests.authenticate_as('alice');
-- No UPDATE policy exists, so this silently affects zero rows.
update public.usage_tracking set bp_scans_used = 0
  where user_id = tests.get_supabase_uid('alice');
select results_eq(
  $$select bp_scans_used from public.usage_tracking$$,
  $$values (3)$$,
  'alice cannot zero her own usage_tracking counter'
);

prepare alice_insert_usage as
  insert into public.usage_tracking (user_id, month)
  values (tests.get_supabase_uid('alice'), '2026-06');
select throws_ok(
  'alice_insert_usage',
  '42501',
  'new row violates row-level security policy for table "usage_tracking"',
  'alice cannot insert her own usage_tracking row'
);

-- ============================================================================
-- CHECK constraints (sanity)
-- ============================================================================
prepare bad_systolic as
  insert into public.bp_readings (user_id, systolic, diastolic)
  values (tests.get_supabase_uid('alice'), 9999, 80);
select tests.authenticate_as('alice');
select throws_ok(
  'bad_systolic',
  '23514',
  null,
  'bp_readings rejects systolic outside 40-300'
);

prepare bad_plan as
  insert into public.subscriptions (user_id, plan) values (gen_random_uuid(), 'platinum');
set local role service_role;
select throws_ok(
  'bad_plan',
  '23514',
  null,
  'subscriptions rejects invalid plan value'
);
reset role;

prepare bad_month_format as
  insert into public.usage_tracking (user_id, month)
  values (tests.get_supabase_uid('alice'), '2026-5');
set local role service_role;
select throws_ok(
  'bad_month_format',
  '23514',
  null,
  'usage_tracking rejects malformed month string'
);
reset role;

select * from finish();
rollback;
