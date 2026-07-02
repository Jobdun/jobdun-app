# OWASP Top 10 (2021) → Jobdun Supabase checks (net-new gates only)

Most Web-Top-10 access-control items are audited under the API list to avoid double-work. Only the **net-new** gates are detailed here.

**Redirect table — audited elsewhere:**

| Web (2021) | Audited under |
|---|---|
| A01 Broken Access Control | API1 (BOLA) + API3 (property) + API5 (function) |
| A05 Security Misconfiguration | API8 |
| A07 Identification & Auth Failures | API2 |
| A10 Server-Side Request Forgery | API7 |

Each gate below: **Plain English · Discover · PASS when · FAIL / BLOCKER when · Fix**.

---

## A02:2021 — Cryptographic Failures

**Plain English:** Are secrets and sensitive data actually protected — keys, tokens, data at rest, TLS?

**Discover:** `bash scripts/grep-probes.sh` (secret checks); confirm the `.env` split (client-safe `.env` vs gitignored `.env.server`) and the `validate.sh` guard; check whether the service-role + Twilio creds were **rotated** after the historical bundling leak; confirm the Hive cache AES key lives in Keychain/Keystore via `flutter_secure_storage`, not in code.

**PASS when:** no secrets in client code, bundled assets, or git; service-role + Twilio rotated after any known exposure; Hive key in Keychain/Keystore; TLS enforced everywhere.

**FAIL / BLOCKER when:** a **live** secret is client-reachable or bundled → **BLOCKER**; rotation still pending after a known leak → **FAIL/BLOCKER** by exposure window.

**Fix:** `fix-patterns.md → Secret rotation checklist`.

## A03:2021 — Injection

**Plain English:** Can someone smuggle SQL or commands through an input field? For this backend the risk lives in `SECURITY DEFINER` functions and any dynamic SQL.

**Discover:** read `search_trades` and other DEFINER functions for string-concatenated SQL vs. parameterised/`format(%L)`/`quote_literal`; check PostgREST filter surfaces for anything reflected into SQL.

**PASS when:** DEFINER SQL is parameterised or properly quoted (`search_trades` is DEFINER + sanitised per the prior audit); no user input concatenated into a query string.

**FAIL / BLOCKER when:** user input is concatenated into SQL inside a DEFINER function → **BLOCKER**.

**Fix:** `fix-patterns.md → Parameterise DEFINER SQL`.

## A04:2021 — Insecure Design

**Plain English:** Is security baked into the design, or bolted on afterward? Are the trust boundaries and abuse cases thought through?

**Discover:** read `references/jobdun-threat-model.md`; confirm the marketplace posture is coherent (manual verification, **no ABN-for-trades**); confirm trust boundaries between builder / trade / admin are explicit; check each sensitive flow (verification, messaging, broadcast) has a documented abuse model.

**PASS when:** trust boundaries are explicit and consistent; sensitive flows have an abuse model; no implicit "trust the client" assumptions.

**FAIL when:** a sensitive flow has no abuse model; trust boundaries are implicit or contradictory.

**Fix:** document the boundary/abuse-model in the threat model; add the missing control (cross-refs an API-gate fix).

## A06:2021 — Vulnerable & Outdated Components (backend scope only)

**Plain English:** Are any known-vulnerable dependencies running **server-side**?

**Discover:** read `supabase/functions/deno.json` + import maps — are Deno deps pinned to explicit versions (not floating)? Check Postgres extension versions in the schema.

**PASS when:** Edge Function deps pinned to explicit, non-vulnerable versions; extensions current.

**FAIL when:** floating/unpinned imports; an outdated extension with a known CVE. (Flutter client packages are out of backend scope — note, don't deep-audit.)

**Fix:** pin imports to explicit versions; bump flagged extensions.

## A08:2021 — Software & Data Integrity Failures

**Plain English:** Can the migration or CI pipeline be tampered with, or a bad/`down` migration slip through and run forward?

**Discover:** confirm rollback/`down` scripts live in `supabase/rollbacks/` and **never** inside `supabase/migrations/` (the CLI runs anything in `migrations/` forward — the documented gotcha); check CI runs on `main`/`develop`; check no unpinned remote script is `curl|bash`-ed in the pipeline.

**PASS when:** `migrations/` is forward-only; rollbacks isolated in `supabase/rollbacks/`; CI gated on protected branches; no unpinned remote code executed in CI.

**FAIL when:** a `down`/rollback `.sql` sits in `migrations/` (would apply forward and drop/alter objects); CI missing on a protected branch.

**Fix:** `fix-patterns.md → Move down-scripts out of migrations/`.

## A09:2021 — Security Logging & Monitoring Failures

**Plain English:** If something bad happened, would you even know? Are privileged actions recorded?

**Discover:** confirm `verification_events` and `user_role_events` (or equivalent) capture admin actions + role changes; check the audit trail isn't user-writable (can't be silently erased); check auth-sensitive events are observable.

**PASS when:** admin actions and role changes are logged to an append-style audit table not writable by ordinary users; sensitive auth events observable.

**FAIL when:** admin mutations aren't logged; the audit table is user-writable/deletable.

**Fix:** add audit triggers on privileged mutations; lock down the audit table with RLS (insert-only via DEFINER).
