# Jobdun — Next Steps (post schema-reconciliation)

**Status date:** 2026-05-17
**Branch:** `develop` (active integration line; `main` is stale)
**Live Supabase:** project `zethpanvkfyijislxesn`, region **Oceania (Sydney)** — all 19 migrations through `20260516000002` applied.

This document is the running plan for what to do after the backend audit
(`docs/audit/`) and the schema-drift reconciliation. It supersedes ad-hoc
sequencing discussions. Source roadmap: `docs/audit/00_EXECUTIVE_SUMMARY.md`.

---

## 0. Where we are now

| Item | State |
|---|---|
| Schema-drift cluster (verification/messaging/search/profile columns) | **Fixed** — migrations applied to live |
| CI schema-diff guard (`scripts/schema-diff.sh` + `supabase/schema.sql`) | **In place** |
| F-RLS-01 admin self-promotion backdoor | **Closed on live** |
| Data residency (F-PRIV-05, Sprint 3 blocker) | **Resolved** — confirmed Sydney `ap-southeast-2` |
| Auth → profile data-layer contract | **Verified clean** vs live schema (Step A) |
| Auth → profile end-to-end on device | **Step B — in progress** (manual walkthrough) |
| Live data | Empty / owner-only |

**Current focus:** finish the auth → profile vertical slice end-to-end against
live Supabase. Step A (static contract verification) passed with no code
changes required. Step B is the on-device walkthrough:

1. Sign up (fresh email) → `handle_new_user` trigger creates `profiles` row
2. Pick role → `builder_profiles` / `trade_profiles` row, role lands in JWT
3. Fill + save profile (`phone`, `bio`, trade `rate`/`crew`/`radius`) → persists
4. `/home` completeness banner reflects saved data

> Any runtime bug found in Step B is fixed as a sub-task **before** moving on —
> debugging/TDD discipline, not patch-and-hope.

---

## 1. Finish Sprint 1 (launch-blocking — must clear before Sprint 2)

Sprint 1 = "Schema-drift repair + auth lockdown". Three of its DoD items are
done (above). The remaining launch-blockers, in dependency-light order:

| # | Finding | Work | Effort |
|---|---|---|---|
| 1 | **F-RLS-02** | Trade can self-approve own licence / set `is_verified=true`. Add RLS column-pin + BEFORE-UPDATE trigger so `status`/`is_verified` are admin-only. | S–M |
| 2 | **F-RLS-03 / F-PRIV-02** | Any authenticated user can read every `trade_profiles`/`builder_profiles` row incl. phone. Replace blanket `authenticated` SELECT with relationship-scoped policy + admin policy. | M |
| 3 | **F-PRIV-02** | Serve private verification docs via short-TTL signed URLs, not raw stored paths. | M |
| 4 | **F-PRIV-01** | Add storage re-upload UPDATE policy (currently missing). | S |
| 5 | **F-RT-02** | `MessageThreadPage` still reads mock data — wire to the now-real columns. | M |

**Sprint 1 Definition of Done:** all five closed + a hostile-signup test
proving `'admin'` is unassignable + verification/messaging/search execute
end-to-end against real columns + schema-diff CI green.

> **Launch gate:** do NOT invite any external/beta testers onto the live
> project until F-RLS-02 and F-RLS-03 are closed. Today's data is owner-only,
> so the exposure is theoretical — that stops being true the moment a tester
> account exists.

---

## 2. Sprint 2 — Trust & Safety MVP + admin authz (don't-launch-without)

Findings: F-SCH-09/10, F-TS-01/02/08/10, F-RLS-04/05/06/07/13, F-EDGE-01.
Effort ~13–16 person-days. **Do not start before Sprint 1 DoD.**

- `reports` / `user_suspensions` / `moderation_audit_log` tables with admin RLS
  (audit log must land *before* any enforcement path)
- `submit_review` SECURITY DEFINER RPC with party + completion guard; revoke
  direct `reviews` INSERT
- Admin Edge Function trio + `_shared/`; one `is_admin()` predicate
- `WITH CHECK` + column-immutability triggers on all UPDATE policies
- Conversation/application integrity guards

---

## 3. Sprint 3 — Privacy Act + observability baseline (regulatory-blocking for AU)

Findings: F-PRIV-09/11/12, F-EDGE-04/05, F-OPS-01/02/03, F-PRIV-10/14.
Effort ~14–18 person-days. Region already confirmed (one blocker pre-cleared).

- `delete-my-account` + `export-my-data` Edge Functions; `deleted_at` /
  `anonymised_at` columns; retention model + cron
- Resolve `privacy_policy.md` `[PLACEHOLDER]`s + bump `versions.json`
- Sentry capturing crashes with a release tag
- `docs/runbooks/` — NDB, auth-down, restore, breach playbooks
- One restore drill; record RTO/RPO
- Move secrets off the repo tree + rotate

---

## 4. Sprint 4 — Index pass + realtime hygiene + delivery (scale-blocking)

Findings: F-PERF-02/03/04/05/07, F-RT-03/04/05/07/08/11, F-EDGE-02,
F-SCH-04/06/07, F-PRIV-04/06/08, F-TS-03/06. Effort ~16–20 person-days.
Land before meaningful load — not before first users.

- Keyset pagination + composite/partial indexes on every hot list path
  (EXPLAIN: no Seq Scan on jobs/applications/messages)
- Server-filtered realtime with bounded subscriptions + backoff + poll fallback
- Push notifications (`device_tokens` + `send-push` Edge Function)
- Rate-limit primitive on write RPCs
- One centralised image pipeline (compress + EXIF strip + magic-byte + size cap)

---

## Sequencing rules (do not reorder)

1. Schema reconciliation unblocks the perf/index pass — **done**.
2. Admin-claim lockdown (F-RLS-01) unblocks every admin policy — **done**.
3. `moderation_audit_log` must precede any enforcement action (Sprint 2).
4. Sprints 1–2 are launch-blocking. 3 is AU-regulatory-blocking. 4 is
   scale-blocking.
5. **Paused until Sprint 1+2 clear:** FTUE/social-auth/portfolio polish
   (Phase-3 feature work; negative-value while trust layer is absent).
   FTUE work stays committed and live — paused, not reverted.

---

## Open product decisions still blocking later sprints

- Account deletion: anonymise + preserve consent/moderation trail (recommended)
  vs hard-cascade? Retention window for the anonymised skeleton?
- Exact `application_status` transition matrix per role.
- Which `job_status` = "work completed" for the review guard?
- Who may initiate a conversation — builder-only post-application, or either?
- Suspension semantics: hard session-kill vs soft RLS write-block + JWT expiry?
- Push provider (FCM vs OneSignal); Sentry vs existing Crashlytics; paging channel.
