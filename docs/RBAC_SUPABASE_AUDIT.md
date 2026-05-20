# RBAC Audit — Supabase Role Setup (Builder / Trade)

> ## Resolution — 2026-05-20 (branch `feat/rbac-lockdown`)
>
> The role-flip / orphan-stub gap surfaced by this audit is closed. **Role is now assigned exactly once at signup and is immutable from any client.** A user wanting both sides of the marketplace creates a second account (T&C copy update tracked separately).
>
> **Shipped in this PR:**
>
> | # | Change | File |
> | --- | --- | --- |
> | 1 | Dropped `user_roles_update_own` RLS policy; added `forbid_role_mutation` trigger that rejects any role change from non–`service_role` callers (42501). | `supabase/migrations/20260520000001_lock_user_role.sql` |
> | 2 | New append-only `user_role_events` audit table + `log_role_event` trigger (`reason='signup'` on INSERT, `reason='admin_change'` on UPDATE OF role). RLS lets users read their own history; admins read all. | `supabase/migrations/20260520000002_role_audit_log.sql` |
> | 3 | Narrowed `builder_profiles_select_authenticated` and `trade_profiles_select_authenticated` with `EXISTS (user_roles where role=…)` guards — orphan stubs are no longer readable. | `supabase/migrations/20260520000003_profile_role_consistency.sql` |
> | 4 | Deleted the orphan `register()` chain in `auth_remote_datasource.dart` / `auth_repository_impl.dart` / `auth_repository.dart`, the `SignUp` use case, and its unit test — they bypassed the role-bearing signup path. | `lib/features/auth/...`, `test/features/auth/domain/usecases/sign_up_test.dart` |
> | 5 | New integration test covering signup row-shape, blocked role flip, blocked admin escalation, and EXISTS-guarded cross-user SELECTs. Skipped unless `--dart-define=RBAC_INTEGRATION=true` is set against a shadow project. | `test/integration/rbac_test.dart` |
>
> **Explicitly deferred** (do not implement without a new decision):
> - Admin-driven role-change Edge Function (uses `service_role` to bypass the trigger; ship when the first support ticket arrives).
> - Any UI for role switching — the capability is being removed, not gated.
> - Phase-3 linked dual-role accounts.
> - Reputation-portability policy (separate decision).
>
> **Migration run order against prod** (paste at the bottom of the PR description; see also §10 of this doc):
> ```
> supabase/migrations/20260520000001_lock_user_role.sql
> supabase/migrations/20260520000002_role_audit_log.sql
> supabase/migrations/20260520000003_profile_role_consistency.sql
> ```
> Each migration has a DOWN block at the bottom of the file for emergency rollback.
>
> ---

**Date:** 2026-05-20
**Branch:** `feat/ui-updates` (audit) → `feat/rbac-lockdown` (resolution)
**Scope:** Role-assignment & authorization layer — `public.user_roles`, `handle_new_user` trigger, `custom_access_token` hook, RLS policies, and the Flutter side that writes/reads role.
**Question driving this audit:** Can a user end up created in *both* the `trade` and `builder` roles? Where does role come from for each sign-up path?

> **TL;DR — A user cannot have two roles.** `public.user_roles` has `PRIMARY KEY (user_id)`, so the database physically enforces one role per `auth.users` row. Every code path that writes to it uses `INSERT … ON CONFLICT (user_id) DO NOTHING` or `upsert(onConflict: 'user_id')`, so a second role assignment overwrites the first rather than creating a duplicate. The risk to watch is not duplication — it is **silent role flipping** and **orphan stub profiles** in the role table the user *didn't* pick.

---

## 1. The Schema — what role assignment actually looks like in Postgres

| Table | PK | Role-related shape | Source |
| --- | --- | --- | --- |
| `auth.users` | `id` | Supabase-managed. `raw_user_meta_data` may carry `{ role, full_name, phone }` set at sign-up. | (Supabase managed) |
| `public.profiles` | `id` → `auth.users(id)` | Universal — every authenticated user has exactly one row. No role column. | `20260511000001_initial_schema.sql:8-15` |
| `public.user_roles` | **`user_id` (PK)** → `auth.users(id)` | `role text NOT NULL DEFAULT 'trade' CHECK (role IN ('builder','trade','admin'))` | `20260511000001_initial_schema.sql:18-23` |
| `public.builder_profiles` | `id` → `profiles(id)` | Builder-only extension fields (company_name, abn, logo_url, …). | `20260511000001_initial_schema.sql:28-36` |
| `public.trade_profiles` | `id` → `profiles(id)` | Trade-only extension fields (primary_trade, hourly_rate, …). | `20260511000001_initial_schema.sql:41-53` |

**Key invariant:** `user_roles.user_id` is a PRIMARY KEY (not just `UNIQUE`). The database will reject a second `INSERT` for the same `user_id` outright. Two roles for one user is structurally impossible at the storage layer.

The fact that `builder_profiles` and `trade_profiles` are *separate* tables (rather than discriminator columns on one table) means the schema can technically hold a stub profile in both — that is the real risk surface, not `user_roles` itself. See §6.

---

## 2. The Sign-up Paths — where role is written

There are three live entry points into `user_roles`:

### Path A — Email sign-up with role chosen in /register

1. Flutter calls `SupabaseConfig.client.auth.signUp(…, data: { full_name, role })`.
   `auth_provider.dart:270-283`
2. `auth.users INSERT` fires the `on_auth_user_created` trigger →
   `public.handle_new_user()` reads `raw_user_meta_data->>'role'`.
   `20260516000002_forbid_self_admin.sql:18-38` (latest version of the function)
3. If role ∈ `{'builder','trade'}`:
   - `INSERT INTO profiles` (always)
   - `INSERT INTO user_roles` with that role
   - `INSERT INTO builder_profiles` *or* `INSERT INTO trade_profiles` (matching the chosen role only)
4. The next access-token issuance runs `public.custom_access_token(event)`, which selects from `user_roles` and injects `claims.user_role` into the JWT.
   `20260512000004_token_hook_role_optional.sql:11-40`

### Path B — SSO sign-up (Google / Apple)

1. `signInWithGoogle()` / `signInWithApple()` call `signInWithIdToken` — **no `role` is supplied** in metadata (the Google/Apple ID token has no concept of a Jobdun role).
   `auth_provider.dart:409-491`, `493-541`
2. `handle_new_user` sees `v_role IS NULL` → creates the `profiles` row only. **No `user_roles` row. No stub profile.**
   `20260516000002_forbid_self_admin.sql:26` (the `IF v_role IN ('builder','trade')` gate)
3. JWT hook finds no `user_roles` row → does *not* inject `user_role` claim.
   `20260512000004_token_hook_role_optional.sql:34-36`
4. On first `/home` visit, `_maybeShowRoleSheet` sees `auth.isRoleLoaded == true && auth.role == null` and presents the non-dismissible `RoleSelectionSheet`.
   `home_page.dart:77-85`, `role_selection_sheet.dart`
5. User taps a card → `setRoleAndStubProfile(role)` upserts `profiles`, `user_roles`, and the matching `builder_profiles` or `trade_profiles` row, then calls `auth.refreshSession()` so the new JWT carries the claim.
   `auth_provider.dart:883-928`

### Path C — Email sign-up that *did not* pass role (orphan code path)

`lib/features/auth/data/datasources/auth_remote_datasource.dart:46-69` exposes a `register({email, password, fullName})` method that **does not pass `role`** in `data:` — only `full_name`. If anything still calls this code path, it produces the SSO-style outcome (no role, RoleSelectionSheet on first home visit).

> **Flag — Orphan code, but worth verifying.** The active sign-up controller in `auth_provider.dart:238-322` is the canonical path and it *does* pass role. The repository/datasource pair appears to be vestigial from the original Clean Architecture scaffold. Either delete the unused `AuthRemoteDataSourceImpl.register` or update it to accept role — silent default to `trade` here would re-introduce the bug `20260512000002` was written to fix.

---

## 3. The JWT Claim — how the app reads role at runtime

`auth_provider.dart:80-119`:

```
UserRole? _roleFromSession() {  // 1st choice — JWT claim
  …claims['user_role'] as String?…
}
Future<UserRole?> _roleFromDb(String userId) async {  // 2nd choice
  …from('user_roles').select('role').eq('user_id', userId).maybeSingle()…
}

final role = _roleFromSession() ?? await _roleFromDb(userId);   // line 141
```

This dual lookup is deliberate: when the user has *just* picked a role in the sheet, the JWT in memory may still be the pre-pick one. The DB fallback prevents the sheet from re-firing on the next render.

**Source-of-truth ranking:**
1. `public.user_roles.role` (DB) — authoritative
2. JWT `claims.user_role` — derived from #1, refreshed each token issuance
3. `AuthState.role` (Flutter) — derived from #2 with #1 as fallback

The Flutter side never holds role independently — all writes go through the DB and refresh the JWT.

---

## 4. RLS Policies on user_roles

`20260511000006_rls.sql:44-74` (+ `20260511000009_rls_patch.sql:15-36`):

```
ENABLE ROW LEVEL SECURITY on public.user_roles;

POLICY user_roles_select_own   FOR SELECT   USING (auth.uid() = user_id)
POLICY user_roles_insert_own   FOR INSERT   WITH CHECK (auth.uid() = user_id AND role IN ('builder','trade'))
POLICY user_roles_update_own   FOR UPDATE   USING (auth.uid() = user_id)
                                            WITH CHECK (auth.uid() = user_id AND role IN ('builder','trade'))
-- No DELETE policy → no one can DELETE through PostgREST.
```

**Properties:**
- **Self-only writes.** A user can only ever write a `user_roles` row keyed to their own `auth.uid()`.
- **Admin escalation blocked at three layers** (defence in depth):
  1. `handle_new_user` ignores `role='admin'` from metadata. `20260516000002:26`
  2. RLS `WITH CHECK role IN ('builder','trade')` rejects client-side INSERT/UPDATE of admin.
  3. `forbid_self_admin` BEFORE INSERT trigger raises `42501` on any admin INSERT, regardless of role of the caller (so even a future bug elsewhere can't slip an admin row through). `20260516000002:45-59`
- **No DELETE policy** — a user cannot drop their role row. To change role they must `UPDATE`, which keeps the PK and replaces the value.

**Gap to flag (medium):**
- `user_roles_update_own` lets an authenticated user *flip their own role* from `trade ↔ builder` via a direct PostgREST upsert. In the supported UX, `RoleSelectionSheet` is only shown when `role == null`, so the only client-driven flip is the SSO first-pick. But the API itself allows a re-pick — an attacker (or a curious user with their own JWT) could `PATCH /user_roles?user_id=eq.<self>` with the opposite role and the database would accept it.
- **Why this matters.** When a user flips from builder → trade post-sign-up, their `builder_profiles` row stays behind (no cascade, no app-side cleanup). They now own both a builder stub and a trade stub. Joins keyed off `user_roles.role` will use trade; joins keyed off `builder_profiles` existence will still find a row. This is a join-correctness landmine, not an auth bug — but it deserves either:
  - tighten RLS to forbid UPDATE once a role exists (`USING (current_setting('app.allow_role_flip', true) = 'true')` or simpler: drop the update policy entirely and route flips through an Edge Function with audit trail), **or**
  - add a `DELETE` cascade from `user_roles` UPDATE that prunes the *other* role table.

---

## 5. RLS on the Role-extension Tables

`20260511000006_rls.sql:77-130`:

```
builder_profiles_select_authenticated  USING (auth.role() = 'authenticated')
builder_profiles_insert_own            WITH CHECK (auth.uid() = id)
builder_profiles_update_own            USING + WITH CHECK (auth.uid() = id)
-- (mirror policies on trade_profiles)
```

**Properties:**
- Writes are self-only (the row's PK must equal `auth.uid()`).
- Reads are **wide open to any authenticated user**. Necessary for `applications` joins (builders see trade profiles; trades see builder profiles) — but it also means any authenticated user can `SELECT *` against either table for any other user.
- This is the F-PRIV-01 / F-PRIV-02 surface called out in `docs/JOBDUN_BACKEND_AUDIT.md` and `MEMORY.md → project_audit_sprint_plan`. Not strictly an RBAC bug — it is a column-level privacy issue. The minimum-viable fix is the `profiles_public` security-invoker view added in `20260516000001:101-106`; the role-extension tables still need narrower SELECT scopes before launch.

---

## 6. The Two-Role Question — concrete answer

**Can a single user have two roles?**

- In `user_roles`: **no.** PK on `user_id` makes it physically one row. Confirmed.
- In `builder_profiles` and `trade_profiles`: **technically yes,** if the user uses the role-update path described in §4 (gap). The current sign-up paths (A and B) only ever write to one of the two stub tables, but a post-sign-up role flip leaves the previous stub behind.

**Sketch of the leak:**

```
1. SSO sign-up. handle_new_user creates profiles row. No user_roles row.
2. User picks "I'm hiring" → setRoleAndStubProfile(builder)
     ├── upsert profiles
     ├── upsert user_roles{role='builder'}
     └── upsert builder_profiles{id=user}
3. Bored user PATCHes user_roles to role='trade' directly via REST.
     RLS allows it (auth.uid() matches, role in allowed set).
4. App's next role read returns 'trade'. Home renders trade flow.
5. SELECT * FROM builder_profiles WHERE id = user;  -- still returns the stub.
```

The leftover row is itself blank in the sign-up case (no company_name, no logo) so practical exposure is small — but if the user filled in builder details before flipping, those details remain readable by any authenticated user via `builder_profiles_select_authenticated`.

---

## 7. Recommendations (ranked by impact)

| # | Issue | Action | Effort |
| --- | --- | --- | --- |
| 1 | `user_roles` UPDATE policy enables silent role flip + stub orphaning | Either drop `user_roles_update_own` (route role flips through a Postgres function or Edge Function), **or** add an `AFTER UPDATE` trigger that DELETEs the row in the now-unused extension table. | S — one migration |
| 2 | Orphan `auth_remote_datasource.dart` `register()` does not pass role | Delete it (the controller path in `auth_provider.dart:238` is the live one) or update it to accept role. Either way, remove the divergence so it can't be wired up later by mistake. | XS — delete unused method |
| 3 | `builder_profiles` / `trade_profiles` SELECT is `authenticated`-wide | Narrow with column lists (security-invoker views like `profiles_public`) or scope by relation (`EXISTS conversation/application linking the two users`). Tracked as F-PRIV-01/02 in the backend audit. | M — needs view design |
| 4 | `user_roles.role` DEFAULT is `'trade'` | The default never fires today (every writer supplies role), but it documents an old behavior. Drop the DEFAULT so a future bad insert fails fast instead of silently picking a side. | XS |
| 5 | Migration history has two role-handling generations of the same trigger (`…7`, `…12_2`, `…16_2`) | These are functionally idempotent (`CREATE OR REPLACE FUNCTION`), but the older files now misrepresent live behavior. Mark the older two as superseded in a comment header or fold into a single canonical migration before squashing for production. | XS — doc only |

---

## 8. Verification queries

Run these against the Supabase Postgres console to sanity-check the live state:

```sql
-- 1. Every authenticated user has exactly 0 or 1 user_roles row.
SELECT user_id, COUNT(*) FROM public.user_roles GROUP BY user_id HAVING COUNT(*) > 1;
-- Expected: zero rows. (PK guarantees this, but confirms PK is live.)

-- 2. No user holds stubs in both extension tables.
SELECT b.id FROM public.builder_profiles b
JOIN public.trade_profiles t ON t.id = b.id;
-- Expected: zero rows in clean state. Non-zero => §6 leak has fired in production.

-- 3. JWT hook is wired (admin must check Dashboard → Auth → Hooks too).
SELECT proname, prosecdef FROM pg_proc WHERE proname = 'custom_access_token';
-- Expected: row exists, prosecdef = true.

-- 4. forbid_self_admin trigger is attached.
SELECT tgname FROM pg_trigger WHERE tgname = 'user_roles_forbid_self_admin';
-- Expected: row exists.

-- 5. No admin row was created via the sign-up trigger.
SELECT user_id FROM public.user_roles WHERE role = 'admin';
-- Expected: zero rows in development; production admins must be inserted by superuser only.
```

---

## 9. Post-merge migration plan (prod)

These are the exact migrations to apply to the production Supabase project after this PR lands. Apply in order; each is idempotent and ships with a DOWN block in the file footer.

```
supabase/migrations/20260520000001_lock_user_role.sql
supabase/migrations/20260520000002_role_audit_log.sql
supabase/migrations/20260520000003_profile_role_consistency.sql
```

After applying, smoke-check from the SQL editor:

```sql
-- 1. forbid_role_mutation trigger exists on user_roles
SELECT tgname FROM pg_trigger WHERE tgname = 'trg_forbid_role_mutation';
-- expect: 1 row

-- 2. user_role_events table exists and is RLS-enabled
SELECT relname, relrowsecurity FROM pg_class WHERE relname = 'user_role_events';
-- expect: relrowsecurity = true

-- 3. log_role_event trigger exists on user_roles
SELECT tgname FROM pg_trigger WHERE tgname = 'trg_log_role_event';
-- expect: 1 row

-- 4. SELECT policies on the role-extension tables now reference user_roles
SELECT polname, pg_get_expr(polqual, polrelid)
  FROM pg_policy
  WHERE polrelid IN ('public.builder_profiles'::regclass,
                     'public.trade_profiles'::regclass)
    AND polcmd = 'r';
-- expect: USING expressions contain `EXISTS (... FROM ... user_roles ...)`

-- 5. user_roles UPDATE policy is gone (only SELECT + INSERT remain for client roles)
SELECT polname, polcmd FROM pg_policy WHERE polrelid = 'public.user_roles'::regclass;
-- expect: no row with polcmd='w' (UPDATE)
```

A post-deploy migration of existing data is *not* required — `user_role_events` starts empty (no historical replay) and existing builder/trade users already have matching `user_roles` rows, so the new EXISTS guards do not hide them.

---

## 10. Files referenced

| Path | Role |
| --- | --- |
| `supabase/migrations/20260511000001_initial_schema.sql` | Defines `profiles`, `user_roles`, `builder_profiles`, `trade_profiles` |
| `supabase/migrations/20260511000006_rls.sql` | All RLS policies including `user_roles_*` |
| `supabase/migrations/20260511000007_handle_new_user_trigger.sql` | Initial trigger (superseded) |
| `supabase/migrations/20260511000008_custom_access_token_hook.sql` | JWT hook v1 (superseded) |
| `supabase/migrations/20260511000009_rls_patch.sql` | Re-adds insert/update on `user_roles` |
| `supabase/migrations/20260512000002_handle_new_user_role_optional.sql` | Trigger v2 — role becomes optional (SSO path) |
| `supabase/migrations/20260512000004_token_hook_role_optional.sql` | JWT hook v2 — claim omitted if no row |
| `supabase/migrations/20260516000002_forbid_self_admin.sql` | Trigger v3 + `forbid_self_admin` defence trigger |
| `lib/features/auth/presentation/providers/auth_provider.dart` | Email signup (`register`), SSO (`signInWithGoogle/Apple`), role pick (`setRoleAndStubProfile`), role read (`_roleFromSession` / `_roleFromDb`) |
| `lib/features/auth/presentation/widgets/role_selection_sheet.dart` | Post-SSO role prompt |
| `lib/features/auth/data/datasources/auth_remote_datasource.dart` | Orphan datasource — `register()` does not pass role (recommendation #2) |
| `lib/features/home/presentation/pages/home_page.dart` | Fires `RoleSelectionSheet` when `role == null && isRoleLoaded` |
