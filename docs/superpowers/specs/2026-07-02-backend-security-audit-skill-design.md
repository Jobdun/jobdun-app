# Backend Security Audit Skill — Design Spec

**Date:** 2026-07-02
**Status:** Approved (design) — pending spec review
**Topic:** A repeatable, OWASP-anchored security audit skill for the Jobdun Supabase backend
**Companion skills:** `writing-skills`, `skill-creator`, `supabase`, `context7`

---

## 1. Problem

Jobdun's backend is a Supabase project: **82 migrations**, **4 Edge Functions** (`jobs-feed`, `push-send`, `verify-abn`, `verify-licence`), a JWT custom-claims hook (`custom_access_token_hook`), **5 storage buckets** (`avatars`, `company-logos`, `portfolio-images`, `verification-documents`, `job-attachments`), and RLS-reliant access control across ~10 core tables (`profiles`, `builder_profiles`, `trade_profiles`, `jobs`, `job_applications`, `messages`, `verification_documents`, `reviews`, `notifications`).

Security is verified today by **one-off manual audits** (e.g. `docs/BACKEND_FULL_AUDIT_2026-06-11.md`) that go stale the moment new migrations land — and several findings from that audit are **still OPEN**:

- **P0** — self-grantable trust signals (a user can set their own `verified`/trust flags)
- **P1** — PII overexposure (phone, exact coordinates, rates)
- **P1** — 15 unindexed foreign keys
- **P2** — Dart-model ↔ schema drift (7 phantom columns)
- Bundled **service-role key + Twilio creds** in old builds (rotation pending)
- `push-send` anon-key hardening still open

There is no repeatable, framework-anchored way to re-check the backend on demand. The installed `supabase` / `supabase-postgres-best-practices` skills are generic — neither knows Jobdun's tables, policies, functions, or the OWASP gates that matter for a Supabase/PostgREST backend.

## 2. Goal

A single Claude Code skill — **`backend-security-audit`** — that, on demand:

1. **Researches** current Supabase behavior via context7 and pins the current OWASP list versions.
2. **Discovers** the *actual current* backend state via scripts (drift-proof — no hardcoded table lists).
3. **Assesses** it against **OWASP API Security Top 10 (2023)** + **OWASP Top 10 (2021)**, classifying each gate **PASS / FAIL / BLOCKER** with `file:line` evidence.
4. **Drafts** ready-to-apply fixes (migrations/patches) for every FAIL/BLOCKER — **without** auto-applying.
5. **Writes** a dated report (`docs/SECURITY_AUDIT_<date>.md`) in the existing audit format, BLOCKERS first.

> **Plain-English requirement:** every OWASP category and every finding carries a "what this means in plain English" line so a non-security-specialist can understand the risk and the fix. This is a first-class output, not a footnote.

### Non-goals
- **Not** a Flutter client or Next.js admin-web audit — backend core only (locked scope).
- **Not** auto-applying fixes — drafts only; the human reviews and applies.
- **Not** a replacement for a professional pentest before a major launch — it's a continuous internal gate.
- **Not** a mechanical linter — regex-able checks live in the scripts; the SKILL.md focuses on judgment calls.

## 3. Locked decisions

| Axis | Decision |
|---|---|
| Scope | Supabase backend core (DB/RLS, Edge Functions, Auth/JWT, Storage, secrets) |
| Shape | One comprehensive audit skill (+ reference/script files) |
| Behavior | Audit **+ draft fixes** (no auto-apply) |
| Framework | OWASP API Security Top 10 (2023) **+** OWASP Top 10 (2021) |
| Grounding | **Approach C** — discovery scripts + baked-in research + dated report |

## 4. Architecture

```
.claude/skills/backend-security-audit/
  SKILL.md                     # overview · when-to-use · 5-step workflow · OWASP gate index · report format
  references/
    owasp-api-top10.md         # API Security Top 10 (2023) → Supabase/PostgREST checks + plain English
    owasp-web-top10.md         # Web Top 10 (2021) → Supabase checks + plain English (folds overlaps into API list)
    jobdun-threat-model.md     # anon-key surface, RLS reliance, edge-fn auth, bucket policies, JWT hook, trust boundaries
    fix-patterns.md            # canonical recipes: RLS template, DEFINER search_path pin, index-the-FK, secret rotation, CORS lock
  scripts/
    discover.sh                # enumerate tables/RLS/policies/DEFINER fns/FKs/storage policies from schema.sql (+ optional live db)
    grep-probes.sh             # static probes: service-role key in client, hardcoded secrets, unpinned search_path, open CORS, public buckets
  assets/
    report-template.md         # dated PASS/FAIL/BLOCKER skeleton matching BACKEND_FULL_AUDIT
```

**Rationale — progressive disclosure.** `SKILL.md` stays lean (the workflow + a one-line index of every gate + the report format). Heavy content lives in `references/` (loaded on demand) and `scripts/` (mechanical enumeration). This follows Anthropic's skill-authoring best practices and keeps `SKILL.md` well under the size budget. The `references/` and `scripts/` split is deliberate: **anything a regex can decide is a script; anything requiring judgment is prose in a reference file.**

## 5. Workflow (embedded in SKILL.md)

1. **Research** — use `context7` for current Supabase RLS / Edge Functions / Storage behavior and Postgres specifics; confirm the current OWASP list versions (API Security Top 10 = 2023 edition; Web Top 10 = 2021 edition). context7 supplies *library* accuracy; the OWASP category definitions come from OWASP itself.
2. **Discover** — run `scripts/discover.sh` and `scripts/grep-probes.sh` to build a live inventory of *this* backend: every table + whether RLS is enabled/forced, every policy and its `USING`/`WITH CHECK`, every `SECURITY DEFINER` function and whether `search_path` is pinned, every FK and whether it's indexed, every storage bucket and its policies, every Edge Function and its auth/CORS posture, and any secret usage in client-reachable code.
3. **Assess** — walk **every** OWASP gate against that inventory. Classify each: **PASS** (verified safe), **FAIL** (real weakness, fix needed), **BLOCKER** (exploitable now / data-exposing — fix before anything ships). Cite `file:line`. No gate may be skipped; "not applicable" must be justified in one line.
4. **Draft fixes** — for each FAIL/BLOCKER, emit a ready-to-apply migration or patch built from `references/fix-patterns.md`. **Do not apply.** Fixes go to `supabase/migrations/` drafts (or inline diffs) for the human to review and run. Keep matching rollbacks (per the repo's `supabase/rollbacks/` convention).
5. **Report** — write `docs/SECURITY_AUDIT_<date>.md` from `assets/report-template.md`: verdict, BLOCKERS first, then FAILs, then PASS ledger ("what was verified solid, don't re-litigate"), each finding with its plain-English explanation, OWASP tag, evidence, and the drafted fix reference.

## 6. OWASP coverage — with plain-English explanations

This is the heart of the skill. Each category below becomes a **gate** in the audit. Overlapping Web-Top-10 items are folded into the matching API item (marked ↔) so we don't double-audit.

### OWASP API Security Top 10 (2023)

**API1:2023 — Broken Object Level Authorization (BOLA)** ↔ A01:2021
- **Plain English:** *Can user A read or change user B's stuff just by knowing its ID?* In Supabase this is enforced almost entirely by Row Level Security. If a table's RLS is missing or too loose, anyone can pull anyone's rows.
- **Checks:** RLS enabled **and forced** on every table; every policy scopes rows to `auth.uid()` or a relationship; public views (`trade_profiles_public`, `builder_profiles_public`) expose only intended columns.
- **Known status:** verify the PII views still round coordinates to 2dp and gate rates.

**API2:2023 — Broken Authentication** ↔ A07:2021
- **Plain English:** *Can someone log in as another user, forge a token, or dodge the login?* Covers the JWT role-claim hook, admin promotion, and session/OTP settings.
- **Checks:** `custom_access_token_hook` integrity (role can't be spoofed); admin role non-self-assignable (`forbid_self_admin`); OTP expiry/session config; email confirmation on.

**API3:2023 — Broken Object Property Level Authorization** ↔ A01:2021
- **Plain English:** *Even if you're allowed to see a row, can you see or change fields you shouldn't* — read someone's phone number, or set your own `verified` flag to `true`? (This merges "mass assignment" + "excessive data exposure".)
- **Checks:** column-level `WITH CHECK` prevents users writing trust/verification/role columns; PII columns gated; PostgREST can't mass-assign protected fields.
- **Known status:** **OPEN P0 — self-grantable trust signals. This gate MUST FAIL until fixed.**

**API4:2023 — Unrestricted Resource Consumption**
- **Plain English:** *Can someone hammer an endpoint to run up your bill or knock the service over* — unlimited OTP sends, unbounded queries, push spam?
- **Checks:** pagination caps on feeds/search; rate limits on `push-send`, OTP, `search_trades`; Edge Functions bound work; no unbounded `select *` paths.

**API5:2023 — Broken Function Level Authorization** ↔ A01:2021
- **Plain English:** *Can a normal user call an admin-only function?* If a `SECURITY DEFINER` function doesn't pin `search_path` or check the caller's role, a regular user can escalate privileges.
- **Checks:** every `SECURITY DEFINER` fn pins `search_path`; `admin_set_user_status` / `admin_set_job_status` / `admin_broadcast` and peers verify `user_role = 'admin'`; no privilege-escalating helper is callable by `authenticated`.

**API6:2023 — Unrestricted Access to Sensitive Business Flows**
- **Plain English:** *Can someone abuse a legitimate flow at scale* — mass-create jobs, spam applications, blast broadcasts, farm verifications?
- **Checks:** per-user throttles on job/application creation and broadcasts; verification submission abuse controls; duplicate-guard on sensitive inserts.

**API7:2023 — Server-Side Request Forgery (SSRF)** ↔ A10:2021
- **Plain English:** *Can a user trick your server into calling a URL it shouldn't?* The `verify-abn` / `verify-licence` functions call external government APIs — those endpoints must be hard-coded, never user-supplied.
- **Checks:** external URLs in Edge Functions are constants; no user input flows into a fetch target; egress is limited to the known ABR/licence hosts.

**API8:2023 — Security Misconfiguration** ↔ A05:2021
- **Plain English:** *The boring-but-deadly stuff:* a storage bucket left public, the service-role key shipped in the app, wide-open CORS, RLS not forced.
- **Checks:** each bucket's public/private flag matches intent (`verification-documents` MUST be private); **service-role key never reachable from client code or bundled assets**; Edge Function CORS not `*` for authenticated routes; `search_path` and extension hygiene.
- **Known status:** **`.env` service-role/Twilio leak lives here — verify the split + rotation.**

**API9:2023 — Improper Inventory Management**
- **Plain English:** *Do you actually know every table/function/endpoint that exists, and does the schema match what the app expects?* Forgotten debug functions and drifted columns are where breaches hide.
- **Checks:** schema ↔ Dart-model drift (the 7 phantom columns); no leftover debug/test RPCs exposed to `authenticated`/`anon`; migrations inventory sane; deprecated columns (`budget_min`/type) not still readable in a sensitive way.

**API10:2023 — Unsafe Consumption of 3rd-party APIs**
- **Plain English:** *Do you blindly trust what ABR / licence registries / Twilio / FCM send back?* A compromised or malformed upstream response shouldn't be able to corrupt your data or crash the function.
- **Checks:** responses from `verify-abn`/`verify-licence`/Twilio/FCM are validated/typed before use; timeouts + error handling; no raw upstream HTML/JSON written straight to the DB.

### OWASP Web Top 10 (2021) — net-new items not already folded above

**A02:2021 — Cryptographic Failures**
- **Plain English:** *Are secrets and sensitive data actually protected?* Covers secret storage/rotation, encryption at rest, and TLS.
- **Checks:** service-role + Twilio rotation done; Hive AES key lives in Keychain/Keystore (not in code); no secrets committed to git; TLS enforced.

**A03:2021 — Injection**
- **Plain English:** *Can someone smuggle SQL or commands through an input field?* Mainly a risk in `SECURITY DEFINER` functions and any dynamic SQL.
- **Checks:** `search_trades` (and peers) keep input sanitised / parameterised; no string-concatenated SQL in DEFINER fns; PostgREST filter injection surface reviewed.

**A04:2021 — Insecure Design**
- **Plain English:** *Is security baked into the design, or bolted on afterward?* Trust boundaries and abuse-case thinking.
- **Checks:** marketplace trust posture is coherent (manual verification, no ABN-for-trades); trust boundaries between builder/trade/admin are explicit; sensitive flows have a documented abuse model.

**A06:2021 — Vulnerable & Outdated Components** *(limited backend scope)*
- **Plain English:** *Any known-vulnerable dependencies running server-side?*
- **Checks:** Edge Function Deno deps pinned + not known-vulnerable; Postgres extensions current; note (don't deep-audit) client packages — out of backend scope.

**A08:2021 — Software & Data Integrity Failures**
- **Plain English:** *Can the migration/CI pipeline be tampered with, or a bad migration slip through?*
- **Checks:** the down-migration gotcha guarded (rollbacks kept out of `migrations/`); CI runs on protected branches; no unpinned remote scripts executed in the pipeline.

**A09:2021 — Security Logging & Monitoring Failures**
- **Plain English:** *If something bad happened, would you even know?*
- **Checks:** admin actions and role changes are logged (`verification_events`, `user_role_events`); auth-sensitive events observable; audit trail can't be silently bypassed.

## 7. Report artifact

`docs/SECURITY_AUDIT_<date>.md`, generated from `assets/report-template.md`:

```
# Security Audit — <date>
## Verdict            (one line: ship / hold; BLOCKER count)
## BLOCKERS           (exploitable now — each: plain English · OWASP tag · file:line · drafted fix)
## FAILs              (real weaknesses — same structure, ranked)
## PASS ledger        ("verified solid, don't re-litigate")
## Drafted fixes      (list of migration/patch files written, not applied)
## Method             (context7 refs pulled, OWASP versions, scripts run)
```

Ranking = BLOCKER → FAIL, then by blast radius. Mirrors `BACKEND_FULL_AUDIT_2026-06-11.md` so the two are comparable over time.

## 8. Fix-drafting behavior

- Each FAIL/BLOCKER gets a concrete draft: a new `supabase/migrations/<ts>_<slug>.sql` **plus** a matching `supabase/rollbacks/` down-script, or an inline patch for Edge Function / config fixes.
- Drafts are **written but never applied or pushed** — the human reviews, runs `supabase db push`, and commits.
- Drafts follow `references/fix-patterns.md` canonical recipes so fixes are consistent and reviewable.
- Where a fix needs a **product decision** (e.g. which PII columns are public), the skill states the decision needed instead of guessing.

## 9. Drift-proofing (the scripts)

- `discover.sh` parses `supabase/schema.sql` (single source of truth, regenerated) to emit the current inventory — **no hardcoded table names**, so it never goes stale. Optional `--live` mode runs read-only introspection SQL against the linked project for ground truth.
- `grep-probes.sh` runs the mechanical checks: service-role key reachable from `lib/` or bundled assets, hardcoded secrets, `SECURITY DEFINER` without `SET search_path`, `cors` `*` in functions, public bucket declarations.
- Scripts emit machine-readable summaries the SKILL.md assessment step consumes — keeping judgment (prose) and enumeration (scripts) cleanly separated.

## 10. Validation (how we know the skill works)

The skill is **correct only if a fresh run re-finds the known-open issues.** Acceptance:

1. Running the audit flags **API3 BLOCKER** for self-grantable trust flags (the OPEN P0).
2. It flags **API8/A02** for the bundled service-role key / rotation.
3. It flags **API5** if any `SECURITY DEFINER` fn lacks a pinned `search_path`.
4. It flags **API1/API9** for the unindexed FKs / schema drift.
5. It does **not** raise false BLOCKERs on the verified-solid items from the 2026-06-11 audit (RLS-forced tables, sanitised `search_trades`, gated PII views).

If it misses (1)–(4) or false-positives (5), the skill is wrong and we iterate (per `writing-skills` RED→GREEN).

## 11. Build methodology

- Author with `writing-skills` (mechanical → scripts, judgment → prose) + `skill-creator` (description tuned for triggering).
- Follow the existing repo skill format (`app-store-review-check` / `play-review-check`): frontmatter `name` + `description`; body = Overview / When to Use / the gate procedure / report format.
- Keep `SKILL.md` under the size budget; push depth into `references/`.
- Validate against §10 before declaring done (`verification-before-completion`).

## 12. Risks & open questions

- **`schema.sql` freshness** — discovery trusts `supabase/schema.sql`; if it's stale vs. the live project, `--live` mode is the ground-truth fallback. The skill will warn when the two diverge.
- **Fix drafts touching live data** — any migration that alters RLS/policies is high-risk; drafts stay unapplied and carry rollbacks by default.
- **Scope creep** — client + admin-web are explicitly out of scope now; a follow-up skill can cover them later if wanted.
- **OWASP version drift** — list versions are pinned in the references and re-confirmed in step 1 each run.

---

## Next steps
1. Spec review (this doc) — user sign-off.
2. `writing-plans` → implementation plan for building the skill.
3. Build the skill (SKILL.md + references + scripts + template).
4. **Run the audit** against the live backend → `docs/SECURITY_AUDIT_2026-07-02.md`.
5. Review drafted fixes together; apply the BLOCKERs first.
