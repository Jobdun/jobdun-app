---
name: backend-security-audit
description: Use when auditing, hardening, or reviewing the security of the Jobdun Supabase backend — before a release, after changing migrations, RLS policies, Postgres functions, Edge Functions, storage buckets, auth/JWT, or secrets, or when asked whether the backend is secure or "bulletproof". Backend only — not the Flutter client or admin web.
---

# Backend Security Audit

## Overview

A repeatable, OWASP-anchored security audit of the **Jobdun Supabase backend**. It discovers the *current* state (drift-proof — nothing hardcoded), grades it against **OWASP API Security Top 10 (2023)** + **OWASP Top 10 (2021)**, reports **PASS / FAIL / BLOCKER** with `file:line`, and **drafts fixes it never auto-applies**. Companion to `play-review-check` / `app-store-review-check`; run before every release. Backend only.

## When to Use

- Before any release / TestFlight / Play submission
- After changing migrations, RLS, policies, Postgres functions, Edge Functions, storage buckets, auth/JWT config, or secrets
- When asked "is the backend secure / bulletproof / hardened"
- Periodically, to catch drift as migrations accumulate

**Not for:** Flutter client UI, admin web (Next.js), marketing site. Those need their own pass.

## The Workflow — do every step, in order

1. **Research.** Use `context7` (`mcp__context7__*`) for version-accurate Supabase behavior (RLS, Edge Functions auth, Storage policies) and Postgres specifics before relying on any API detail. Confirm the OWASP list versions: **API Security Top 10 = 2023**, **Web Top 10 = 2021**. context7 gives *library* accuracy; the OWASP category definitions come from the reference files here.
2. **Discover.** Read `references/jobdun-threat-model.md` FIRST, then run the scripts to build a live inventory of *this* backend:
   - `bash scripts/discover.sh` — tables, RLS enabled/forced, policies, `SECURITY DEFINER` functions (+ unpinned-`search_path` suspects), FKs, indexes, storage buckets.
   - `bash scripts/grep-probes.sh` — service-role reachable from client, `.env` bundled, hardcoded secrets, wildcard CORS, DEFINER without `search_path`.
   Regenerate `supabase/schema.sql` first if stale (`supabase db dump -f supabase/schema.sql`); use `discover.sh --live` for ground truth against the linked project.
3. **Assess.** Walk **every** gate in the index below. For each, use the matching reference file's Discover/PASS/FAIL criteria, inspect the evidence, and classify **PASS / FAIL / BLOCKER** with a `file:line` citation. No gate may be skipped; an "N/A" needs a one-line justification.
4. **Draft fixes.** For each FAIL/BLOCKER, build a fix from `references/fix-patterns.md` — a new `supabase/migrations/<ts>_<slug>.sql` **plus** a matching `supabase/rollbacks/` down-script, or an inline patch for Edge Function / config fixes. **DO NOT APPLY.** Never run `supabase db push`. If a fix needs a product decision (e.g. which PII is public), state the decision needed instead of guessing.
5. **Report.** Write `docs/SECURITY_AUDIT_<date>.md` from `assets/report-template.md`: verdict, BLOCKERS first, then FAILs, then a PASS ledger ("verified solid — don't re-litigate"). Every finding carries a **plain-English** explanation, its OWASP tag, the evidence, and the drafted-fix reference.

## Severity — how to classify

| Level | Meaning |
|---|---|
| **BLOCKER** | Exploitable now or actively exposing data: a user can read/modify another user's data, escalate privilege/trust, or a live secret is exposed. Fix before anything ships. |
| **FAIL** | A real weakness that isn't yet a live breach: missing defense-in-depth, weak rate limit, unindexed FK (DoS), PII broader than intended. Fix soon. |
| **PASS** | Verified safe. Record it in the ledger so it isn't re-litigated next run. |

## Gate index — walk ALL of these (no skips)

| Gate | One-line check | Reference |
|---|---|---|
| **API1** BOLA | RLS enabled+forced; policies scope rows to owner/relationship; public views don't leak | `references/owasp-api-top10.md` |
| **API2** AuthN | JWT `custom_access_token_hook` integrity; admin non-self-assignable; OTP/session config | ″ |
| **API3** Property-auth | Users can't write trust/verification/role columns; PII gated; no mass-assignment | ″ |
| **API4** Resource | Pagination caps; rate limits on push/OTP/search; bounded queries | ″ |
| **API5** Function-auth | `SECURITY DEFINER` pins `search_path`; `admin_*` RPCs role-gated | ″ |
| **API6** Business flows | Throttles on job/application/broadcast/verification abuse | ″ |
| **API7** SSRF | Edge Function external URLs are constants; no user-controlled fetch target | ″ |
| **API8** Misconfig | Bucket privacy correct; service-role never client-side; no wildcard CORS | ″ |
| **API9** Inventory | Schema↔Dart-model drift; no stray debug RPCs; deprecated columns | ″ |
| **API10** 3rd-party | Validate ABR/licence/Twilio/FCM responses; timeouts | ″ |
| **A02** Crypto | Secret rotation; Hive AES key in Keychain; no secrets in git; TLS | `references/owasp-web-top10.md` |
| **A03** Injection | DEFINER SQL sanitised/parameterised; no string-built SQL | ″ |
| **A04** Insecure design | Coherent trust boundaries; abuse model for sensitive flows | ″ |
| **A06** Components | Edge Deno deps pinned/not vulnerable; extensions current | ″ |
| **A08** Data integrity | Down-migration gotcha guarded; CI on protected branches | ″ |
| **A09** Logging | Admin actions + role changes logged; audit trail not bypassable | ″ |

(Web A01→API1/API3/API5, A05→API8, A07→API2, A10→API7 — audited under the API gate, not duplicated.)

## Rules — non-negotiable

- **Draft only.** Write fixes to `supabase/migrations/` (+ rollbacks) or as inline patches. NEVER apply, NEVER `supabase db push`, NEVER push git. The human reviews and applies.
- **Ground every finding** in a real `file:line`. No invented tables/policies. If you can't verify something from the files, say so explicitly in the report.
- **Product-decision findings** state the decision needed; don't guess a policy that changes product behavior.
- **Keep rollbacks** for every DB-mutating draft (repo convention: `supabase/rollbacks/`, never inside `migrations/`).
- **Plain English is mandatory** — every finding must be understandable by a non-security-specialist.

## Acceptance — regression baseline `docs/SECURITY_AUDIT_2026-07-02.md`

A fresh run is correct if it reproduces the validated 2026-07-02 state:

1. **Finds the 2 BLOCKERs:** `push-send` has no internal caller authorization (API5/API2 — anon key can push to anyone); conversation/message/application **identity columns are client-mutable** (API1/API3 — `WITH CHECK` only checks ownership + `GRANT ALL`).
2. **Confirms API3 PASS** — users canNOT self-grant `is_verified` (excluded from the per-column GRANTs); do **NOT** false-BLOCKER it (the old P0 is fixed).
3. **Confirms API5 PASS** — every `SECURITY DEFINER` function pins `search_path`.
4. **Flags the anon directory exposure** (API3/API8, F3) as needing a **product decision**, not an auto-fix.
5. **Does NOT** raise BLOCKERs on verified-solid items (RLS on all tables, gated PII views, private buckets, split secrets).

A regression from this baseline — a new table without RLS, a reverted column GRANT re-exposing `is_verified`, a new unpinned DEFINER fn, a new `GRANT ALL TO anon` — MUST surface as a fresh FAIL/BLOCKER. If a run misses (1), false-flags (2)/(3), or auto-"fixes" (4), the reference checks are wrong — fix them and re-run.

## Report format

`docs/SECURITY_AUDIT_<date>.md` — sections in order: **Verdict** · **BLOCKERS** · **FAILs** · **PASS ledger** · **Drafted fixes** (files written, unapplied) · **Method** (context7 refs, OWASP versions, scripts run). Ranked BLOCKER→FAIL, then by blast radius. Mirrors `docs/BACKEND_FULL_AUDIT_2026-06-11.md` so runs are comparable over time.
