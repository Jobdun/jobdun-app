# Jobdun Backend Audit — Executive Summary

**Overall verdict:** **RED** for 25k AU users
**Date:** 2026-05-16
**Auditor count:** 8 specialists + 1 synthesizer

7 of 8 specialist reports returned RED; only schema returned AMBER (and that report itself says "leaning RED on verification"). The relational core is genuinely well-built — real Postgres enums, UUID PKs, RLS on every table, an immutable consent trail, sensible unique constraints. But the platform is **not shippable to 25k Australians today**: core features (verification, messaging, job search) are broken at runtime against the deployed schema, any signup can self-promote to admin, every user can scrape the full PII directory, there is zero trust-&-safety infrastructure, zero observability, and the published privacy policy promises Privacy Act rights that have no implementation behind them.

---

## TL;DR for Ken

- **Three of your headline features are dead on arrival, not slow — broken.** The Dart app reads/writes ~20 columns that no migration ever created. Verification upload, the entire messaging inbox, and job keyword search all 400 the moment a real user touches them. The inbox silently falls back to mock data ("Pinnacle Construct") and you'll burn days chasing it. This is the single biggest theme of the whole audit (F-SCH-01, F-RT-01, F-PERF-01/09, F-PRIV-03).
- **Your auth model has a wide-open admin backdoor.** The signup trigger still trusts `raw_user_meta_data->>'role'` and accepts `'admin'`. A `curl` against `/auth/v1/signup` with `"role":"admin"` makes anyone an admin with a real `user_role:admin` JWT (F-RLS-01). On top of that, a trade can self-approve their own licence (F-RLS-02) and any logged-in account can SELECT the entire `trade_profiles`/`builder_profiles` table including every phone number (F-RLS-03).
- **There is no trust-&-safety layer at all — none.** No reports table, no suspensions, no moderation audit log, no rate limits, no review-completion guard. Anyone can review-bomb anyone for a job they were never on, and you cannot ban the person who does it. You are putting tradies on strangers' residential properties with no way to receive, action, or audit a safety complaint (F-TS-01/02/08/10).
- **You are flying blind and your privacy policy is writing cheques the code can't cash.** No Sentry, no logging, no metrics, no runbooks, no tested restore. Meanwhile `privacy_policy.md` advertises a delete-account button, data export, and a retention schedule that do not exist — promising APP rights you can't fulfil is itself the exposure (F-OPS-01/02/03, F-PRIV-09/11/12). Also: data residency (Sydney vs Singapore/US) is unknown and that's an APP 8 problem until you confirm it.
- **The good news, so you don't despair:** the schema spine is above-average for a solo build, the fixes are mostly small idempotent migrations + RLS tightening, no service-role key leaked into the app, and every specialist shipped paste-ready SQL/TS. Pause the social-auth/portfolio branch — you're polishing the lobby while the building has no locks, no plumbing, and no fire exits.

## TL;DR for Ken's boss (layman's version)

- The app's screens for licence verification, in-app chat, and job search are wired to database fields that were never built — **if we ship as-is, those features fail for every real user on day one and look like sample/demo data.**
- Anyone signing up can secretly make themselves an administrator, and any logged-in user can download every other user's phone number and town — **if we ship as-is, a single malicious signup gets the keys to the kingdom and our users' contact details get scraped and spammed.**
- There is no way to report a scammer or abuser, no way to ban one, and no record of any moderation action — **if we ship as-is, the first scam or harassment incident has nowhere to go and we have no defensible response, with workers being sent to strangers' homes.**
- We cannot see crashes, errors, or outages, and have no emergency playbooks — **if we ship as-is, problems are invisible until users complain and a data breach blows the legally-mandated 30-day notification deadline.**
- Our public privacy policy promises Australians a delete-my-account button, a data download, and scheduled data deletion that do not exist in the software — **if we ship as-is, we are publicly committing to legal obligations we cannot technically perform, which is a regulatory and misleading-conduct risk.**

## Top 10 P0 findings

The dominant cross-cutting theme is **schema↔Dart-model drift**: the app reads/writes ~20 columns across verification, messaging, job search, applications and conversations that no migration creates. Five separate specialists (schema, perf, realtime, storage, edge) independently flagged it. It is treated below as the #1 priority cluster because it is *runtime breakage today*, blocks the index/perf work, and a single reconciliation migration plus a CI schema-diff check resolves the whole class.

| # | Title | Source | Rationale | Fix direction | Effort |
|---|---|---|---|---|---|
| 1 | **Schema↔model drift cluster: ~20 missing columns break verification, messaging, search** | schema (F-SCH-01/02), realtime (F-RT-01), perf (F-PERF-01/09), storage (F-PRIV-03) | The Dart data layer reads/writes `doc_type, file_path, expiry_date, deleted_at` (verification), `conversations.status/unread/last_read/last_message_*` + `messages.deleted_at` (messaging), `jobs.search_vector` (search), `applications.status_changed_at`. None exist in any migration. Every one of these code paths throws PostgREST `42703`/`PGRST204` or silently drops writes the first time a real user hits it. Messaging additionally falls back to mock data so failure is *invisible*. This is not "at scale" — it is broken at user #1, and it blocks the entire performance index pass (indexes on non-existent columns are no-ops). | One reconciliation migration set making the schema match the Dart contract (confirm Dart is canonical — Open Q); then a CI schema-diff/codegen check so it never silently drifts again. | M–L |
| 2 | **Signup trigger trusts client-supplied `role`, allowing self-promotion to `admin`** | rls-auth (F-RLS-01) | `handle_new_user` does `IF v_role IN ('builder','trade','admin')` on attacker-controlled `raw_user_meta_data`. Any `curl` to `/auth/v1/signup` with `"role":"admin"` yields a JWT carrying `user_role:admin`, which satisfies the `legal_acceptances` admin-read policy and every future admin policy. Full privilege escalation from an anonymous signup, in a system holding 25k Australians' PII, with one engineer and no SIEM. Root cause that makes every admin-gating fix moot until closed. | Strip `'admin'` from the trigger's accepted roles; add a `forbid_self_admin` BEFORE-INSERT trigger on `user_roles`; remove admin from client self-select. | S |
| 3 | **Trade can self-approve their own verification documents / set `is_verified=true`** | rls-auth (F-RLS-02), trust-safety (F-TS-05) | `verification_documents_update_own` and `trade_profiles_update_own` have no column pinning, so the owner can `UPDATE … SET status='approved'` / `is_verified=true`. No admin approval path exists anywhere (zero Edge Functions). The verification badge — the trust spine of a trades marketplace putting unlicensed workers on construction sites — is cosmetic. Safety + liability exposure. | RLS + BEFORE-UPDATE trigger locking `status`/`is_verified` to admin JWT only; durable fix is the `admin-approve-verification` Edge Function with audit log. | M |
| 4 | **Every authenticated user can read every builder/trade profile incl. `contact_phone`** | rls-auth (F-RLS-03), storage (F-PRIV-02) | `*_profiles_select_authenticated USING (auth.role()='authenticated')` exposes a harvestable directory of ~25k Australians' phone numbers + locations to anyone who signs up; PostgREST gives free pagination. APP 6/APP 11 exposure under Privacy Act 1988. Also leaks raw private-doc storage paths into a world-readable column. | Replace blanket policy with relationship-scoped SELECT (counterparty via application/conversation) + admin policy; stop persisting raw private paths, serve via short-TTL signed URLs. | M |
| 5 | **No admin authorization model / no Edge Functions for any privileged op** | edge (F-EDGE-01), rls-auth (F-RLS-04) | `supabase/functions/` does not exist. The only admin policy in 17 migrations is `legal_acceptances` read. Verification approval, suspension, moderation, report resolution have no enforcement point — the separate admin web app either doesn't work or wields a service-role key directly (catastrophic). Structural root cause behind #3, trust-safety, and privacy gaps. | Build `_shared/` + admin trio Edge Functions (skeletons provided in 05); adopt one `is_admin()` SQL predicate; route audited writes through Edge Functions. | L |
| 6 | **No trust-&-safety infrastructure: no reports, no suspensions, no moderation audit log** | trust-safety (F-TS-01/02/10), schema (F-SCH-09/10) | Zero intake path for scams/abuse, zero enforcement lever (only option is destructive auth-user delete), zero immutable record of admin actions. For an AU marketplace sending workers to private homes this is present-tense safety/legal/duty-of-care exposure. Audit log must land *before* enforcement goes live. | Ship `reports` + `user_suspensions` + `moderation_audit_log` migrations (paste-ready SQL in 07) with the proven `legal_acceptances` admin-policy pattern. | M–L |
| 7 | **Anyone can review anyone for a job they were never part of (no completion guard)** | trust-safety (F-TS-08), schema (F-SCH-11), rls-auth (F-RLS-07) | `reviews` insert policy is only `auth.uid()=reviewer_id`; no check the reviewer was a party, the reviewee the counterparty, or the job completed. Reviews drive who gets hired into people's homes — review-bombing, retaliation, sock-puppet inflation are all exploitable, and a malicious review is unremovable (no UPDATE/DELETE policy). | Replace raw insert with `submit_review` SECURITY DEFINER RPC asserting party + terminal-state; revoke direct INSERT; add admin hide. | M |
| 8 | **No push notifications — out-of-app message delivery is impossible** | realtime (F-RT-11), edge (F-EDGE-02) | No FCM/push package, no device-token model, no `send-push` function. Realtime is in-app only. A builder messaging "can you start Monday 7am?" reaches a tradie on-site *never* unless the app is foregrounded. Breaks the marketplace's core coordination loop at any scale. | Add `firebase_messaging` + `device_tokens` table + `send-push` Edge Function triggered on message insert. | L |
| 9 | **APP 8 data residency unknown + APP 13 delete-account promised but absent** | storage (F-PRIV-05/12), edge (F-EDGE-05) | Region (Sydney vs Singapore/US) not determinable from repo and the policy itself carries `[PLACEHOLDER]`. Privacy policy advertises a dated 30-day delete-account flow + legal-hold logic that has zero code; a naive cascade would also destroy records legally required to be retained. Promising un-fulfillable APP rights is the exposure independent of scale. | Confirm region in dashboard now (cheap pre-launch, XL if migration needed); build `delete-my-account` anonymisation Edge Function; add `deleted_at`/`anonymised_at`. | S→XL |
| 10 | **Observability blind + no on-call/breach runbooks + untested restore** | observability (F-OPS-01/02/03) | No Sentry/logging/metrics/alerting; a production incident is invisible until a user complains. No NDB runbook despite a hard 30-day statutory clock. Supabase PITR exists but an untested restore is not a backup; RTO/RPO undefined. Lowest-maturity domain in the audit. | Add `sentry_flutter` + zone guard; create `docs/runbooks/` (templates provided in 08); perform one restore drill. | S–M |

## P0 + P1 sprint plan

Two-week sprints, sequenced by dependency (schema reconciliation unblocks perf; admin-claim trust unblocks all admin policies; audit log precedes enforcement).

### Sprint 1 — "Schema-drift repair + auth lockdown" (the can't-ship-without)
- **Findings:** F-SCH-01, F-SCH-02, F-RT-01, F-RT-02, F-PERF-01, F-PERF-09, F-PRIV-03, F-PRIV-01 (storage UPDATE policy); F-RLS-01, F-RLS-02, F-RLS-03, F-PRIV-02.
- **Effort:** ~12–15 person-days.
- **Definition of done:** verification upload, messaging inbox (no mock fallback), and job search execute against real columns end-to-end; a CI schema-diff check is green; `'admin'` is impossible to self-assign and proven via a hostile-signup test; no blanket `authenticated` SELECT on profile PII; private docs served only via short-TTL signed URLs; storage re-upload UPDATE policy exists.

### Sprint 2 — "Trust & Safety MVP + admin authz" (don't-launch-without)
- **Findings:** F-SCH-09, F-SCH-10, F-TS-01, F-TS-02, F-TS-08, F-TS-10, F-RLS-04, F-RLS-07, F-EDGE-01 (admin trio + `_shared/`), F-RLS-05, F-RLS-06, F-RLS-13.
- **Effort:** ~13–16 person-days.
- **Definition of done:** `reports`/`user_suspensions`/`moderation_audit_log` tables live with admin RLS; `moderation_audit_log` lands before any enforcement path; review insert goes through `submit_review` RPC with completion guard; admin Edge Function trio deployed with audit logging; all UPDATE policies have `WITH CHECK` + column-immutability triggers; conversation/application integrity guards in place.

### Sprint 3 — "Privacy Act baseline + observability baseline"
- **Findings:** F-PRIV-05 (region confirm), F-PRIV-12, F-EDGE-05 (delete-my-account), F-PRIV-11/F-EDGE-04 (export), F-PRIV-09 (retention model — `deleted_at`/`expires_at` columns + cron), F-OPS-01, F-OPS-02, F-OPS-03, F-PRIV-10/F-OPS-11 (secrets), F-PRIV-14 (NDB runbook).
- **Effort:** ~14–18 person-days.
- **Definition of done:** Supabase region confirmed and policy `[PLACEHOLDER]`s resolved + `versions.json` bumped; `delete-my-account`/`export-my-data` Edge Functions live with `deleted_at`/`anonymised_at` columns; Sentry capturing crashes with a release tag; `docs/runbooks/` exists with NDB + auth-down + restore + breach playbooks; one restore drill completed and RTO recorded; secrets moved off repo tree + rotated.

### Sprint 4 — "Index pass + realtime hygiene + delivery"
- **Findings:** F-PERF-02 (keyset pagination), F-PERF-03/04/05, F-PERF-07, F-RT-03/04/05/07/08, F-RT-11/F-EDGE-02 (push), F-SCH-04/06/07, F-PRIV-04/06/08 (image pipeline), F-TS-03/F-EDGE-07 (rate limiting), F-TS-06.
- **Effort:** ~16–20 person-days.
- **Definition of done:** keyset pagination + composite/partial indexes on every hot list path (EXPLAIN shows no Seq Scan on jobs/applications/messages); realtime streams server-filtered with bounded subscriptions + backoff + poll fallback; push notifications delivering; rate-limit primitive enforced on write RPCs; one centralised image pipeline (compress + EXIF strip + magic-byte + size cap); notification/jobs-trade enums + FKs.

> Sprints 1–2 are launch-blocking. 3 is regulatory-blocking for AU. 4 is scale-blocking (must land before meaningful load, not before first users).

## Phase alignment

| Phase | Roadmap intent | Findings mapped |
|---|---|---|
| **Phase 0 (now — pre-anything)** | Stop the bleeding | Schema-drift cluster (#1), F-RLS-01/02/03, F-PRIV-01/02/03/05, F-EDGE-01, F-TS-01/02/08/10, F-OPS-01/02/03, F-RT-01/02 |
| **Phase 1 (pre-load)** | Make it correct & defensible | F-RLS-04/05/06/07/13, F-SCH-03/04/06/07/09/10, F-PERF-02/03/04/05/07/10, F-RT-03/04/05/07/08/11, F-PRIV-04/06/08/09/10/11, F-EDGE-04/05/07/08/09, F-TS-03/04/06/09, F-OPS-04/05/06 |
| **Phase 2 (tech debt / hardening)** | Reduce risk at scale | F-SCH-05/08/11/12/13, F-PERF-06/08/12, F-RT-09, F-PRIV-12 (XL build)/14, F-EDGE-02/06, F-TS-05/07, F-OPS-07/08/09/11/12 |
| **Phase 3 (polish)** | Operational maturity | F-SCH-15, F-PERF-11, F-RLS-11/12, F-RT-10, F-PRIV-15, F-EDGE-03, F-TS-11, F-OPS-10 |

**Work Ken is doing now that should pause:** the current branch (`feat/auth-social-portfolio-strip`, recent commits "social auth buttons", "FTUE carousel", "portfolio strip") is **Phase 3/feature-polish work that must pause until the Phase 0 P0 cluster clears.** Concretely: the portfolio-strip feature ships images to a world-readable bucket with no EXIF strip and no moderation (F-PRIV-06/08); social-auth expands the signup surface that currently has the admin self-promotion hole (F-RLS-01) and the broad PII-read policy (F-RLS-03); FTUE geo-personalisation has no feature flag/kill-switch (F-OPS-08). Polishing onboarding while verification, messaging and search are broken at runtime and the admin door is open is negative-value work. Land Sprint 1 + 2 first.

## Risk-adjusted opinion

**If Ken shipped today untouched:**

- **At ~1k users:** Verification, messaging and job search are visibly broken from the first real user — the inbox shows demo data ("Pinnacle Construct"), licence upload errors out, search 500s (F-SCH-01, F-RT-01, F-PERF-01). Within days a curious or hostile user `curl`s a `"role":"admin"` signup and now has admin JWT over the whole consent trail and any admin-gated data (F-RLS-01). First scam DM or harassing user arrives and there is literally nowhere to report it and no way to ban them (F-TS-01/02). **Failure mode: the product doesn't function and the first bad actor is unstoppable.**
- **At ~10k users:** A competitor or scraper paginates `trade_profiles`/`builder_profiles` and walks off with ~10k Australians' phone numbers and suburbs — an APP 6/11 incident with no detection (no Sentry, no logging) until it surfaces on social media or in a complaint (F-RLS-03, F-OPS-01). A privacy-aware user requests deletion citing the published policy; there is no delete flow, and the honest answer exposes the policy-vs-reality gap (F-PRIV-12). Unbounded queries (every list fetches the entire table, no LIMIT anywhere) push Supabase Pro CPU toward saturation on the job feed (F-PERF-02/03). **Failure mode: a reportable privacy breach you can't see, plus a regulatory-promise gap, plus the first performance cliff.**
- **At ~25k users:** The conversations realtime stream broadcasts every user's conversation changes to every connected client (F-PERF-07) and per-thread channels leak without bound (F-RT-05) — Realtime quota burn + battery drain on rural 3G while the inbox still doesn't reliably show new messages. Review-bombing and fake-licence fraud are systemic with no moderation tooling and no audit trail; an enforcement action (or a wrongful one) is legally indefensible (F-TS-08/10). A bad migration or stray `DELETE` with no tested restore and undefined RTO/RPO is a business-ending event (F-OPS-03). Region-unknown means you still can't truthfully state where 25k Australians' licence images live (F-PRIV-05). **Failure mode: simultaneous trust collapse, cost blowout, and an unrecoverable-data / unprovable-compliance posture with one engineer on call.**

## Open questions

**Canonical source of truth (schema vs Dart) — blocks Sprint 1:**
- Is the Dart model the intended schema (rich verification: issuer/number/expiry/review_notes) or is the thin migration truth? (schema Q1, perf Q1, storage Q5)
- Was a `messaging_state_columns` / `profiles_public` migration written and lost, or did the data layer get ahead of the schema? (realtime Q1)
- Is there production data in `zethpanvkfyijislxesn` yet (clean apply vs data-clean required for FK/enum casts)? (schema Q2)

**Privacy Act / data residency — blocks Sprint 3:**
- **What region is project `zethpanvkfyijislxesn`?** Confirm `ap-southeast-2` (Sydney) in dashboard — raised independently by storage, realtime, and observability. (storage Q1, realtime Q5, ops Q3)
- Has the AU privacy-lawyer review (7-year retention, APP 8 carve-out) been done? (storage Q2)
- Account deletion: anonymise + preserve consent/moderation trail (recommended), or hard-cascade? What retention window for the anonymised skeleton? (schema Q3, edge Q4)

**Admin model & authz:**
- How are admins provisioned — manual SQL by Ken, or the admin web app via service-role? (rls Q1, edge Q1, trust-safety Q5)
- Does the admin web app exist today, and how does it currently approve/suspend — dashboard SQL or a service-role key in the browser bundle? (edge Q1, rls Q7)
- Is the `custom_access_token` hook actually selected in the Supabase dashboard? If not, every admin predicate silently fails closed. (rls Q8)

**Domain rules needing a product decision:**
- Exact `application_status` transition matrix per role. (rls Q3)
- Which `job_status` means "work completed" for the review guard — `closed`, or a `completed` not in the enum? (rls Q4, trust-safety Q3)
- Who may initiate a conversation — builder-only post-application, or either side? (rls Q13)
- Should a trade see a builder's `contact_phone` before applying to an open job? (rls Q2)
- Counter maintenance strategy for `jobs.application_count`/`view_count` — trigger, derived, or rollup? (schema Q, perf Q2)
- Licence number: typed-in (enables duplicate detection) or photo-only? (trust-safety Q2)
- Suspension semantics: hard session-kill (needs Edge Function) vs soft RLS write-block + JWT expiry? (trust-safety Q1)
- Portfolio images: auth-gated private + signed URLs, or world-public marketing? (storage Q3)

**Infra / vendor choices:**
- Push provider: FCM vs OneSignal? (realtime Q2, edge Q5)
- Sentry vs existing Crashlytics org? PostHog vs other analytics? Paging channel (Discord/Slack/SMS)? Acceptable RTO/RPO? Store accounts + signing-key holder? (ops Q1/4/5/6/7)
- Scheduling: Supabase config.toml cron vs `pg_cron`+`pg_net`? (edge Q7)
- Moderation keyword lexicon — needs a real AU-trades scam/abuse list. (edge Q6, trust-safety)

**Documentation drift to surface (raised by observability F-OPS-09, ops Q2):** Both `CLAUDE.md` and `00_SCOPE.md` line 41 assert a `.github/workflows/cd.yml` CD workflow exists. **It does not** — only `ci.yml` is present, and `ci.yml` is itself weaker than the local `scripts/validate.sh` (no build, no format check, tests scoped to `test/features/`). This means the scope file's own ground-truth section contains an unverified claim, and CLAUDE.md cannot be trusted as ops ground truth until corrected. Action: fix both files to state CD does not exist.

## What I'd ship first vs. defer

**Ship first (next 2 weeks — Sprint 1):**
- Schema reconciliation migration set (verification + messaging + search + applications columns) and a CI schema-diff/codegen guard.
- Kill admin self-promotion (F-RLS-01) + verification self-approve lockdown (F-RLS-02).
- Relationship-scoped profile-PII RLS (F-RLS-03) + signed-URL serving for private docs (F-PRIV-02) + storage UPDATE policy (F-PRIV-01).
- Rebuild `MessageThreadPage` off mock data so messaging is actually wired (F-RT-02).

**Ship next (weeks 3–6 — Sprints 2–3):**
- `reports` / `user_suspensions` / `moderation_audit_log` + review-completion RPC + admin Edge Function trio (the launch-blocking trust layer).
- `WITH CHECK` + immutability triggers on all UPDATE policies; conversation/application integrity guards.
- Confirm Supabase region; build `delete-my-account` + `export-my-data`; add Sentry + the four core runbooks; perform one restore drill; move/rotate secrets.

**Defer to Phase 2+:**
- Licence-fraud detection (SHA-256/duplicate-licence), licence-expiry cron, FCM push polish, moderation keyword scan tuning.
- Full index/keyset pagination pass and realtime backoff/poll-fallback — *must* land before meaningful load, but after correctness and safety; not before first users.
- Feature-flag table, status page, structured-logging schema, Fastlane release pipeline, CI hardening, denormalised-counter triggers, `legal_acceptances` immutability trigger, conversation NULL-job_id unique fix.
- Presence/typing (correctly deferred — document the decision and cost ceiling).

## Layman's analogy

Think of Jobdun's backend right now like a newly built apartment block with an impressively solid concrete frame and good floor plans — but the front door lock is a sticker that says "locked," the verification, intercom, and directory wiring runs to junction boxes that were never installed (so they spark out the moment anyone flips a switch), there's no building manager, no incident log, no fire-evacuation plan, and a tested fire-suppression system that's never actually been tested. The structure is genuinely sound and worth finishing — but you cannot let 25,000 tenants move in until the locks are real, the wiring reaches the boxes, someone is watching the building, and there's a plan for when something goes wrong. The owner is currently busy choosing lobby paint colours; that should stop until the locks and wiring are done.
