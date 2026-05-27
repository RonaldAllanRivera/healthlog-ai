# healthlog-ai — Phase 1: Foundation (Design Spec)

**Date:** 2026-05-27
**Status:** Approved for implementation planning
**Scope:** Phase 1 of a 5-phase build. This phase establishes the monorepo, database schema, shared package, and minimal app shells. AI integration, billing, realtime, and feature UIs come in later phases.

---

## 1. Overview

Stand up the `healthlog-ai` monorepo with:

- npm workspaces + Turborepo
- Supabase (local CLI + hosted) as the source of truth for the database
- A shared `@healthlog/supabase` package exposing generated types, zod schemas, plan limits, and platform-specific client factories via subpath exports
- Minimal scaffolded `apps/web` (Next.js 15 + Tailwind v4 + shadcn) and `apps/mobile` (Expo SDK 52 + NativeWind v4)
- Three test gates: pgTAP RLS isolation tests, vitest schema tests, `tsc --noEmit` typecheck
- Project-level Claude Code configuration with a scoped allow-list

End state: a clean clone runs `npm install && supabase start && npm run db:reset && npm run db:test && npm run typecheck && npm run dev` to a green build, with both apps serving placeholder pages.

This document is also a Supabase intro for a first-time user — design choices include short "why" notes where the rationale isn't self-evident.

---

## 2. Scope

### In scope (Phase 1)

- Monorepo skeleton: root `package.json`, `turbo.json`, `tsconfig.json` (solution-style), `.gitignore`, `.nvmrc`, `README.md`
- `tooling/` directory with shared ESLint flat config + shared tsconfig bases
- `supabase/` directory: `config.toml`, initial migration creating all five tables + RLS + triggers + pg_cron, pgTAP RLS isolation test suite
- `packages/supabase/`: subpath-exported package with generated types stub, zod schemas, plan limits, and platform clients
- `apps/web/`: minimal Next.js 15 scaffold with Tailwind v4, shadcn init, env validation, single placeholder page
- `apps/mobile/`: minimal Expo SDK 52 scaffold with NativeWind v4, React Navigation v7, single placeholder screen
- Dev scripts on the root `package.json` for the full local workflow
- `.claude/settings.json` permission allow-list + deny-list
- `CLAUDE.md` at the repo root
- `.env.example` files in `apps/web/`, `apps/mobile/`, and `supabase/functions/`

### Out of scope (deferred to later phases)

- Supabase Edge Functions implementation — directory exists, `.env.example` lives there, but no function bodies (Phase 3 / Phase 4)
- Supabase Storage buckets and policies (Phase 3 — when image uploads land)
- Supabase Auth UI / login flow (Phase 2)
- Any feature pages on the web app beyond the placeholder (Phase 2+)
- Any feature screens on the mobile app beyond the placeholder (Phase 2+)
- Stripe products, checkout, webhook handler (Phase 4)
- Realtime subscription wiring (Phase 5)
- CI configuration (Phase 5)

---

## 3. Monorepo layout

```
healthlog-ai/
├── .claude/
│   ├── settings.json          # committed allow/deny list
│   └── settings.local.json    # gitignored, per-user
├── .gitignore
├── .nvmrc                     # 20
├── CLAUDE.md                  # project memory for Claude
├── README.md
├── package.json               # npm workspaces root, dev scripts
├── turbo.json
├── tsconfig.json              # solution-style references
├── docs/
│   └── superpowers/
│       └── specs/             # this spec lives here
├── tooling/
│   ├── eslint-config/         # @healthlog/eslint-config
│   │   ├── package.json
│   │   ├── base.js            # flat config, shared rules
│   │   ├── next.js            # extends base + next plugin
│   │   ├── react-native.js    # extends base + RN rules
│   │   └── node.js            # extends base for node packages
│   └── tsconfig/              # @healthlog/tsconfig
│       ├── package.json
│       ├── base.json
│       ├── nextjs.json
│       ├── react-native.json
│       └── package.json (lib)
├── supabase/
│   ├── config.toml
│   ├── migrations/
│   │   └── <timestamp>_initial_schema.sql
│   ├── seed.sql               # empty in Phase 1
│   └── tests/
│       └── rls.test.sql       # pgTAP isolation tests
├── packages/
│   └── supabase/              # @healthlog/supabase
│       ├── package.json
│       ├── tsconfig.json
│       ├── vitest.config.ts
│       ├── src/
│       │   ├── types.ts       # generated; placeholder stub committed
│       │   ├── plans.ts       # PLAN_LIMITS const
│       │   ├── schemas/
│       │   │   ├── index.ts
│       │   │   ├── bp.ts
│       │   │   ├── meal.ts
│       │   │   ├── subscription.ts
│       │   │   └── usage.ts
│       │   ├── web/
│       │   │   ├── server.ts
│       │   │   └── browser.ts
│       │   └── mobile/
│       │       └── index.ts
│       └── tests/
│           └── schemas.test.ts
└── apps/
    ├── web/                   # @healthlog/web
    │   ├── package.json
    │   ├── tsconfig.json
    │   ├── next.config.ts
    │   ├── postcss.config.mjs
    │   ├── components.json    # shadcn
    │   ├── .env.example
    │   ├── src/
    │   │   ├── app/
    │   │   │   ├── layout.tsx
    │   │   │   ├── page.tsx   # "HealthLog AI" placeholder
    │   │   │   └── globals.css
    │   │   ├── env.ts         # @t3-oss/env-nextjs + zod
    │   │   └── lib/
    │   │       └── supabase/  # re-exports from @healthlog/supabase/web/*
    │   └── tests/             # empty in Phase 1
    └── mobile/                # @healthlog/mobile
        ├── package.json
        ├── tsconfig.json
        ├── app.json
        ├── babel.config.js
        ├── metro.config.js
        ├── tailwind.config.js
        ├── global.css
        ├── .env.example
        └── src/
            ├── App.tsx        # placeholder screen
            └── env.ts         # zod validation of EXPO_PUBLIC_*
```

**Why `tooling/` separate from `packages/`:** `packages/` ships runtime code consumed by apps; `tooling/` is dev-time config. Turbo can cache them on different keys, and a tsconfig change shouldn't trigger an app rebuild.

---

## 4. Supabase schema

A single initial migration creates everything. The file is timestamp-prefixed (e.g., `20260527120000_initial_schema.sql`) — the `supabase migration new initial_schema` command produces this.

### 4.1 Tables

```sql
-- profiles: one row per auth user, created automatically by trigger.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  created_at timestamptz not null default now()
);

-- bp_readings: one row per blood pressure measurement.
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

-- meal_logs: one row per meal analyzed.
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

-- subscriptions: one row per user (enforced by unique(user_id)).
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

-- usage_tracking: one row per (user, month) pair, lazy-created.
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
```

**Deviations from the original spec, with rationale:**

| Original | Phase 1 design | Why |
|---|---|---|
| `profiles(id, user_id)` two columns | `profiles(id references auth.users)` | Canonical Supabase pattern. One column means one source of truth for the join key. |
| No CHECK constraints | CHECK on every numeric column | Gemini will occasionally emit garbage. Constraints stop bad data at the DB boundary. |
| `subscriptions` allows multiple per user | `unique(user_id)` | One Stripe customer = one subscription in this app's model. |
| `subscriptions.plan/status` free-text | CHECK constraints | Catches typos in webhook handler before they reach the DB. |
| No `updated_at` on subscriptions | `updated_at` with trigger | Subscription state changes; auditability requires knowing when. |
| pg_cron "resets" usage | pg_cron "cleans up" usage older than 6 months | Lazy per-month rows make reset redundant; cleanup keeps the table small. |

### 4.2 Triggers

```sql
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
```

**Why `security definer` on `handle_new_user`:** the trigger fires in the context of the auth schema; `security definer` lets it write to `public.profiles` regardless of the calling role. `set search_path = public` is the safety belt — without it, a malicious user could shadow `public.profiles` with their own table.

### 4.3 Row Level Security

RLS is enabled on every table. Policies are written so that even if the app forgets a `where user_id = ?` filter, the database refuses to return another user's row.

```sql
alter table public.profiles enable row level security;
alter table public.bp_readings enable row level security;
alter table public.meal_logs enable row level security;
alter table public.subscriptions enable row level security;
alter table public.usage_tracking enable row level security;

-- profiles: user reads/updates only their own row.
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- bp_readings: full CRUD on own rows.
create policy "bp_readings_select_own" on public.bp_readings
  for select using (auth.uid() = user_id);
create policy "bp_readings_insert_own" on public.bp_readings
  for insert with check (auth.uid() = user_id);
create policy "bp_readings_update_own" on public.bp_readings
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "bp_readings_delete_own" on public.bp_readings
  for delete using (auth.uid() = user_id);

-- meal_logs: full CRUD on own rows.
create policy "meal_logs_select_own" on public.meal_logs
  for select using (auth.uid() = user_id);
create policy "meal_logs_insert_own" on public.meal_logs
  for insert with check (auth.uid() = user_id);
create policy "meal_logs_update_own" on public.meal_logs
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "meal_logs_delete_own" on public.meal_logs
  for delete using (auth.uid() = user_id);

-- subscriptions: users can read their own row. Writes only via service role.
create policy "subscriptions_select_own" on public.subscriptions
  for select using (auth.uid() = user_id);

-- usage_tracking: users can read their own. Writes only via service role.
create policy "usage_tracking_select_own" on public.usage_tracking
  for select using (auth.uid() = user_id);
```

**Why subscriptions/usage_tracking are read-only to users:** if a user could `update subscriptions set plan = 'pro'` on themselves, they'd bypass billing entirely. Same logic for usage_tracking — a user could zero out their counter to dodge limits. Both tables are written exclusively by server-side code holding the service role key (Stripe webhook for subscriptions, Edge Function for usage).

### 4.4 Extensions and pg_cron

```sql
-- Enable extensions used in this migration.
create extension if not exists "pgcrypto";  -- gen_random_uuid()
create extension if not exists "pg_cron";

-- Monthly cleanup: drop usage_tracking rows older than 6 months.
-- Runs at midnight UTC on the 1st of each month.
select cron.schedule(
  'cleanup_old_usage_tracking',
  '0 0 1 * *',
  $$delete from public.usage_tracking
    where month < to_char(now() - interval '6 months', 'YYYY-MM')$$
);
```

**Hosted-project note:** `pg_cron` requires enabling in the Supabase dashboard (Database → Extensions). Local CLI enables it via `config.toml`. The README documents both.

---

## 5. `packages/supabase`

### 5.1 `package.json` exports

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
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "lint": "eslint ."
  },
  "dependencies": {
    "@supabase/supabase-js": "^2.45.0",
    "@supabase/ssr": "^0.5.0",
    "@react-native-async-storage/async-storage": "^2.0.0",
    "zod": "^3.23.0"
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

**Why optional peer deps:** `web/server` imports `next/headers`, which only exists in the Next.js app. The mobile entry imports React Native. Marking them optional prevents npm warnings in each consumer.

### 5.2 `src/types.ts` — initial stub

Committed as a placeholder until `npm run db:types` runs against the local DB:

```ts
// AUTO-GENERATED by `supabase gen types typescript --local`.
// Run `npm run db:types` after any migration change.
// This file is overwritten — do not edit by hand.

export type Json =
  | string | number | boolean | null
  | { [k: string]: Json | undefined }
  | Json[];

export type Database = Record<string, never>;
```

After the first `npm run db:types`, this file contains the full type graph for the schema in section 4.

### 5.3 `src/plans.ts` — single source of truth for limits

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
  const limit = kind === "bp"
    ? PLAN_LIMITS[plan].bpScans
    : PLAN_LIMITS[plan].mealScans;
  return used >= limit;
}
```

### 5.4 `src/schemas/` — zod schemas

One file per domain. Each exports:

- An *Insert* schema (validates client-submitted data before it touches the DB)
- A *Result* schema (validates AI-extracted data before saving — Phase 3 will use this)
- TypeScript types inferred from each schema

Example (`bp.ts`):

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

Constraints mirror the DB CHECK constraints exactly. Mismatches between zod and DB would let invalid data reach the DB layer or vice versa.

### 5.5 Client factories

Each platform entry exports a `createClient()` function. The factories are thin — they just wire up the right Supabase SDK helper for their environment.

- `web/server.ts` — `createServerClient` from `@supabase/ssr` reading cookies via `next/headers`. Used in Server Components, route handlers, server actions.
- `web/browser.ts` — `createBrowserClient` from `@supabase/ssr`. Used in Client Components.
- `mobile/index.ts` — `createClient` from `@supabase/supabase-js` with an AsyncStorage auth storage adapter.

All three are generic over `Database` from `./types` so consumers get typed query builders.

---

## 6. App scaffolds

### 6.1 `apps/web` — Next.js 15

Created with `npx create-next-app@latest apps/web --typescript --tailwind --eslint --app --src-dir --import-alias "@/*" --no-turbopack`. Modifications after:

- Update `package.json` name to `@healthlog/web`, mark `"private": true`
- Add `@healthlog/supabase` and `@healthlog/eslint-config` workspace dependencies
- Add `@t3-oss/env-nextjs` + `zod` for env validation
- Initialize shadcn with `npx shadcn@latest init` (neutral theme, CSS variables, RSC enabled)
- Replace `app/page.tsx` with a placeholder that renders "HealthLog AI" and a footer line "Phase 1 foundation. Apps land in later phases."
- `src/env.ts` validates the env vars listed in section 9
- `src/lib/supabase/server.ts` and `client.ts` re-export from `@healthlog/supabase/web/*` with the env vars wired in
- `.env.example` mirrors section 9

### 6.2 `apps/mobile` — Expo SDK 52

Created with `npx create-expo-app@latest apps/mobile --template blank-typescript`. Modifications after:

- Update `package.json` name to `@healthlog/mobile`, mark `"private": true`
- Add `@healthlog/supabase` and `@healthlog/eslint-config` workspace dependencies
- NativeWind v4 init: `nativewind`, `tailwindcss@^3.4`, `react-native-reanimated`, `react-native-css-interop` (NativeWind v4 uses Tailwind v3 internally — Tailwind v4 alpha doesn't yet support RN as of SDK 52)
- React Navigation v7 install: `@react-navigation/native`, `@react-navigation/native-stack`, `@react-navigation/bottom-tabs`, peer deps. Packages installed but not wired up in Phase 1 — the placeholder is a single screen; navigation structure lands in Phase 2 / Phase 3 when real screens arrive.
- `babel.config.js` configured for NativeWind + Reanimated
- `metro.config.js` configured for monorepo resolution (`watchFolders` includes repo root, `nodeModulesPaths` includes both app and root)
- `src/App.tsx` renders a "HealthLog AI" placeholder screen styled with NativeWind classes
- `src/env.ts` validates `EXPO_PUBLIC_*` vars with zod
- `.env.example` mirrors section 9

**NativeWind v4 vs Tailwind v4 caveat:** the project spec says "Tailwind v4" but NativeWind v4 still targets Tailwind v3.x. Web gets Tailwind v4 (via Next.js + PostCSS). Mobile gets Tailwind v3 (via NativeWind v4). The class syntax is identical for the utilities this project uses, so app-level code stays portable.

### 6.3 Metro monorepo resolution

Expo + monorepos require Metro to look outside the app directory. `apps/mobile/metro.config.js` adds:

```js
const { getDefaultConfig } = require("expo/metro-config");
const path = require("path");

const projectRoot = __dirname;
const workspaceRoot = path.resolve(projectRoot, "../..");

const config = getDefaultConfig(projectRoot);
config.watchFolders = [workspaceRoot];
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, "node_modules"),
  path.resolve(workspaceRoot, "node_modules"),
];
config.resolver.disableHierarchicalLookup = true;
module.exports = config;
```

Without this, importing `@healthlog/supabase/mobile` fails because Metro doesn't traverse up.

---

## 7. Dev workflow & scripts

### 7.1 Root `package.json`

```json
{
  "name": "healthlog-ai",
  "private": true,
  "workspaces": ["apps/*", "packages/*", "tooling/*"],
  "engines": { "node": ">=20.0.0" },
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
  }
}
```

### 7.2 `turbo.json`

```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "!.next/cache/**", "dist/**"]
    },
    "dev": { "cache": false, "persistent": true },
    "lint": { "outputs": [] },
    "typecheck": { "dependsOn": ["^build"], "outputs": [] },
    "test": { "dependsOn": ["^build"], "outputs": [] }
  }
}
```

`^build` means a workspace's typecheck depends on its dependencies having built — required because `@healthlog/supabase` is consumed by both apps.

---

## 8. Testing strategy — three gates

### 8.1 pgTAP RLS isolation tests (`supabase/tests/rls.test.sql`)

The critical security gate. Pattern:

```sql
begin;
select plan(40);  -- adjust to actual test count

-- Set up two synthetic users.
select tests.create_supabase_user('alice');
select tests.create_supabase_user('bob');

-- Sign in as alice.
select tests.authenticate_as('alice');

-- Insert a bp_reading as alice.
insert into public.bp_readings (user_id, systolic, diastolic)
  values (tests.get_supabase_uid('alice'), 120, 80);

-- alice can see her own row.
select results_eq(
  $$select count(*)::int from public.bp_readings$$,
  $$values (1)$$,
  'alice sees her own bp_reading'
);

-- Sign in as bob.
select tests.authenticate_as('bob');

-- bob sees zero rows.
select results_eq(
  $$select count(*)::int from public.bp_readings$$,
  $$values (0)$$,
  'bob cannot see alice''s bp_reading'
);

-- bob cannot update alice's row.
update public.bp_readings set systolic = 200
  where user_id = tests.get_supabase_uid('alice');
select results_eq(
  $$select count(*)::int from public.bp_readings where systolic = 200$$,
  $$values (0)$$,
  'bob cannot update alice''s bp_reading'
);

-- ... repeat the cross-user read/write checks for meal_logs, profiles, subscriptions, usage_tracking ...

select * from finish();
rollback;
```

Coverage per table: alice-sees-own (read), alice-writes-own (where applicable), bob-cannot-read-alices, bob-cannot-update-alices, bob-cannot-delete-alices. For subscriptions/usage_tracking, additionally test that even alice cannot insert/update her own rows (only the service role should).

The `tests.*` helpers come from the `supabase_test_helpers` extension, which the CLI auto-installs for `supabase test db`.

### 8.2 Vitest schema tests (`packages/supabase/tests/schemas.test.ts`)

For each schema, three categories:

- Valid input parses successfully
- Each constraint rejects malformed input with a descriptive zod error
- Inferred types align with the DB column types (verified by an assignability check at compile time)

Plus a test that `PLAN_LIMITS` is consistent (e.g., pro >= basic >= free for every limit).

### 8.3 Typecheck

`tsc --noEmit` in each workspace, orchestrated by `turbo typecheck`. Strict mode on across the board. The `packages/supabase` workspace builds first so apps consume real types, not stale stubs.

---

## 9. Environment variables

Three `.env.example` files, ready to be copied to `.env.local` (apps) or `.env` (supabase functions). Values blank in `.example`.

### `apps/web/.env.example`

```
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
STRIPE_BASIC_PRICE_ID=
STRIPE_PRO_PRICE_ID=
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=
NEXT_PUBLIC_APP_URL=
```

In Phase 1, only the first two are required for the placeholder page to start (and even those can be the local Supabase keys printed by `supabase start`). Stripe vars come into play in Phase 4. `src/env.ts` marks them optional for now.

### `apps/mobile/.env.example`

```
EXPO_PUBLIC_SUPABASE_URL=
EXPO_PUBLIC_SUPABASE_ANON_KEY=
EXPO_PUBLIC_WEB_URL=
```

### `supabase/functions/.env.example`

```
GEMINI_API_KEY=
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
STRIPE_WEBHOOK_SECRET=
```

Phase 1 creates the file. Functions implementation arrives in Phase 3 / Phase 4.

---

## 10. `.claude/` configuration

### 10.1 `.claude/settings.json`

```jsonc
{
  "permissions": {
    "allow": [
      "Bash(ls:*)", "Bash(cat:*)", "Bash(tree:*)", "Bash(find:*)",
      "Bash(rg:*)", "Bash(grep:*)",
      "Bash(git status)", "Bash(git status:*)",
      "Bash(git diff:*)", "Bash(git log:*)", "Bash(git show:*)",
      "Bash(git branch)", "Bash(git branch:*)", "Bash(git remote -v)",
      "Bash(node --version)", "Bash(npm --version)",
      "Bash(npm install)", "Bash(npm install:*)", "Bash(npm ls:*)",
      "Bash(npm run dev:*)", "Bash(npm run build:*)",
      "Bash(npm run lint:*)", "Bash(npm run typecheck:*)",
      "Bash(npm run test:*)", "Bash(npm run db\\:*)",
      "Bash(npx tsc:*)", "Bash(npx vitest:*)",
      "Bash(supabase --version)", "Bash(supabase start)",
      "Bash(supabase stop)", "Bash(supabase status)", "Bash(supabase status:*)",
      "Bash(supabase db reset)", "Bash(supabase db reset:*)",
      "Bash(supabase db diff:*)", "Bash(supabase migration new:*)",
      "Bash(supabase migration list)", "Bash(supabase gen types:*)",
      "Bash(supabase test db)", "Bash(supabase test db:*)",
      "Bash(turbo:*)",
      "Bash(npx create-next-app:*)", "Bash(npx create-expo-app:*)",
      "Bash(npx shadcn:*)", "Bash(npx supabase init)"
    ],
    "deny": [
      "Bash(supabase db push:*)", "Bash(supabase db pull:*)",
      "Bash(supabase link:*)", "Bash(supabase secrets:*)",
      "Bash(supabase functions deploy:*)",
      "Bash(git push:*)", "Bash(git reset --hard:*)",
      "Bash(git clean:*)", "Bash(git branch -D:*)",
      "Bash(rm -rf:*)", "Bash(npm publish:*)",
      "Bash(docker rm:*)", "Bash(docker stop:*)"
    ]
  }
}
```

### 10.2 `.claude/settings.local.json`

Empty `{}`. Gitignored.

### 10.3 `CLAUDE.md`

Short file at repo root. Contents:

- One-paragraph project description
- Monorepo layout summary with workspace names
- Database workflow rule: **migrations are the source of truth; never edit the DB directly; always `npm run db:types` after a schema change**
- Commit message convention (conventional commits)
- "Ask before adding new top-level dependencies"
- Current phase pointer: a single line like "Current phase: see `docs/superpowers/specs/` for the latest dated design." Avoids a stale phase number sitting in CLAUDE.md after Phase 2+ lands.

### 10.4 `.gitignore` additions for `.claude`

```
.claude/settings.local.json
```

---

## 11. README content

Sections:

1. **What is this?** — one paragraph
2. **Architecture** — bullet list of the three apps/packages
3. **Prerequisites** — Node 20, Docker (for local Supabase), Supabase CLI, npm
4. **Setup**
   1. Clone repo
   2. `nvm use` (picks up Node 20 from `.nvmrc`)
   3. `npm install` at the root
   4. `supabase start` — boots local Postgres + Auth + Storage on Docker; prints local keys
   5. `npm run db:reset` — applies migrations to local DB
   6. `npm run db:types` — generates TypeScript types
   7. Copy `.env.example` files to `.env.local` (apps) and fill in the keys printed by `supabase start`
   8. `npm run dev` — starts web (http://localhost:3000) and mobile (Metro bundler with QR code)
5. **Workflow** — how to add a migration, generate types, run tests
6. **Testing** — three gates explained
7. **Hosted Supabase project setup** — when you're ready: create project at supabase.com, enable `pg_cron` extension in dashboard, push migrations with `supabase db push` (manually, never auto-allowed)
8. **What's coming in later phases** — link to other specs once they exist

The README explicitly explains, for a Supabase first-timer, what migrations / RLS / `auth.uid()` are in one or two sentences each.

---

## 12. Acceptance criteria

A reviewer running the following commands from a clean clone must see them all succeed:

1. `nvm use && npm install` — completes without warnings beyond the optional peer-dep notices
2. `supabase start` — boots local stack, prints keys
3. `npm run db:reset` — applies the initial migration cleanly
4. `npm run db:test` — pgTAP suite passes, RLS isolation verified for all five tables
5. `npm run db:types` — regenerates `packages/supabase/src/types.ts` without diff after the second run
6. `npm run typecheck` — all workspaces pass
7. `npm run test` — vitest schema suite passes
8. `npm run lint` — no errors
9. `npm run dev`:
   - http://localhost:3000 renders the "HealthLog AI" placeholder
   - Metro bundler starts; QR code scannable; Expo Go renders the placeholder screen
10. Importing `@healthlog/supabase/types`, `/schemas`, `/plans`, `/web/server`, `/web/browser`, `/mobile` from a TypeScript file resolves with full types

If any step fails, Phase 1 is not done.

---

## 13. Risks and open items

- **`pg_cron` on hosted Supabase free tier:** historically required upgrading; the dashboard currently advertises it on all tiers but the user should verify in their project settings before pushing the initial migration.
- **NativeWind v4 + Tailwind v4 mismatch:** flagged in section 6.2. App-level code is portable; build configs differ. Not a blocker.
- **Expo SDK 52 + React Native New Architecture:** SDK 52 enables the new architecture by default. Some community libraries may lag. For Phase 1 we only ship a placeholder screen, so this is theoretical risk; revisit if a Phase 3 library throws.
- **Initial `types.ts` stub:** the committed stub is empty until `npm run db:types` runs. The README's setup order ensures this happens before any code consumes it.

---

## 14. Phase boundary

Phase 1 ends when all acceptance criteria pass and the repo is committed. Phase 2 starts with a new spec for the web auth UI and basic dashboard (reading bp_readings/meal_logs that don't yet exist — they'll arrive empty).
