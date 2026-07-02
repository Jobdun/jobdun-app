# Fix patterns — canonical drafted-fix recipes

Copy-paste templates for the **Draft fixes** step. Rules:
- Draft into `supabase/migrations/<ts>_<slug>.sql`; **never apply**, never `supabase db push`.
- Every DB-mutating recipe has a matching **Rollback** for `supabase/rollbacks/` (never place a down-script inside `migrations/`).
- `<placeholders>` in angle brackets must be filled from the discovery output.
- Where a recipe changes product behavior, flag it as **needs product decision** in the report rather than guessing.

---

## Enable + force RLS

```sql
-- <ts>_rls_<table>.sql
ALTER TABLE public.<table> ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.<table> FORCE  ROW LEVEL SECURITY;   -- also applies to table owner
```
**Rollback:** `ALTER TABLE public.<table> NO FORCE ROW LEVEL SECURITY; ALTER TABLE public.<table> DISABLE ROW LEVEL SECURITY;`
**Risk:** low — but a table with RLS on and NO policies denies all access; pair with the owner-scoped policy below.

## Owner-scoped policy (read + write)

```sql
-- <ts>_policy_<table>_owner.sql
CREATE POLICY "<table>_select_own" ON public.<table>
  FOR SELECT TO authenticated
  USING (<owner_col> = (select auth.uid()));

CREATE POLICY "<table>_modify_own" ON public.<table>
  FOR ALL TO authenticated
  USING      (<owner_col> = (select auth.uid()))
  WITH CHECK (<owner_col> = (select auth.uid()));
```
**Rollback:** `DROP POLICY "<table>_select_own" ON public.<table>; DROP POLICY "<table>_modify_own" ON public.<table>;`
**Note:** `(select auth.uid())` wraps the call so the planner caches it per-statement (Supabase RLS perf best practice). For relationship scoping, replace the predicate with an `EXISTS (…)` over the join table.

## Column-guard WITH CHECK — the self-grant / mass-assignment fix (API3)

Stop users writing trust/verification/role columns on their own row. Two-layer: revoke column privilege AND a guard trigger (defense-in-depth).

```sql
-- <ts>_guard_<table>_trust_cols.sql
-- Layer 1: never let the client UPDATE these columns via PostgREST
REVOKE UPDATE (<verified_col>, <trust_col>, <role_col>, <rating_col>) ON public.<table> FROM authenticated, anon;

-- Layer 2: belt-and-suspenders trigger (blocks any path, incl. future grants)
CREATE OR REPLACE FUNCTION public.forbid_trust_self_edit()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  IF NEW.<verified_col> IS DISTINCT FROM OLD.<verified_col>
     OR NEW.<trust_col>  IS DISTINCT FROM OLD.<trust_col>
     OR NEW.<role_col>   IS DISTINCT FROM OLD.<role_col> THEN
    RAISE EXCEPTION 'trust/verification/role columns are system-managed';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER trg_forbid_trust_self_edit
  BEFORE UPDATE ON public.<table>
  FOR EACH ROW EXECUTE FUNCTION public.forbid_trust_self_edit();
```
**Rollback:** `DROP TRIGGER trg_forbid_trust_self_edit ON public.<table>; DROP FUNCTION public.forbid_trust_self_edit(); GRANT UPDATE (<...cols>) ON public.<table> TO authenticated;`
**Risk:** medium — verify the legitimate write path (admin RPC / DEFINER) still sets these. **Trust flags must only be set by an admin/service path.**

## DEFINER search_path pin (API5)

```sql
-- <ts>_pin_search_path_<fn>.sql
ALTER FUNCTION public.<fn>(<arg_types>) SET search_path = '';
-- If the body uses unqualified names, either fully-qualify them (public.foo)
-- or use:  SET search_path = 'public, pg_temp';
```
**Rollback:** `ALTER FUNCTION public.<fn>(<arg_types>) RESET search_path;`
**Risk:** medium — an empty `search_path` requires schema-qualified references inside the function; test the function after.

## Index the foreign key (API1 / scalability)

```sql
-- <ts>_index_fk_<table>_<col>.sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_<table>_<col> ON public.<table> (<fk_col>);
```
**Rollback:** `DROP INDEX CONCURRENTLY IF EXISTS public.idx_<table>_<col>;`
**Risk:** low. `CONCURRENTLY` can't run inside a txn block — this migration must not be wrapped in BEGIN/COMMIT.

## Private bucket + storage policy (API8)

```sql
-- <ts>_bucket_<name>_private.sql
UPDATE storage.buckets SET public = false WHERE id = '<bucket>';

CREATE POLICY "<bucket>_owner_rw" ON storage.objects
  FOR ALL TO authenticated
  USING      (bucket_id = '<bucket>' AND owner = (select auth.uid()))
  WITH CHECK (bucket_id = '<bucket>' AND owner = (select auth.uid()));
```
**Rollback:** `DROP POLICY "<bucket>_owner_rw" ON storage.objects; UPDATE storage.buckets SET public = true WHERE id = '<bucket>';`
**Risk:** medium — flipping a bucket private breaks any code using a plain public URL; move those reads to signed URLs first. **Needs product decision** if the bucket was intentionally public.

## Edge CORS lock (API8)

```ts
// supabase/functions/_shared/cors.ts  (patch)
const ALLOWED = new Set(["https://jobdun.com.au", "https://admin.jobdun.com.au"]);
export function corsHeaders(origin: string | null) {
  const allow = origin && ALLOWED.has(origin) ? origin : "https://jobdun.com.au";
  return { "Access-Control-Allow-Origin": allow, "Vary": "Origin",
           "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
}
```
**Rollback:** restore the previous `cors.ts`.
**Risk:** low — but confirm every real client origin is in the allowlist before shipping.

## Secret rotation checklist (A02) — no migration; operational

1. Rotate the **service-role key** (Supabase dashboard → API → roll). Update `.env.server` + CI secrets. Redeploy Edge Functions.
2. Rotate **Twilio** auth token; update `supabase/functions/.env` + CI.
3. Confirm the client `.env` contains **only** the anon key + public config; `.env.server` is gitignored; `validate.sh` guard is green.
4. Confirm no old build/artifact still ships the old key (the exposure window is why rotation is mandatory, not optional).

## Parameterise DEFINER SQL (A03)

```sql
-- inside the function: never concatenate user input
EXECUTE format('SELECT * FROM public.<t> WHERE name ILIKE %L', '%' || <arg> || '%');
-- %L quotes as a literal; prefer plain parameterised queries where possible.
```
**Rollback:** restore prior function body.

## Move down-scripts out of migrations/ (A08)

Operational, not SQL: `git mv supabase/migrations/<down>.sql supabase/rollbacks/`. The Supabase CLI applies **everything** in `migrations/` forward — a stray `down` there will drop/alter objects on the next `db push`.
**Rollback:** n/a (moving a file out of harm's way).
