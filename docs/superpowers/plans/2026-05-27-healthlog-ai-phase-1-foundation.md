# healthlog-ai — Phase 1: Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the `healthlog-ai` monorepo with database schema, shared `@healthlog/supabase` package, minimal `apps/web` (Next.js 15) and `apps/mobile` (Expo SDK 52) shells, three test gates, and Claude Code project config — verifiable end-to-end from a clean clone.

**Architecture:** npm workspaces + Turborepo monorepo. Supabase CLI manages a local Postgres (Docker) with migrations as source of truth. `packages/supabase` exposes generated types, zod schemas, plan limits, and platform-specific client factories via subpath exports. RLS isolates user data; pgTAP verifies the isolation; vitest verifies the schemas; tsc verifies the types.

**Tech Stack:** Node 20, npm workspaces, Turborepo 2.x, TypeScript 5.6+, Next.js 15 (App Router, Tailwind v4, shadcn/ui), Expo SDK 52 (React Native 0.76, NativeWind v4, React Navigation v7), Supabase CLI + Postgres 15, `@supabase/supabase-js` v2 + `@supabase/ssr`, Zod 3, Vitest 2, pgTAP via `supabase test db`.

**Reference:** [`docs/superpowers/specs/2026-05-27-healthlog-ai-phase-1-foundation-design.md`](../specs/2026-05-27-healthlog-ai-phase-1-foundation-design.md)

**Prerequisites the engineer must have installed before starting:**
- Node.js 20.x (`nvm install 20 && nvm use 20`)
- npm 10+
- Docker Desktop running (Supabase local stack needs it)
- Supabase CLI (`brew install supabase/tap/supabase` or equivalent — `supabase --version` must work)

---

## Task 1: Initialize repo, root configs, .gitignore, .nvmrc

**Files:**
- Create: `.git/` (via `git init`)
- Create: `.gitignore`
- Create: `.nvmrc`
- Create: `README.md` (stub — full content in Task 20)

- [ ] **Step 1: Confirm working directory and clean state**

Run from the project root (`/home/allan/code/next.js/healthlog-ai`):
```bash
pwd && ls -la
```
Expected: only `docs/` exists. If anything else is there, stop and ask.

- [ ] **Step 2: Initialize git**

```bash
git init
git branch -M main
```
Expected: "Initialized empty Git repository". Branch renamed to `main`.

- [ ] **Step 3: Create `.gitignore`**

Create `.gitignore`:
```
# Node
node_modules/
.npm/
.pnpm-debug.log*
npm-debug.log*

# Build outputs
.next/
out/
dist/
build/
.turbo/
*.tsbuildinfo

# Env
.env
.env.local
.env.*.local

# Expo
.expo/
.expo-shared/
web-build/

# Supabase
supabase/.branches/
supabase/.temp/

# Claude Code
.claude/settings.local.json

# IDE
.vscode/
.idea/
.DS_Store
*.swp
```

- [ ] **Step 4: Create `.nvmrc`**

Create `.nvmrc`:
```
20
```

- [ ] **Step 5: Create stub `README.md`**

Create `README.md`:
```markdown
# healthlog-ai

Monorepo for the HealthLog AI product. See `docs/superpowers/specs/` for design specs and `docs/superpowers/plans/` for implementation plans.

Full setup instructions land at the end of Phase 1 implementation.
```

- [ ] **Step 6: Confirm Node version**

```bash
nvm use && node --version
```
Expected: `v20.x.x`. If `nvm` not installed, the engineer must install Node 20 by some other means and proceed.

- [ ] **Step 7: Initial commit**

```bash
git add .gitignore .nvmrc README.md docs/
git commit -m "chore: initialize repo with gitignore, nvmrc, and design docs"
```
Expected: commit created. `git status` shows clean tree.

---

## Task 2: Root `package.json`, `turbo.json`, root `tsconfig.json`

**Files:**
- Create: `package.json`
- Create: `turbo.json`
- Create: `tsconfig.json`

- [ ] **Step 1: Create root `package.json`**

Create `package.json`:
```json
{
  "name": "healthlog-ai",
  "private": true,
  "version": "0.0.0",
  "workspaces": [
    "apps/*",
    "packages/*",
    "tooling/*"
  ],
  "engines": {
    "node": ">=20.0.0",
    "npm": ">=10.0.0"
  },
  "scripts": {
    "dev": "turbo dev",
    "build": "turbo build",
    "lint": "turbo lint",
    "typecheck": "turbo typecheck",
    "test": "turbo test",
    "db:start": "supabase start",
    "db:stop": "supabase stop",
    "db:status": "supabase status",
    "db:reset": "supabase db reset",
    "db:diff": "supabase db diff -f",
    "db:migration": "supabase migration new",
    "db:types": "supabase gen types typescript --local > packages/supabase/src/types.ts",
    "db:test": "supabase test db"
  },
  "devDependencies": {
    "turbo": "^2.3.0",
    "typescript": "^5.6.3"
  }
}
```

- [ ] **Step 2: Create `turbo.json`**

Create `turbo.json`:
```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "!.next/cache/**", "dist/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "lint": {
      "outputs": []
    },
    "typecheck": {
      "dependsOn": ["^build"],
      "outputs": []
    },
    "test": {
      "dependsOn": ["^build"],
      "outputs": []
    }
  }
}
```

- [ ] **Step 3: Create root `tsconfig.json`**

Create `tsconfig.json` (solution-style — does not compile, just orchestrates):
```json
{
  "files": [],
  "references": [
    { "path": "packages/supabase" },
    { "path": "apps/web" },
    { "path": "apps/mobile" }
  ]
}
```
Note: the referenced paths don't exist yet. That's fine; TypeScript only validates references when their tsconfigs exist. We'll re-verify after creating those workspaces.

- [ ] **Step 4: Install root dev dependencies**

```bash
npm install
```
Expected: `node_modules/` created, `turbo` and `typescript` installed. `package-lock.json` generated.

- [ ] **Step 5: Verify turbo is callable**

```bash
npx turbo --version
```
Expected: `2.x.x` printed.

- [ ] **Step 6: Commit**

```bash
git add package.json package-lock.json turbo.json tsconfig.json
git commit -m "chore: set up root workspaces, turbo, and tsconfig"
```

---

## Task 3: Shared `tooling/tsconfig` package

**Files:**
- Create: `tooling/tsconfig/package.json`
- Create: `tooling/tsconfig/base.json`
- Create: `tooling/tsconfig/library.json`
- Create: `tooling/tsconfig/nextjs.json`
- Create: `tooling/tsconfig/react-native.json`

- [ ] **Step 1: Create the package manifest**

Create `tooling/tsconfig/package.json`:
```json
{
  "name": "@healthlog/tsconfig",
  "version": "0.0.0",
  "private": true,
  "files": [
    "base.json",
    "library.json",
    "nextjs.json",
    "react-native.json"
  ]
}
```

- [ ] **Step 2: Create `base.json`** (shared strictness defaults)

Create `tooling/tsconfig/base.json`:
```json
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022"],
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "forceConsistentCasingInFileNames": true,
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "skipLibCheck": true,
    "isolatedModules": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true
  }
}
```

- [ ] **Step 3: Create `library.json`** (for `packages/*`)

Create `tooling/tsconfig/library.json`:
```json
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "extends": "./base.json",
  "compilerOptions": {
    "composite": true,
    "outDir": "dist",
    "rootDir": "src"
  }
}
```

- [ ] **Step 4: Create `nextjs.json`**

Create `tooling/tsconfig/nextjs.json`:
```json
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "extends": "./base.json",
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["dom", "dom.iterable", "ES2022"],
    "jsx": "preserve",
    "module": "esnext",
    "moduleResolution": "bundler",
    "allowJs": false,
    "noEmit": true,
    "incremental": true,
    "plugins": [{ "name": "next" }]
  }
}
```

- [ ] **Step 5: Create `react-native.json`**

Create `tooling/tsconfig/react-native.json`:
```json
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "extends": "./base.json",
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022"],
    "jsx": "react-native",
    "module": "esnext",
    "moduleResolution": "bundler",
    "noEmit": true
  }
}
```

- [ ] **Step 6: Re-run npm install to wire up the new workspace**

```bash
npm install
```
Expected: `@healthlog/tsconfig` symlinked under `node_modules/@healthlog/`.

- [ ] **Step 7: Verify the workspace is discoverable**

```bash
npm ls @healthlog/tsconfig
```
Expected: shows `@healthlog/tsconfig@0.0.0 -> ./tooling/tsconfig`.

- [ ] **Step 8: Commit**

```bash
git add tooling/tsconfig package.json package-lock.json
git commit -m "chore: add shared @healthlog/tsconfig package"
```

---

## Task 4: Shared `tooling/eslint-config` package

**Files:**
- Create: `tooling/eslint-config/package.json`
- Create: `tooling/eslint-config/base.js`
- Create: `tooling/eslint-config/next.js`
- Create: `tooling/eslint-config/react-native.js`
- Create: `tooling/eslint-config/node.js`

- [ ] **Step 1: Create the package manifest**

Create `tooling/eslint-config/package.json`:
```json
{
  "name": "@healthlog/eslint-config",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "main": "base.js",
  "files": ["base.js", "next.js", "react-native.js", "node.js"],
  "dependencies": {
    "eslint": "^9.15.0",
    "typescript-eslint": "^8.15.0",
    "@eslint/js": "^9.15.0",
    "eslint-config-prettier": "^9.1.0",
    "globals": "^15.12.0"
  }
}
```

- [ ] **Step 2: Create `base.js`** (flat config, shared rules)

Create `tooling/eslint-config/base.js`:
```js
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import prettier from "eslint-config-prettier";
import globals from "globals";

export default tseslint.config(
  {
    ignores: [
      "**/node_modules/**",
      "**/dist/**",
      "**/.next/**",
      "**/.expo/**",
      "**/.turbo/**",
      "**/coverage/**",
      "**/*.config.js",
      "**/*.config.mjs",
      "**/*.config.ts",
    ],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  prettier,
  {
    languageOptions: {
      globals: { ...globals.node },
    },
    rules: {
      "@typescript-eslint/no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],
      "@typescript-eslint/consistent-type-imports": [
        "error",
        { prefer: "type-imports" },
      ],
      "no-console": ["warn", { allow: ["warn", "error"] }],
    },
  },
);
```

- [ ] **Step 3: Create `next.js`**

Create `tooling/eslint-config/next.js`:
```js
import base from "./base.js";
import globals from "globals";

export default [
  ...base,
  {
    languageOptions: {
      globals: { ...globals.browser, ...globals.node },
    },
  },
];
```
Note: a heavier next-plugin-aware config can be layered later. Phase 1 keeps it minimal — `next lint` is being deprecated in favor of bring-your-own ESLint anyway.

- [ ] **Step 4: Create `react-native.js`**

Create `tooling/eslint-config/react-native.js`:
```js
import base from "./base.js";
import globals from "globals";

export default [
  ...base,
  {
    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.node,
        __DEV__: "readonly",
      },
    },
  },
];
```

- [ ] **Step 5: Create `node.js`**

Create `tooling/eslint-config/node.js`:
```js
import base from "./base.js";
export default base;
```

- [ ] **Step 6: Install dependencies**

```bash
npm install
```
Expected: ESLint and its dependencies installed in `node_modules/`.

- [ ] **Step 7: Verify config loads**

```bash
cd tooling/eslint-config && node -e "import('./base.js').then(m => console.log('ok', Array.isArray(m.default)))" && cd ../..
```
Expected: `ok true`.

- [ ] **Step 8: Commit**

```bash
git add tooling/eslint-config package.json package-lock.json
git commit -m "chore: add shared @healthlog/eslint-config package"
```

---

## Task 5: Initialize Supabase and write initial migration

**Files:**
- Create: `supabase/config.toml` (via `supabase init`)
- Create: `supabase/migrations/<timestamp>_initial_schema.sql`
- Create: `supabase/seed.sql`
- Modify: `.gitignore` (if `supabase init` adds entries)

- [ ] **Step 1: Initialize Supabase project**

```bash
supabase init
```
Expected: prompts "Generate VS Code settings for Deno? [y/N]" — answer **N**. "Generate IntelliJ Settings for Deno? [y/N]" — answer **N**. Creates `supabase/config.toml` and `supabase/seed.sql`.

- [ ] **Step 2: Confirm the supabase directory structure**

```bash
ls supabase/
```
Expected: `config.toml`, `seed.sql`. `migrations/` directory may or may not exist yet — we'll create the first migration next.

- [ ] **Step 3: Confirm `pg_cron` is available locally (fallback in Step 6 if not)**

The local Supabase Docker image ships with `pg_cron` in `shared_preload_libraries` by default in recent CLI versions, so the migration's `create extension if not exists "pg_cron";` will likely just work.

**Don't edit `config.toml` yet.** If Step 6 (`supabase start`) or Step 7 (`supabase db reset`) fails with an error like `could not open extension control file ... pg_cron` or `pg_cron must be loaded via shared_preload_libraries`, return to this step and:

1. Open `supabase/config.toml`
2. Look for any existing `[db]`-related section
3. Try one of these (depending on your CLI version — only one will validate):
   ```toml
   # Newer CLI:
   [db.extensions]
   enabled = ["pg_cron"]
   ```
   Or:
   ```toml
   # Older CLI used shared_preload_libraries directly:
   [db]
   shared_preload_libraries = ["pg_cron"]
   ```
4. Validate with `supabase config validate` if that subcommand exists in your CLI
5. Re-run Steps 6-7

If neither shape works in your CLI version, check `supabase --help` and the Supabase docs for the current pattern. The substance: local Postgres must come up with `pg_cron` available.

- [ ] **Step 4: Generate the migration file**

```bash
supabase migration new initial_schema
```
Expected: creates `supabase/migrations/<14-digit-timestamp>_initial_schema.sql`, empty file.

- [ ] **Step 5: Fill in the migration SQL**

Open the file just created. Write the full schema:

```sql
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
```

- [ ] **Step 6: Start local Supabase**

```bash
supabase start
```
Expected: Docker pulls images (first run only — may take several minutes). Prints local API URL, anon key, service role key, JWT secret, DB URL. **Copy these somewhere — you'll need them for the apps' `.env.local` later.**

If `supabase start` fails:
- "Cannot connect to Docker daemon" → start Docker Desktop and retry
- pg_cron extension error → confirm `config.toml` change from Step 3

- [ ] **Step 7: Run `supabase db reset` to apply the migration**

```bash
supabase db reset
```
Expected: drops local DB, re-applies migrations, completes with "Finished supabase db reset on branch main." No errors.

- [ ] **Step 8: Manually verify schema in the local DB**

```bash
supabase status
```
Note the **DB URL** (looks like `postgresql://postgres:postgres@127.0.0.1:54322/postgres`).

```bash
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -c "\dt public.*"
```
Expected: all five tables listed (`bp_readings`, `meal_logs`, `profiles`, `subscriptions`, `usage_tracking`).

```bash
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -c "select schedule, command from cron.job where jobname = 'cleanup_old_usage_tracking';"
```
Expected: one row showing the cron schedule.

- [ ] **Step 9: Commit**

```bash
git add supabase/
git commit -m "feat(db): add initial schema with RLS, triggers, and pg_cron cleanup"
```

---

## Task 6: pgTAP RLS isolation tests

**Files:**
- Create: `supabase/tests/database/rls.test.sql`

- [ ] **Step 1: Create the tests directory**

```bash
mkdir -p supabase/tests/database
```

- [ ] **Step 2: Write the test file**

Create `supabase/tests/database/rls.test.sql`:

```sql
-- RLS isolation tests for healthlog-ai.
-- Verifies that user A cannot read or write user B's data on every table,
-- and that subscriptions/usage_tracking writes are blocked for normal users.

begin;
select plan(28);

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
```

- [ ] **Step 3: Run the test suite**

```bash
npm run db:test
```
Expected: `supabase test db` runs pgTAP, output ends with `# Result: PASS` and shows all 28 tests passing.

If a test fails:
- Read the failure message carefully; pgTAP shows the SQL query, expected vs actual rows
- The most common mistake is an off-by-one in the `plan(N)` count — adjust to match the actual number of `select ... ok(...)` calls
- A policy mismatch usually indicates the migration RLS doesn't match what the test expects

- [ ] **Step 4: Commit**

```bash
git add supabase/tests/
git commit -m "test(db): add pgTAP RLS isolation tests for all five tables"
```

---

## Task 7: `packages/supabase` skeleton + generate types

**Files:**
- Create: `packages/supabase/package.json`
- Create: `packages/supabase/tsconfig.json`
- Create: `packages/supabase/vitest.config.ts`
- Create: `packages/supabase/src/types.ts` (stub initially, then regenerated)
- Create: `packages/supabase/eslint.config.js`

- [ ] **Step 1: Create the package directory tree**

```bash
mkdir -p packages/supabase/src/schemas packages/supabase/src/web packages/supabase/src/mobile packages/supabase/tests
```

- [ ] **Step 2: Create `package.json`**

Create `packages/supabase/package.json`:
```json
{
  "name": "@healthlog/supabase",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "exports": {
    "./types": "./src/types.ts",
    "./schemas": "./src/schemas/index.ts",
    "./plans": "./src/plans.ts",
    "./web/server": "./src/web/server.ts",
    "./web/browser": "./src/web/browser.ts",
    "./mobile": "./src/mobile/index.ts"
  },
  "scripts": {
    "lint": "eslint .",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "@supabase/supabase-js": "^2.45.0",
    "@supabase/ssr": "^0.5.0",
    "@react-native-async-storage/async-storage": "^2.0.0",
    "zod": "^3.23.0"
  },
  "devDependencies": {
    "@healthlog/eslint-config": "*",
    "@healthlog/tsconfig": "*",
    "typescript": "^5.6.3",
    "vitest": "^2.1.0"
  },
  "peerDependencies": {
    "next": "^15.0.0",
    "react-native": ">=0.76.0"
  },
  "peerDependenciesMeta": {
    "next": { "optional": true },
    "react-native": { "optional": true }
  }
}
```

- [ ] **Step 3: Create `tsconfig.json`**

Create `packages/supabase/tsconfig.json`:
```json
{
  "extends": "@healthlog/tsconfig/library.json",
  "compilerOptions": {
    "rootDir": "src",
    "outDir": "dist",
    "noEmit": true,
    "composite": false
  },
  "include": ["src/**/*.ts", "tests/**/*.ts"]
}
```

Note: `composite: false` and `noEmit: true` because we don't actually ship built artifacts in Phase 1 — apps import the `.ts` sources directly via subpath exports. The Next.js compiler and Metro both handle `.ts` from workspaces. Switch to building if Phase 5 introduces external publishing.

- [ ] **Step 4: Create `vitest.config.ts`**

Create `packages/supabase/vitest.config.ts`:
```ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: ["tests/**/*.test.ts"],
  },
});
```

- [ ] **Step 5: Create ESLint config**

Create `packages/supabase/eslint.config.js`:
```js
import config from "@healthlog/eslint-config/node.js";
export default config;
```

- [ ] **Step 6: Create the stub `types.ts`**

Create `packages/supabase/src/types.ts`:
```ts
// AUTO-GENERATED by `supabase gen types typescript --local`.
// Run `npm run db:types` after any migration change.
// This file is overwritten — do not edit by hand.

export type Json =
  | string
  | number
  | boolean
  | null
  | { [k: string]: Json | undefined }
  | Json[];

export type Database = Record<string, never>;
```

- [ ] **Step 7: Install dependencies**

```bash
npm install
```
Expected: `@healthlog/supabase` symlinked. `@supabase/supabase-js`, `@supabase/ssr`, `zod`, `vitest`, etc. resolved.

- [ ] **Step 8: Verify typecheck passes on the stub**

```bash
npm run typecheck -w @healthlog/supabase
```
Expected: no errors. (No source files yet beyond `types.ts`, which is valid TypeScript.)

- [ ] **Step 9: Regenerate types from the live local DB**

```bash
npm run db:types
```
Expected: `packages/supabase/src/types.ts` is overwritten with the real generated types. The file should now contain a long `Database` type with `public.Tables.profiles`, `bp_readings`, `meal_logs`, `subscriptions`, `usage_tracking` sub-trees.

Verify:
```bash
grep -c "public" packages/supabase/src/types.ts
```
Expected: a number > 5 (multiple references in the generated file).

- [ ] **Step 10: Typecheck again with real types**

```bash
npm run typecheck -w @healthlog/supabase
```
Expected: no errors.

- [ ] **Step 11: Commit**

```bash
git add packages/supabase/ package.json package-lock.json
git commit -m "feat(supabase): scaffold @healthlog/supabase package with generated types"
```

---

## Task 8: `plans.ts` with tests (TDD)

**Files:**
- Create: `packages/supabase/tests/plans.test.ts`
- Create: `packages/supabase/src/plans.ts`

- [ ] **Step 1: Write the failing test**

Create `packages/supabase/tests/plans.test.ts`:
```ts
import { describe, it, expect } from "vitest";
import { PLAN_LIMITS, isOverLimit, type Plan } from "../src/plans.js";

describe("PLAN_LIMITS", () => {
  it("defines limits for free, basic, pro", () => {
    expect(PLAN_LIMITS.free.bpScans).toBe(10);
    expect(PLAN_LIMITS.free.mealScans).toBe(10);
    expect(PLAN_LIMITS.basic.bpScans).toBe(100);
    expect(PLAN_LIMITS.basic.mealScans).toBe(100);
    expect(PLAN_LIMITS.pro.bpScans).toBe(Infinity);
    expect(PLAN_LIMITS.pro.mealScans).toBe(Infinity);
  });

  it("monotonically increases free → basic → pro for every limit", () => {
    const kinds = ["bpScans", "mealScans"] as const;
    for (const kind of kinds) {
      expect(PLAN_LIMITS.basic[kind]).toBeGreaterThanOrEqual(
        PLAN_LIMITS.free[kind],
      );
      expect(PLAN_LIMITS.pro[kind]).toBeGreaterThanOrEqual(
        PLAN_LIMITS.basic[kind],
      );
    }
  });
});

describe("isOverLimit", () => {
  it("returns false when usage is below the limit", () => {
    expect(isOverLimit("free", "bp", 0)).toBe(false);
    expect(isOverLimit("free", "bp", 9)).toBe(false);
    expect(isOverLimit("basic", "meal", 50)).toBe(false);
  });

  it("returns true when usage equals or exceeds the limit", () => {
    expect(isOverLimit("free", "bp", 10)).toBe(true);
    expect(isOverLimit("free", "meal", 11)).toBe(true);
    expect(isOverLimit("basic", "bp", 100)).toBe(true);
  });

  it("returns false for pro at any reasonable count", () => {
    expect(isOverLimit("pro", "bp", 1_000_000)).toBe(false);
    expect(isOverLimit("pro", "meal", Number.MAX_SAFE_INTEGER)).toBe(false);
  });

  it("typechecks Plan as keyof PLAN_LIMITS", () => {
    const p: Plan = "free";
    expect(p in PLAN_LIMITS).toBe(true);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
npm run test -w @healthlog/supabase
```
Expected: vitest fails with a module-not-found error pointing at `../src/plans.js`.

- [ ] **Step 3: Implement `plans.ts`**

Create `packages/supabase/src/plans.ts`:
```ts
export const PLAN_LIMITS = {
  free:  { bpScans: 10,        mealScans: 10        },
  basic: { bpScans: 100,       mealScans: 100       },
  pro:   { bpScans: Infinity,  mealScans: Infinity  },
} as const;

export type Plan = keyof typeof PLAN_LIMITS;

export function isOverLimit(
  plan: Plan,
  kind: "bp" | "meal",
  used: number,
): boolean {
  const limit =
    kind === "bp" ? PLAN_LIMITS[plan].bpScans : PLAN_LIMITS[plan].mealScans;
  return used >= limit;
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
npm run test -w @healthlog/supabase
```
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/supabase/src/plans.ts packages/supabase/tests/plans.test.ts
git commit -m "feat(supabase): add PLAN_LIMITS and isOverLimit with tests"
```

---

## Task 9: Zod schemas with tests (TDD)

This task implements four schema modules and their tests. Each is structured the same way: write the test, watch it fail, write the schema, watch it pass.

**Files:**
- Create: `packages/supabase/src/schemas/bp.ts`
- Create: `packages/supabase/src/schemas/meal.ts`
- Create: `packages/supabase/src/schemas/subscription.ts`
- Create: `packages/supabase/src/schemas/usage.ts`
- Create: `packages/supabase/src/schemas/index.ts`
- Create: `packages/supabase/tests/schemas.test.ts`

- [ ] **Step 1: Write the full schema test file**

Create `packages/supabase/tests/schemas.test.ts`:
```ts
import { describe, it, expect } from "vitest";
import {
  BpReadingInsert,
  BpAnalysisResult,
  MealLogInsert,
  FoodAnalysisResult,
  SubscriptionRow,
  UsageTrackingRow,
} from "../src/schemas/index.js";

describe("BpReadingInsert", () => {
  it("accepts a minimal valid reading", () => {
    expect(
      BpReadingInsert.parse({ systolic: 120, diastolic: 80 }),
    ).toEqual({ systolic: 120, diastolic: 80 });
  });

  it("accepts all optional fields", () => {
    const r = BpReadingInsert.parse({
      systolic: 120,
      diastolic: 80,
      pulse: 70,
      notes: "morning reading",
      image_url: "https://example.com/x.jpg",
    });
    expect(r.pulse).toBe(70);
  });

  it("rejects systolic out of range", () => {
    expect(() => BpReadingInsert.parse({ systolic: 9999, diastolic: 80 }))
      .toThrow();
    expect(() => BpReadingInsert.parse({ systolic: 10, diastolic: 80 }))
      .toThrow();
  });

  it("rejects diastolic out of range", () => {
    expect(() => BpReadingInsert.parse({ systolic: 120, diastolic: 9999 }))
      .toThrow();
  });

  it("rejects non-integer systolic", () => {
    expect(() => BpReadingInsert.parse({ systolic: 120.5, diastolic: 80 }))
      .toThrow();
  });

  it("rejects malformed image_url", () => {
    expect(() =>
      BpReadingInsert.parse({
        systolic: 120,
        diastolic: 80,
        image_url: "not-a-url",
      }),
    ).toThrow();
  });
});

describe("BpAnalysisResult", () => {
  it("requires systolic, diastolic; allows null pulse", () => {
    const r = BpAnalysisResult.parse({
      systolic: 120,
      diastolic: 80,
      pulse: null,
    });
    expect(r.pulse).toBeNull();
  });
});

describe("MealLogInsert", () => {
  it("accepts a minimal entry with just description", () => {
    expect(MealLogInsert.parse({ description: "apple" }))
      .toEqual({ description: "apple" });
  });

  it("rejects negative calories", () => {
    expect(() =>
      MealLogInsert.parse({ description: "x", estimated_calories: -1 }),
    ).toThrow();
  });

  it("accepts zero calories", () => {
    expect(
      MealLogInsert.parse({ description: "water", estimated_calories: 0 }),
    ).toEqual({ description: "water", estimated_calories: 0 });
  });
});

describe("FoodAnalysisResult", () => {
  it("parses a typical AI response", () => {
    const r = FoodAnalysisResult.parse({
      items: [{ name: "apple", calories: 95 }],
      total_calories: 95,
    });
    expect(r.items).toHaveLength(1);
  });

  it("rejects empty items array", () => {
    expect(() =>
      FoodAnalysisResult.parse({ items: [], total_calories: 0 }),
    ).toThrow();
  });
});

describe("SubscriptionRow", () => {
  it("accepts free plan with active status", () => {
    expect(
      SubscriptionRow.parse({
        id: "11111111-1111-1111-1111-111111111111",
        user_id: "22222222-2222-2222-2222-222222222222",
        stripe_customer_id: null,
        stripe_subscription_id: null,
        plan: "free",
        status: "active",
        current_period_end: null,
      }),
    ).toMatchObject({ plan: "free", status: "active" });
  });

  it("rejects invalid plan name", () => {
    expect(() =>
      SubscriptionRow.parse({
        id: "11111111-1111-1111-1111-111111111111",
        user_id: "22222222-2222-2222-2222-222222222222",
        stripe_customer_id: null,
        stripe_subscription_id: null,
        plan: "platinum",
        status: "active",
        current_period_end: null,
      }),
    ).toThrow();
  });
});

describe("UsageTrackingRow", () => {
  it("accepts a well-formed month", () => {
    const r = UsageTrackingRow.parse({
      user_id: "33333333-3333-3333-3333-333333333333",
      month: "2026-05",
      bp_scans_used: 3,
      meal_scans_used: 1,
    });
    expect(r.month).toBe("2026-05");
  });

  it("rejects malformed month string", () => {
    expect(() =>
      UsageTrackingRow.parse({
        user_id: "33333333-3333-3333-3333-333333333333",
        month: "2026-5",
        bp_scans_used: 0,
        meal_scans_used: 0,
      }),
    ).toThrow();
  });

  it("rejects negative counters", () => {
    expect(() =>
      UsageTrackingRow.parse({
        user_id: "33333333-3333-3333-3333-333333333333",
        month: "2026-05",
        bp_scans_used: -1,
        meal_scans_used: 0,
      }),
    ).toThrow();
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
npm run test -w @healthlog/supabase
```
Expected: vitest fails with import errors for `../src/schemas/index.js`.

- [ ] **Step 3: Create `bp.ts`**

Create `packages/supabase/src/schemas/bp.ts`:
```ts
import { z } from "zod";

export const BpReadingInsert = z.object({
  systolic: z.number().int().min(40).max(300),
  diastolic: z.number().int().min(30).max(200),
  pulse: z.number().int().min(20).max(250).nullable().optional(),
  notes: z.string().max(1000).nullable().optional(),
  image_url: z.string().url().nullable().optional(),
});
export type BpReadingInsert = z.infer<typeof BpReadingInsert>;

export const BpAnalysisResult = z.object({
  systolic: z.number().int().min(40).max(300),
  diastolic: z.number().int().min(30).max(200),
  pulse: z.number().int().min(20).max(250).nullable(),
});
export type BpAnalysisResult = z.infer<typeof BpAnalysisResult>;
```

- [ ] **Step 4: Create `meal.ts`**

Create `packages/supabase/src/schemas/meal.ts`:
```ts
import { z } from "zod";

export const MealLogInsert = z.object({
  description: z.string().min(1).max(2000).nullable().optional(),
  image_url: z.string().url().nullable().optional(),
  estimated_calories: z.number().int().min(0).nullable().optional(),
});
export type MealLogInsert = z.infer<typeof MealLogInsert>;

export const FoodItem = z.object({
  name: z.string().min(1).max(200),
  calories: z.number().min(0),
});
export type FoodItem = z.infer<typeof FoodItem>;

export const FoodAnalysisResult = z.object({
  items: z.array(FoodItem).min(1),
  total_calories: z.number().min(0),
});
export type FoodAnalysisResult = z.infer<typeof FoodAnalysisResult>;
```

- [ ] **Step 5: Create `subscription.ts`**

Create `packages/supabase/src/schemas/subscription.ts`:
```ts
import { z } from "zod";

export const PLANS = ["free", "basic", "pro"] as const;
export const STATUSES = ["active", "canceled", "past_due"] as const;

export const SubscriptionRow = z.object({
  id: z.string().uuid(),
  user_id: z.string().uuid(),
  stripe_customer_id: z.string().nullable(),
  stripe_subscription_id: z.string().nullable(),
  plan: z.enum(PLANS),
  status: z.enum(STATUSES),
  current_period_end: z.string().datetime().nullable(),
});
export type SubscriptionRow = z.infer<typeof SubscriptionRow>;
```

- [ ] **Step 6: Create `usage.ts`**

Create `packages/supabase/src/schemas/usage.ts`:
```ts
import { z } from "zod";

export const MONTH_REGEX = /^\d{4}-\d{2}$/;

export const UsageTrackingRow = z.object({
  user_id: z.string().uuid(),
  month: z.string().regex(MONTH_REGEX, "Month must be YYYY-MM"),
  bp_scans_used: z.number().int().min(0),
  meal_scans_used: z.number().int().min(0),
});
export type UsageTrackingRow = z.infer<typeof UsageTrackingRow>;
```

- [ ] **Step 7: Create the schemas index barrel**

Create `packages/supabase/src/schemas/index.ts`:
```ts
export * from "./bp.js";
export * from "./meal.js";
export * from "./subscription.js";
export * from "./usage.js";
```

- [ ] **Step 8: Run the tests to verify they pass**

```bash
npm run test -w @healthlog/supabase
```
Expected: every test in `schemas.test.ts` and `plans.test.ts` passes.

- [ ] **Step 9: Run typecheck**

```bash
npm run typecheck -w @healthlog/supabase
```
Expected: no errors.

- [ ] **Step 10: Commit**

```bash
git add packages/supabase/src/schemas packages/supabase/tests/schemas.test.ts
git commit -m "feat(supabase): add zod schemas for bp, meal, subscription, usage with tests"
```

---

## Task 10: Web client factories (server + browser)

**Files:**
- Create: `packages/supabase/src/web/server.ts`
- Create: `packages/supabase/src/web/browser.ts`

These thin wrappers use `@supabase/ssr` and pass through the generated `Database` type so query builders return typed results.

- [ ] **Step 1: Create `web/server.ts`**

Create `packages/supabase/src/web/server.ts`:
```ts
import { createServerClient } from "@supabase/ssr";
import type { CookieOptions } from "@supabase/ssr";
import type { Database } from "../types.js";

type CookieStore = {
  get(name: string): { value: string } | undefined;
  set(name: string, value: string, options?: CookieOptions): void;
};

/**
 * Create a Supabase client for use in Next.js Server Components,
 * route handlers, and server actions. Pass the result of
 * `cookies()` from `next/headers`.
 */
export function createSupabaseServerClient(
  cookieStore: CookieStore,
  options: { url: string; anonKey: string },
) {
  return createServerClient<Database>(options.url, options.anonKey, {
    cookies: {
      get(name: string) {
        return cookieStore.get(name)?.value;
      },
      set(name: string, value: string, options: CookieOptions) {
        cookieStore.set(name, value, options);
      },
      remove(name: string, options: CookieOptions) {
        cookieStore.set(name, "", { ...options, maxAge: 0 });
      },
    },
  });
}
```

- [ ] **Step 2: Create `web/browser.ts`**

Create `packages/supabase/src/web/browser.ts`:
```ts
import { createBrowserClient } from "@supabase/ssr";
import type { Database } from "../types.js";

/**
 * Create a Supabase client for use in Next.js Client Components.
 */
export function createSupabaseBrowserClient(options: {
  url: string;
  anonKey: string;
}) {
  return createBrowserClient<Database>(options.url, options.anonKey);
}
```

- [ ] **Step 3: Typecheck the package**

```bash
npm run typecheck -w @healthlog/supabase
```
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add packages/supabase/src/web
git commit -m "feat(supabase): add web/server and web/browser client factories"
```

---

## Task 11: Mobile client factory

**Files:**
- Create: `packages/supabase/src/mobile/index.ts`

- [ ] **Step 1: Create `mobile/index.ts`**

Create `packages/supabase/src/mobile/index.ts`:
```ts
import "react-native-url-polyfill/auto";
import { createClient } from "@supabase/supabase-js";
import AsyncStorage from "@react-native-async-storage/async-storage";
import type { Database } from "../types.js";

/**
 * Create a Supabase client for React Native. Sessions are persisted
 * in AsyncStorage so the user stays signed in across app launches.
 */
export function createSupabaseMobileClient(options: {
  url: string;
  anonKey: string;
}) {
  return createClient<Database>(options.url, options.anonKey, {
    auth: {
      storage: AsyncStorage,
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false,
    },
  });
}
```

- [ ] **Step 2: Add the URL polyfill dependency**

```bash
npm install react-native-url-polyfill@^2 -w @healthlog/supabase
```
Expected: package added to `dependencies` in `packages/supabase/package.json`.

`react-native-url-polyfill` is required because RN's `fetch` lacks WHATWG URL support; without it, supabase-js throws on the very first request. It's the standard fix recommended by the Supabase RN docs.

- [ ] **Step 3: Typecheck the package**

```bash
npm run typecheck -w @healthlog/supabase
```
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add packages/supabase/src/mobile packages/supabase/package.json package-lock.json
git commit -m "feat(supabase): add mobile client factory with AsyncStorage auth persistence"
```

---

## Task 12: Scaffold `apps/web` (Next.js 15)

**Files:**
- Create: `apps/web/` (entire Next.js project tree, via `create-next-app`)
- Modify: `apps/web/package.json` (rename, add workspace deps)
- Modify: `apps/web/tsconfig.json` (extend shared base)
- Create: `apps/web/eslint.config.js`

- [ ] **Step 1: Run create-next-app**

From the repo root:
```bash
npx create-next-app@latest apps/web \
  --typescript --tailwind --eslint --app --src-dir \
  --import-alias "@/*" --use-npm --skip-install
```
Expected: scaffolds `apps/web/` with App Router, Tailwind v4, src dir.

**If prompted interactively** for any flag the CLI didn't auto-accept (the create-next-app flag set shifts between versions):
- "Would you like to use Turbopack?" — **No** (Turborepo + Turbopack interactions can still be rough; webpack is safer for Phase 1)
- Any other prompt — accept the default

**If the command fails with "unknown flag"** for any of the flags above, drop that flag and accept the interactive default for it. The non-negotiables: TypeScript, App Router, src directory, Tailwind. Everything else can take defaults.

- [ ] **Step 2: Rename the workspace and add internal deps**

Read `apps/web/package.json` and edit it to:
- Set `"name": "@healthlog/web"`
- Add to `"dependencies"`: `"@healthlog/supabase": "*"`
- Add to `"devDependencies"`: `"@healthlog/eslint-config": "*"`, `"@healthlog/tsconfig": "*"`
- Add scripts: `"typecheck": "tsc --noEmit"`. Keep existing `dev`, `build`, `start`, `lint`.
- Remove `"private"` if present and re-add as `"private": true`.

The resulting `apps/web/package.json` `scripts` section should look like:
```json
"scripts": {
  "dev": "next dev",
  "build": "next build",
  "start": "next start",
  "lint": "next lint",
  "typecheck": "tsc --noEmit"
}
```

- [ ] **Step 3: Replace `apps/web/tsconfig.json`**

Overwrite `apps/web/tsconfig.json` with:
```json
{
  "extends": "@healthlog/tsconfig/nextjs.json",
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

- [ ] **Step 4: Install workspace dependencies**

From the repo root:
```bash
npm install
```
Expected: `@healthlog/supabase` and the tooling packages symlinked into `apps/web/node_modules`. Next.js's own deps install. No errors.

- [ ] **Step 5: Verify Next typecheck baseline passes**

```bash
npm run typecheck -w @healthlog/web
```
Expected: no errors. (Default scaffold is type-clean.)

- [ ] **Step 6: Commit**

```bash
git add apps/web/ package.json package-lock.json
git commit -m "chore(web): scaffold Next.js 15 app with workspace deps"
```

---

## Task 13: Web env validation + shadcn init + supabase wiring

**Files:**
- Create: `apps/web/src/env.ts`
- Create: `apps/web/.env.example`
- Create: `apps/web/components.json` (via `shadcn init`)
- Create: `apps/web/src/lib/utils.ts` (created by `shadcn init`)
- Create: `apps/web/src/lib/supabase/server.ts`
- Create: `apps/web/src/lib/supabase/client.ts`
- Modify: `apps/web/src/app/page.tsx` (placeholder)

- [ ] **Step 1: Install env validation deps**

```bash
npm install @t3-oss/env-nextjs zod -w @healthlog/web
```

- [ ] **Step 2: Create `src/env.ts`**

Create `apps/web/src/env.ts`:
```ts
import { createEnv } from "@t3-oss/env-nextjs";
import { z } from "zod";

export const env = createEnv({
  server: {
    SUPABASE_SERVICE_ROLE_KEY: z.string().optional(),
    STRIPE_SECRET_KEY: z.string().optional(),
    STRIPE_WEBHOOK_SECRET: z.string().optional(),
    STRIPE_BASIC_PRICE_ID: z.string().optional(),
    STRIPE_PRO_PRICE_ID: z.string().optional(),
  },
  client: {
    NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
    NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1),
    NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY: z.string().optional(),
    NEXT_PUBLIC_APP_URL: z.string().url().optional(),
  },
  runtimeEnv: {
    SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY,
    STRIPE_SECRET_KEY: process.env.STRIPE_SECRET_KEY,
    STRIPE_WEBHOOK_SECRET: process.env.STRIPE_WEBHOOK_SECRET,
    STRIPE_BASIC_PRICE_ID: process.env.STRIPE_BASIC_PRICE_ID,
    STRIPE_PRO_PRICE_ID: process.env.STRIPE_PRO_PRICE_ID,
    NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY:
      process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY,
    NEXT_PUBLIC_APP_URL: process.env.NEXT_PUBLIC_APP_URL,
  },
  skipValidation: !!process.env.SKIP_ENV_VALIDATION,
  emptyStringAsUndefined: true,
});
```

Stripe vars are `.optional()` in Phase 1 — they're required in Phase 4.

- [ ] **Step 3: Create `.env.example`**

Create `apps/web/.env.example`:
```
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
STRIPE_BASIC_PRICE_ID=
STRIPE_PRO_PRICE_ID=
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

- [ ] **Step 4: Initialize shadcn**

From `apps/web`:
```bash
cd apps/web && npx shadcn@latest init --yes --base-color neutral --css-variables && cd ../..
```
Expected: creates `components.json`, `src/lib/utils.ts`, updates `tailwind.config` (if v3 file present) and `src/app/globals.css` with shadcn CSS vars.

If shadcn complains about Tailwind v4 detection, accept its v4-mode default — it added Tailwind v4 support during 2025.

- [ ] **Step 5: Create the Supabase client wrappers**

Create `apps/web/src/lib/supabase/server.ts`:
```ts
import { cookies } from "next/headers";
import { createSupabaseServerClient } from "@healthlog/supabase/web/server";
import { env } from "@/env";

export async function createServerClient() {
  const cookieStore = await cookies();
  return createSupabaseServerClient(cookieStore, {
    url: env.NEXT_PUBLIC_SUPABASE_URL,
    anonKey: env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  });
}
```

Create `apps/web/src/lib/supabase/client.ts`:
```ts
"use client";

import { createSupabaseBrowserClient } from "@healthlog/supabase/web/browser";
import { env } from "@/env";

export function createBrowserClient() {
  return createSupabaseBrowserClient({
    url: env.NEXT_PUBLIC_SUPABASE_URL,
    anonKey: env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  });
}
```

- [ ] **Step 6: Replace the placeholder page**

Overwrite `apps/web/src/app/page.tsx`:
```tsx
export default function Page() {
  return (
    <main className="flex min-h-dvh flex-col items-center justify-center gap-4 px-6 py-24">
      <h1 className="text-5xl font-bold tracking-tight">HealthLog AI</h1>
      <p className="max-w-prose text-center text-sm text-muted-foreground">
        Phase 1 foundation. Auth, dashboard, AI logging, and billing land in
        later phases.
      </p>
    </main>
  );
}
```

- [ ] **Step 7: Copy `.env.example` to `.env.local` and fill with local Supabase keys**

```bash
cp apps/web/.env.example apps/web/.env.local
```

Edit `apps/web/.env.local`. The engineer needs the local Supabase keys — get them with:
```bash
supabase status
```

Fill in:
```
NEXT_PUBLIC_SUPABASE_URL=<API URL from supabase status>
NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon key from supabase status>
SUPABASE_SERVICE_ROLE_KEY=<service_role key from supabase status>
NEXT_PUBLIC_APP_URL=http://localhost:3000
```
Leave Stripe vars blank.

- [ ] **Step 8: Typecheck**

```bash
npm run typecheck -w @healthlog/web
```
Expected: no errors.

- [ ] **Step 9: Build the web app**

```bash
npm run build -w @healthlog/web
```
Expected: Next.js build completes. May print a warning about missing Stripe env vars — these are optional, ignore.

- [ ] **Step 10: Start dev and smoke-test in browser**

```bash
npm run dev -w @healthlog/web
```
Open `http://localhost:3000` — should render "HealthLog AI" heading and the subtitle. Stop the dev server with Ctrl+C.

- [ ] **Step 11: Commit**

```bash
git add apps/web/ package.json package-lock.json
git commit -m "feat(web): wire env validation, shadcn, supabase clients, and placeholder page"
```

---

## Task 14: Scaffold `apps/mobile` (Expo SDK 52)

**Files:**
- Create: `apps/mobile/` (entire Expo project tree, via `create-expo-app`)
- Modify: `apps/mobile/package.json`
- Modify: `apps/mobile/tsconfig.json`

- [ ] **Step 1: Run create-expo-app**

From the repo root:
```bash
npx create-expo-app@latest apps/mobile --template blank-typescript --no-install
```
Expected: scaffolds `apps/mobile/` with `App.tsx`, `app.json`, `babel.config.js`, etc.

- [ ] **Step 2: Rename the workspace and add internal deps**

Edit `apps/mobile/package.json`:
- Set `"name": "@healthlog/mobile"`
- Add `"private": true` if not present
- Add to `"dependencies"`: `"@healthlog/supabase": "*"`
- Add to `"devDependencies"`: `"@healthlog/eslint-config": "*"`, `"@healthlog/tsconfig": "*"`
- Add scripts: `"typecheck": "tsc --noEmit"`, `"lint": "eslint ."`

- [ ] **Step 3: Replace `apps/mobile/tsconfig.json`**

Overwrite `apps/mobile/tsconfig.json`:
```json
{
  "extends": "@healthlog/tsconfig/react-native.json",
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src/**/*", "App.tsx", "*.ts", "*.tsx"],
  "exclude": ["node_modules", ".expo", "ios", "android"]
}
```

- [ ] **Step 4: Install dependencies from the repo root**

```bash
npm install
```
Expected: Expo's deps install. Workspace symlinks created.

- [ ] **Step 5: Smoke-test the bare scaffold**

```bash
npm run start -w @healthlog/mobile
```
A QR code should appear. Quit with `q` or Ctrl+C. We're not testing the device render yet — we just want to confirm Metro starts.

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/ package.json package-lock.json
git commit -m "chore(mobile): scaffold Expo SDK 52 app with workspace deps"
```

---

## Task 15: Mobile NativeWind, Metro monorepo config, env validation

**Files:**
- Create: `apps/mobile/tailwind.config.js`
- Create: `apps/mobile/global.css`
- Create: `apps/mobile/metro.config.js`
- Modify: `apps/mobile/babel.config.js`
- Create: `apps/mobile/nativewind-env.d.ts`
- Create: `apps/mobile/.env.example`
- Create: `apps/mobile/src/env.ts`
- Modify: `apps/mobile/app.json` (add NativeWind plugin if needed)

- [ ] **Step 1: Install NativeWind + peer deps**

```bash
npm install nativewind@^4 -w @healthlog/mobile
npx expo install tailwindcss@^3.4 react-native-reanimated react-native-safe-area-context --workspace apps/mobile
```

`npx expo install` picks the SDK 52-compatible versions of native modules automatically. If it does not support `--workspace`, run it from `apps/mobile`:
```bash
cd apps/mobile && npx expo install react-native-reanimated react-native-safe-area-context && cd ../..
```

- [ ] **Step 2: Create `tailwind.config.js`**

Create `apps/mobile/tailwind.config.js`:
```js
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./App.tsx",
    "./src/**/*.{js,jsx,ts,tsx}",
  ],
  presets: [require("nativewind/preset")],
  theme: { extend: {} },
  plugins: [],
};
```

- [ ] **Step 3: Create `global.css`**

Create `apps/mobile/global.css`:
```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

- [ ] **Step 4: Update `babel.config.js`**

Overwrite `apps/mobile/babel.config.js`:
```js
module.exports = function (api) {
  api.cache(true);
  return {
    presets: [
      ["babel-preset-expo", { jsxImportSource: "nativewind" }],
      "nativewind/babel",
    ],
    plugins: [
      "react-native-reanimated/plugin",
    ],
  };
};
```

`react-native-reanimated/plugin` must be last per Reanimated docs.

- [ ] **Step 5: Create `metro.config.js`**

Create `apps/mobile/metro.config.js`:
```js
const { getDefaultConfig } = require("expo/metro-config");
const { withNativeWind } = require("nativewind/metro");
const path = require("path");

const projectRoot = __dirname;
const workspaceRoot = path.resolve(projectRoot, "../..");

const config = getDefaultConfig(projectRoot);

// Monorepo: tell Metro about the workspace root and use both node_modules paths.
config.watchFolders = [workspaceRoot];
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, "node_modules"),
  path.resolve(workspaceRoot, "node_modules"),
];
config.resolver.disableHierarchicalLookup = true;

// Enable workspace package resolution via package.json `exports`.
config.resolver.unstable_enablePackageExports = true;

module.exports = withNativeWind(config, { input: "./global.css" });
```

- [ ] **Step 6: Create the NativeWind TS declarations**

Create `apps/mobile/nativewind-env.d.ts`:
```ts
/// <reference types="nativewind/types" />
```

- [ ] **Step 7: Create `.env.example`**

Create `apps/mobile/.env.example`:
```
EXPO_PUBLIC_SUPABASE_URL=
EXPO_PUBLIC_SUPABASE_ANON_KEY=
EXPO_PUBLIC_WEB_URL=http://localhost:3000
```

- [ ] **Step 8: Create env validation**

Create `apps/mobile/src/env.ts`:
```ts
import { z } from "zod";

const schema = z.object({
  EXPO_PUBLIC_SUPABASE_URL: z.string().url(),
  EXPO_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1),
  EXPO_PUBLIC_WEB_URL: z.string().url().optional(),
});

export const env = schema.parse({
  EXPO_PUBLIC_SUPABASE_URL: process.env.EXPO_PUBLIC_SUPABASE_URL,
  EXPO_PUBLIC_SUPABASE_ANON_KEY: process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY,
  EXPO_PUBLIC_WEB_URL: process.env.EXPO_PUBLIC_WEB_URL,
});
```

Install zod for the mobile workspace:
```bash
npm install zod -w @healthlog/mobile
```

- [ ] **Step 9: Copy `.env.example` to `.env.local`**

```bash
cp apps/mobile/.env.example apps/mobile/.env.local
```
Fill in the same Supabase URL and anon key from `supabase status` as the web app uses.

Note: Expo only loads env vars prefixed with `EXPO_PUBLIC_` into the JS bundle. That's by design — anything not prefixed would be exposed to anyone with the .ipa/.apk.

- [ ] **Step 10: Commit**

```bash
git add apps/mobile/ package.json package-lock.json
git commit -m "chore(mobile): configure NativeWind, Metro monorepo resolution, env validation"
```

---

## Task 16: Mobile placeholder screen + React Navigation install

**Files:**
- Create: `apps/mobile/src/App.tsx`
- Modify: `apps/mobile/App.tsx` (re-export from src)

- [ ] **Step 1: Install React Navigation v7 packages**

```bash
npm install @react-navigation/native@^7 @react-navigation/native-stack@^7 @react-navigation/bottom-tabs@^7 -w @healthlog/mobile
npx expo install react-native-screens react-native-safe-area-context --workspace apps/mobile
```

If `--workspace` flag fails on `npx expo install`, run from `apps/mobile/`:
```bash
cd apps/mobile && npx expo install react-native-screens react-native-safe-area-context && cd ../..
```

These packages are installed but not wired up — Phase 1 ships a single placeholder screen. Navigation structure lands in Phase 2/3.

- [ ] **Step 2: Move the App component to `src/App.tsx`**

Create `apps/mobile/src/App.tsx`:
```tsx
import { StatusBar } from "expo-status-bar";
import { Text, View } from "react-native";
import "../global.css";

export default function App() {
  return (
    <View className="flex-1 items-center justify-center bg-white px-6">
      <StatusBar style="auto" />
      <Text className="text-3xl font-bold tracking-tight text-neutral-900">
        HealthLog AI
      </Text>
      <Text className="mt-2 text-center text-sm text-neutral-500">
        Phase 1 foundation. Camera, AI, and billing land in later phases.
      </Text>
    </View>
  );
}
```

- [ ] **Step 3: Update the root `App.tsx`**

Overwrite `apps/mobile/App.tsx`:
```tsx
export { default } from "./src/App";
```

- [ ] **Step 4: Update `app.json` for NativeWind (if needed)**

Edit `apps/mobile/app.json`. Under the `"expo"` key, ensure these settings exist (add `web.bundler` if missing, leave the rest as scaffolded):
```json
"web": {
  "bundler": "metro",
  "favicon": "./assets/favicon.png"
}
```

NativeWind v4 doesn't need an Expo config plugin — Metro config + Babel preset are sufficient.

- [ ] **Step 5: Typecheck**

```bash
npm run typecheck -w @healthlog/mobile
```
Expected: no errors.

- [ ] **Step 6: Smoke-test in Expo Go**

```bash
npm run start -w @healthlog/mobile
```
Expected: Metro bundler starts, prints QR code. Scan with Expo Go on a phone (or press `w` to open in web). Should show the placeholder screen with NativeWind styles applied (centered, large bold heading, gray subtitle).

If NativeWind classes don't apply, the babel preset isn't loading — clear the cache:
```bash
npm run start -w @healthlog/mobile -- --clear
```

Stop the dev server with `q` or Ctrl+C.

- [ ] **Step 7: Commit**

```bash
git add apps/mobile/ package.json package-lock.json
git commit -m "feat(mobile): add NativeWind-styled placeholder screen, install React Navigation"
```

---

## Task 17: `.claude/` project configuration + functions env example

**Files:**
- Create: `.claude/settings.json`
- Create: `.claude/settings.local.json`
- Create: `CLAUDE.md`
- Create: `supabase/functions/.env.example`

- [ ] **Step 1: Create `.claude/` directory**

```bash
mkdir -p .claude
```

- [ ] **Step 2: Create `.claude/settings.json`**

Create `.claude/settings.json`:
```json
{
  "permissions": {
    "allow": [
      "Bash(ls:*)",
      "Bash(cat:*)",
      "Bash(tree:*)",
      "Bash(find:*)",
      "Bash(rg:*)",
      "Bash(grep:*)",
      "Bash(git status)",
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git show:*)",
      "Bash(git branch)",
      "Bash(git branch:*)",
      "Bash(git remote -v)",
      "Bash(node --version)",
      "Bash(npm --version)",
      "Bash(npm install)",
      "Bash(npm install:*)",
      "Bash(npm ls:*)",
      "Bash(npm run dev:*)",
      "Bash(npm run build:*)",
      "Bash(npm run lint:*)",
      "Bash(npm run typecheck:*)",
      "Bash(npm run test:*)",
      "Bash(npm run db\\:*)",
      "Bash(npx tsc:*)",
      "Bash(npx vitest:*)",
      "Bash(supabase --version)",
      "Bash(supabase start)",
      "Bash(supabase stop)",
      "Bash(supabase status)",
      "Bash(supabase status:*)",
      "Bash(supabase db reset)",
      "Bash(supabase db reset:*)",
      "Bash(supabase db diff:*)",
      "Bash(supabase migration new:*)",
      "Bash(supabase migration list)",
      "Bash(supabase gen types:*)",
      "Bash(supabase test db)",
      "Bash(supabase test db:*)",
      "Bash(turbo:*)",
      "Bash(npx create-next-app:*)",
      "Bash(npx create-expo-app:*)",
      "Bash(npx shadcn:*)",
      "Bash(npx supabase init)"
    ],
    "deny": [
      "Bash(supabase db push:*)",
      "Bash(supabase db pull:*)",
      "Bash(supabase link:*)",
      "Bash(supabase secrets:*)",
      "Bash(supabase functions deploy:*)",
      "Bash(git push:*)",
      "Bash(git reset --hard:*)",
      "Bash(git clean:*)",
      "Bash(git branch -D:*)",
      "Bash(rm -rf:*)",
      "Bash(npm publish:*)",
      "Bash(docker rm:*)",
      "Bash(docker stop:*)"
    ]
  }
}
```

- [ ] **Step 3: Create empty local overrides file**

Create `.claude/settings.local.json`:
```json
{}
```

(`.gitignore` from Task 1 already excludes this file.)

- [ ] **Step 4: Create `CLAUDE.md`**

Create `CLAUDE.md`:
```markdown
# healthlog-ai — Project Memory

## What this is

A multi-phase monorepo for the HealthLog AI product. Each phase has a dated design spec in `docs/superpowers/specs/` and an implementation plan in `docs/superpowers/plans/`. Current phase: see the latest dated design under `docs/superpowers/specs/`.

## Layout

- `apps/web` — Next.js 15 (App Router, Tailwind v4, shadcn/ui). Workspace name `@healthlog/web`.
- `apps/mobile` — Expo SDK 52 + NativeWind v4 + React Navigation v7. Workspace name `@healthlog/mobile`.
- `packages/supabase` — `@healthlog/supabase`. Subpath exports: `/types`, `/schemas`, `/plans`, `/web/server`, `/web/browser`, `/mobile`.
- `tooling/tsconfig`, `tooling/eslint-config` — shared dev config.
- `supabase/` — migrations, pgTAP tests, `config.toml`.

## Database workflow (important)

- **Migrations are the source of truth.** Never edit the DB directly.
- After any schema change, regenerate types: `npm run db:types`.
- Run RLS tests after touching policies or migrations: `npm run db:test`.
- Local stack lives on Docker via `supabase start`. Get keys via `supabase status`.
- `supabase db push`, `link`, `secrets`, `functions deploy` are denied by default in `.claude/settings.json` because they touch the hosted project. Run them manually when intentional.

## Conventions

- Conventional Commits (`feat:`, `fix:`, `chore:`, `test:`, `docs:`, `refactor:`).
- Strict TypeScript everywhere. No `.js` files except config files.
- New top-level dependencies: ask before adding.
- Stripe and Gemini calls are server-side only (Edge Functions / API routes). Never expose service-role or AI keys to the client.

## Useful scripts

| Command | Effect |
|---|---|
| `npm run dev` | Both apps in parallel via Turborepo |
| `npm run typecheck` | tsc per workspace |
| `npm run test` | vitest in `packages/supabase` |
| `npm run db:start` | boot local Supabase (Docker) |
| `npm run db:reset` | re-apply all migrations |
| `npm run db:types` | regenerate `packages/supabase/src/types.ts` |
| `npm run db:test` | run pgTAP RLS isolation tests |
| `npm run db:migration <name>` | scaffold a new migration file |
```

- [ ] **Step 5: Create `supabase/functions/.env.example`**

```bash
mkdir -p supabase/functions
```

Create `supabase/functions/.env.example`:
```
GEMINI_API_KEY=
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
STRIPE_WEBHOOK_SECRET=
```

The `supabase/functions/` directory exists only to hold this `.env.example` in Phase 1. Function bodies arrive in Phase 3 (analyze-image) and Phase 4 (stripe-webhook).

- [ ] **Step 6: Commit**

```bash
git add .claude/settings.json CLAUDE.md supabase/functions/.env.example
git commit -m "chore: add Claude Code config, CLAUDE.md, and functions env example"
```

---

## Task 18: Add `lint`, `typecheck`, `test` scripts to remaining workspaces and propagate

**Files:**
- Modify: `apps/web/package.json`
- Modify: `apps/mobile/package.json`
- Create: `apps/web/eslint.config.js`
- Create: `apps/mobile/eslint.config.js`

This task ensures `turbo lint`, `turbo typecheck`, `turbo test` succeed at the root, exercising every workspace.

- [ ] **Step 1: Create `apps/web/eslint.config.js`**

The `create-next-app` scaffold uses `eslint-config-next` via the legacy `.eslintrc.json`. We're keeping `next lint` as the default, so leave Next's scaffolded config alone. Verify Next's lint works:

```bash
npm run lint -w @healthlog/web
```
Expected: no errors. If errors appear about unused vars on stub files, fix them (likely a leftover from the create-next-app default page).

- [ ] **Step 2: Create `apps/mobile/eslint.config.js`**

Create `apps/mobile/eslint.config.js`:
```js
import config from "@healthlog/eslint-config/react-native.js";
export default [
  ...config,
  {
    ignores: ["babel.config.js", "metro.config.js", "tailwind.config.js"],
  },
];
```

- [ ] **Step 3: Lint mobile**

```bash
npm run lint -w @healthlog/mobile
```
Expected: no errors. If errors appear in `App.tsx` (the original scaffold one), it should already be replaced with the re-export from Task 16; otherwise fix any lint complaints in `src/App.tsx`.

- [ ] **Step 4: Run all turbo tasks from the root**

```bash
npm run typecheck
```
Expected: all three workspaces (web, mobile, supabase) pass.

```bash
npm run lint
```
Expected: all pass.

```bash
npm run test
```
Expected: vitest in `packages/supabase` passes; web and mobile have no `test` script, so Turbo skips them.

- [ ] **Step 5: Commit**

```bash
git add apps/web/ apps/mobile/
git commit -m "chore: wire eslint configs across workspaces"
```

---

## Task 19: Full README

**Files:**
- Modify: `README.md` (replacing the stub from Task 1)

- [ ] **Step 1: Write the full README**

Overwrite `README.md`:

````markdown
# healthlog-ai

A monorepo for **HealthLog AI** — a health-logging product with a Next.js web dashboard and an Expo mobile app, backed by Supabase and Stripe.

This repository is built in phases. See `docs/superpowers/specs/` for design specs and `docs/superpowers/plans/` for implementation plans, both dated newest-first.

## Architecture

- **`apps/web`** — Next.js 15 (App Router, Tailwind v4, shadcn/ui)
- **`apps/mobile`** — Expo SDK 52 (React Native, NativeWind v4, React Navigation v7)
- **`packages/supabase`** — `@healthlog/supabase` shared package
  - `/types` — generated TypeScript types for the database
  - `/schemas` — zod schemas for inputs and AI responses
  - `/plans` — pricing/limit constants
  - `/web/server`, `/web/browser` — Next.js Supabase clients
  - `/mobile` — React Native Supabase client (AsyncStorage)
- **`supabase/`** — migrations (source of truth for the DB), pgTAP RLS tests, `config.toml`

### What is Supabase, briefly?

Supabase is a hosted Postgres with an authentication, storage, realtime, and edge functions layer on top. You define your database in versioned SQL migrations under `supabase/migrations/`. Row Level Security (RLS) policies live in those migrations and are enforced by Postgres on every query — even if app code forgets a `where user_id = ?` filter, the database refuses to leak another user's row. `auth.uid()` is a SQL function Supabase injects that returns the currently authenticated user's UUID, used in RLS policies like `using (auth.uid() = user_id)`.

You can run a full local Supabase stack on Docker for development (`supabase start`) and push the same migrations to a hosted project for staging/production (`supabase db push`).

## Prerequisites

- Node.js 20.x (the repo's `.nvmrc` pins this)
- npm 10+
- Docker Desktop (running) — for the local Supabase stack
- Supabase CLI: `brew install supabase/tap/supabase` (or see https://supabase.com/docs/guides/cli)

## Setup

```bash
# 1. Use Node 20
nvm use

# 2. Install dependencies
npm install

# 3. Start the local Supabase stack (Docker; first run pulls images)
npm run db:start

# 4. Apply migrations to the local DB
npm run db:reset

# 5. Generate TypeScript types from the local schema
npm run db:types

# 6. Print the local Supabase keys
npm run db:status

# 7. Copy and fill .env.local files (use the keys from step 6)
cp apps/web/.env.example apps/web/.env.local
cp apps/mobile/.env.example apps/mobile/.env.local
# edit both .env.local files, fill in the SUPABASE_URL and SUPABASE_ANON_KEY printed by db:status

# 8. Run everything
npm run dev
```

After step 8:
- Web app at http://localhost:3000
- Mobile bundler with QR code in the terminal — scan with Expo Go on a phone, or press `w` to open in the browser

## Daily workflow

| Command | What it does |
|---|---|
| `npm run dev` | Both apps in parallel |
| `npm run typecheck` | tsc on every workspace |
| `npm run lint` | ESLint on every workspace |
| `npm run test` | vitest in `packages/supabase` |
| `npm run db:start` | boot local Supabase |
| `npm run db:stop` | shut down local Supabase |
| `npm run db:status` | print local keys + URLs |
| `npm run db:reset` | re-apply all migrations to local DB |
| `npm run db:migration <name>` | create a new migration file |
| `npm run db:diff -f <name>` | diff the local DB and emit a migration |
| `npm run db:types` | regenerate `packages/supabase/src/types.ts` |
| `npm run db:test` | run pgTAP RLS isolation tests |

### Adding a schema change

1. `npm run db:migration add_some_column` — creates a new SQL file under `supabase/migrations/`.
2. Write the SQL.
3. `npm run db:reset` to re-run the local DB from scratch with the new migration applied.
4. `npm run db:types` to update the generated types.
5. `npm run db:test` to confirm RLS policies still pass.
6. Commit the migration file together with the types and any code changes.

## Testing

Three gates:

1. **pgTAP RLS isolation tests** (`supabase/tests/database/rls.test.sql`) — runs in a real Postgres via `npm run db:test`. Verifies user A cannot read or write user B's rows on every table.
2. **Vitest schema tests** (`packages/supabase/tests/`) — `npm run test`. Verifies zod schemas accept valid inputs and reject malformed ones.
3. **TypeCheck** — `npm run typecheck`. Strict mode across all workspaces.

## Hosted Supabase setup (when you're ready)

1. Create a project at https://supabase.com
2. In the dashboard, enable the **pg_cron** extension (Database → Extensions)
3. Link the CLI to your project: `supabase link --project-ref <ref>` (you'll be prompted for the db password)
4. Push migrations: `supabase db push`
5. In `apps/web/.env.local`, swap the local URL/anon key for the hosted project's values from the dashboard.

`supabase link`, `db push`, `secrets`, and `functions deploy` are intentionally denied in `.claude/settings.json` — they touch the hosted project, so Claude Code will prompt for permission every time you ask it to run them.

## What's coming in later phases

- **Phase 2** — Auth UI, basic dashboard reading from the DB
- **Phase 3** — AI integration via Supabase Edge Function (Gemini), mobile camera flow
- **Phase 4** — Stripe checkout, webhook, usage limit enforcement
- **Phase 5** — Realtime sync, print view, mobile profile/upgrade, CI

Each phase will land its own spec under `docs/superpowers/specs/` and plan under `docs/superpowers/plans/`.

## License

UNLICENSED (private project).
````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: write full README with setup, workflow, and Supabase intro"
```

---

## Task 20: Final acceptance verification

This task runs the acceptance criteria from section 12 of the design spec end-to-end. Nothing is committed — this is a verification gate.

- [ ] **Step 1: Verify Node version**

```bash
node --version
```
Expected: `v20.x.x`.

- [ ] **Step 2: Reinstall from scratch to verify clean install works**

```bash
rm -rf node_modules apps/*/node_modules packages/*/node_modules tooling/*/node_modules
npm install
```
Expected: completes without errors. Optional peer-dep warnings from `@supabase/ssr` requiring `next` (in the mobile workspace) are expected and harmless — they're optional peer deps.

- [ ] **Step 3: Confirm local Supabase is running**

```bash
supabase status
```
Expected: prints API URL, anon key, etc. If "stopped", run `npm run db:start` first.

- [ ] **Step 4: Reset DB and verify migrations apply cleanly**

```bash
npm run db:reset
```
Expected: completes without error.

- [ ] **Step 5: Run RLS tests**

```bash
npm run db:test
```
Expected: all 28 tests pass.

- [ ] **Step 6: Regenerate types and verify the file is non-empty and unchanged on a second run**

```bash
npm run db:types
git diff packages/supabase/src/types.ts
```
Expected first time: significant diff (or no diff if it was already up-to-date). Run again:
```bash
npm run db:types
git diff packages/supabase/src/types.ts
```
Expected second time: empty diff (idempotent).

- [ ] **Step 7: Typecheck every workspace**

```bash
npm run typecheck
```
Expected: passes for `@healthlog/supabase`, `@healthlog/web`, `@healthlog/mobile`.

- [ ] **Step 8: Run vitest schema tests**

```bash
npm run test
```
Expected: vitest passes.

- [ ] **Step 9: Lint**

```bash
npm run lint
```
Expected: no errors.

- [ ] **Step 10: Build web**

```bash
npm run build -w @healthlog/web
```
Expected: Next.js build completes; output written to `apps/web/.next/`.

- [ ] **Step 11: Start dev and visually confirm both apps**

```bash
npm run dev
```

In a browser open http://localhost:3000 — should render the "HealthLog AI" placeholder.

In another terminal, the Metro bundler should be running. Either:
- Scan the QR code with Expo Go on a phone, OR
- Press `w` in the Metro terminal to open the web build, OR
- In the Metro terminal press `j` to open the debugger (this also confirms Metro is serving)

The placeholder screen should render "HealthLog AI" centered with NativeWind styles.

Stop with Ctrl+C.

- [ ] **Step 12: Confirm subpath imports resolve in a quick TS smoke test**

Create a temporary file `apps/web/src/app/_smoke.ts`:
```ts
import type { Database } from "@healthlog/supabase/types";
import { PLAN_LIMITS } from "@healthlog/supabase/plans";
import { BpReadingInsert } from "@healthlog/supabase/schemas";
import { createSupabaseServerClient } from "@healthlog/supabase/web/server";
import { createSupabaseBrowserClient } from "@healthlog/supabase/web/browser";

type _Smoke = Database;
const _planLimit = PLAN_LIMITS.free.bpScans;
const _schema = BpReadingInsert;
const _server = createSupabaseServerClient;
const _browser = createSupabaseBrowserClient;

void _smoke;
void _planLimit;
void _schema;
void _server;
void _browser;
```

```bash
npm run typecheck -w @healthlog/web
```
Expected: passes. Then delete the smoke file:
```bash
rm apps/web/src/app/_smoke.ts
```

Repeat the same test for mobile — create `apps/mobile/src/_smoke.ts`:
```ts
import type { Database } from "@healthlog/supabase/types";
import { PLAN_LIMITS } from "@healthlog/supabase/plans";
import { createSupabaseMobileClient } from "@healthlog/supabase/mobile";

type _Smoke = Database;
const _p = PLAN_LIMITS.free.bpScans;
const _c = createSupabaseMobileClient;
void _p;
void _c;
```

```bash
npm run typecheck -w @healthlog/mobile
```
Expected: passes. Then delete the file:
```bash
rm apps/mobile/src/_smoke.ts
```

- [ ] **Step 13: Final git status check**

```bash
git status
```
Expected: clean working tree.

```bash
git log --oneline
```
Expected: roughly one commit per task in this plan, in order.

- [ ] **Step 14: Phase 1 done**

If every step above succeeded, Phase 1 is complete and the foundation is verified. Phase 2 will start with a new design spec for auth UI and basic dashboard.

No final commit needed — verification only.

---

## Notes on adapting the plan

- If `create-next-app` or `create-expo-app` adds or removes flags in 2026, accept their interactive defaults for anything not listed here, preferring TypeScript / src-dir / Tailwind where prompted.
- If `shadcn init` rejects Tailwind v4 detection on the day this plan is executed, drop to Tailwind v3 in the web app — the shadcn community has documented procedures for both.
- If `supabase test db` complains that `supabase_test_helpers` is missing, install it explicitly in a new migration: `create extension if not exists supabase_test_helpers with schema tests;`. The exact mechanism varies with CLI version.
- All `git commit` steps assume tests/typecheck/lint pass at the point of the commit. If any check fails, fix and re-run before committing — never `--no-verify`.
