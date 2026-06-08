# Stage 1 — Client Requirements Audit

**Date:** 2026-06-01
**Branch audited:** `feat/verified-builder-details-step6`
**Scope:** The 23 Stage 1 features in the client brief, audited against what is *actually in the repo right now* — Flutter app (`lib/`), admin web app (`lib/admin/`), Supabase migrations (`supabase/migrations/`), and edge functions (`supabase/functions/`).
**Method:** Source-of-truth read of feature folders, DB schema, RPCs, edge functions, and `pubspec.yaml`. Every claim below cites a file. "Declared but unused" means a package is in `pubspec.yaml` but has zero references in `lib/`.

---

## Status legend

| Symbol | Meaning |
|--------|---------|
| ✅ **Done** | Built end-to-end (data + domain + UI), wired to Supabase, usable today. |
| 🟡 **Partial** | Foundations exist but the feature is incomplete, sample-data-backed, or not wired/scheduled. |
| ❌ **Not started** | No feature code. May have an unused package or a stray data field, nothing more. |

---

## Scorecard — all 23 at a glance

| # | Requirement | Status | One-line verdict |
|---|-------------|:------:|------------------|
| 1 | User sign up / login (Builder, Trade, Admin) | ✅ | Email + phone OTP + Google/Apple, role split, separate admin login w/ role gate. |
| 2 | Builder company profiles | ✅ | `builder_profiles` table + edit UI + ABN backfill. |
| 3 | Trade / Crew profiles | ✅ | `trade_profiles`: crew size, trades, service radius, rate, portfolio. |
| 4 | Ratings & reviews | ✅ | `reviews` table, submit/list/average, review cards, rating on profile. |
| 5 | ID / licence / insurance verification badges | ✅* | ABN + state-licence auto-verified via edge fns; *insurance = manual upload only. |
| 6 | Job posting system | ✅ | `jobs` table, create/edit/delete, feed, detail, map. |
| 7 | Urgent job posting option | ✅ | `job_urgency` enum (`standard`/`urgent`) + badge. |
| 8 | Push notifications for new jobs | ❌ | No push SDK, no device-token table, no new-job trigger. In-app centre only. |
| 9 | Search trades by location / rating / availability | ✅ | `search_trades` RPC (bounding-box + haversine + rating + availability); `lib/features/discovery/` module; home builder mini-list + `/discovery` page; trade `OPEN FOR WORK` toggle. *(2026-06-04)* |
| 10 | GPS / map view for nearby crews | ✅ | `/discovery/map` plots real trade pins from `search_trades`; `/jobs/map` plots jobs. *(2026-06-09)* |
| 11 | In-app messaging / chat | ✅ | Realtime Supabase `.stream()` threads + conversations. |
| 12 | Photo / file uploads | ✅ | Pick/crop/compress pipeline, 5 storage buckets, zoom viewer. |
| 13 | Availability calendar | 🟡 | Availability **filter** shipped (`is_available`/`available_from` + search filter + profile toggle, 2026-06-04). Full weekly `table_calendar` view still deferred. |
| 14 | Accept / decline job requests | ✅ | Application flow: shortlist/hire/reject + trade withdraw/decline. |
| 15 | Scheduling calendar | ❌ | No scheduling feature; `table_calendar` unused. |
| 16 | Timesheets / check in–out | ❌ | No code, no table. |
| 17 | Trade earnings dashboard | ❌ | `fl_chart` declared but **unused**; no earnings/payments data. |
| 18 | Quote request system | 🟡 | Trades attach a `quote_amount` on apply; builder sees each quote on the Applicants screen. No standalone builder-initiated request entity. *(2026-06-09)* |
| 19 | Loyalty rewards / discounts | ❌ | Nothing. |
| 20 | Referral system | ❌ | Nothing. |
| 21 | Admin dashboard (users / jobs / payments) | 🟡 | Verifications actionable; user/job moderation RPCs added (`admin_set_user_status`/`admin_set_job_status`, audited) — admin-web wiring + push pending; **payments absent**. *(2026-06-09)* |
| 22 | Licence / insurance expiry reminders | ✅ | pg_cron schedules the expiry sweep daily + a 30-day advance warning (`notify_expiring_verifications`) — live on the DB. *(2026-06-09)* |
| 23 | AI auto-match / smart recommendations | ❌ | Marked *future* by client; no recommendation code. |

**Tally:** ✅ 13 done · 🟡 3 partial · ❌ 7 not started. *(Updated 2026-06-09: #10 ✅ crew map, #22 ✅ cron live, #18 → 🟡 quote-on-apply, #21 moderation DB added — admin-web wiring pending. Earlier 06-04: #9 done, #13 partial.)*

> **2026-06-09 refresh:** scorecard above reflects this date; some gap-list prose further down still describes the 06-01 state. **Live on DB this session:** builder reviews from tradies (S14) + the #22 cron/advance-warning. Also shipped (mobile, committed): the profile P2–P5 credibility program — `/settings` route, incomplete-profile CTA, 96dp verified-ring avatar, rating block + review count, service-area/crew lines, and a **public builder profile** (`/builders/:id`) a tradie can vet before applying. The #21a admin-moderation **DB half** is committed (RPCs + `user_status`); admin-web wiring + push remain.

---

## ⛔ NOT YET IMPLEMENTED — the gap list

This is the part you asked for: everything that still needs building before Stage 1 is complete.

### A. Whole features with **zero code** (greenfield)

1. **Push notifications for new jobs (#8)**
   - No push SDK in `pubspec.yaml` (no `firebase_messaging`, no OneSignal, no Expo).
   - No `device_tokens` / `push_tokens` table in any migration.
   - The `notifications` table *exists* and the in-app notification centre works (`lib/features/notifications/`), but rows are only ever inserted by **verification events** (approve/reject/revoke/expire migrations). **Nothing inserts a notification when a job is posted.**
   - **To build:** push SDK + token registration + token table → DB trigger/edge function on `jobs` insert that fans out to matching trades → push send.

2. **Search trades by location / rating / availability (#9)**
   - `JobFilter` (`lib/features/jobs/domain/entities/job_filter.dart`) filters **jobs** only, by `tradeType` / `status` / `searchQuery`. There is **no trade-directory search at all**.
   - The home screen's "tradies nearby" list renders `TradieCard`s from `_TradieData` **sample data** (`lib/features/home/presentation/pages/home_sample_data.dart`) — not a real query.
   - Foundations that *do* exist: `trade_profiles` carries `baseLatitude/baseLongitude`, `serviceRadiusKm`, and `averageRating`. **Missing:** an `availability` field entirely, plus a repository query + filter UI.
   - **To build:** trade-search repository (geo + rating + availability), filter UI, results list backed by real data.

3. **Availability calendar (#13)** — `table_calendar` is in `pubspec.yaml` but has **0 usages** in `lib/`. No availability field on `trade_profiles`, no calendar screen.

4. **Scheduling calendar (#15)** — no scheduling feature, no booking/schedule table; `table_calendar` unused.

5. **Timesheets / check in–out (#16)** — no code, no `timesheets` table, no geo/clock capture.

6. **Trade earnings dashboard (#17)** — `fl_chart` is in `pubspec.yaml` but has **0 usages** in `lib/`. There is **no payment/earnings data anywhere** to chart (see cross-cutting gap below).

7. **Quote request system (#18)** — "quote" only appears in copy/icon names; no quote entity, table, or request flow.

8. **Loyalty rewards / discounts (#19)** — nothing.

9. **Referral system (#20)** — nothing (no referral codes, no `referrals` table).

10. **AI auto-match / smart recommendations (#23)** — client-flagged *future*; no recommendation/matching code.

### B. Partials that need finishing

11. **GPS / map view for *nearby crews* (#10)** — `home_map_view.dart` is a real `flutter_map` map (key-less OSS tiles + `geolocator`), but its `MarkerLayer` plots **jobs** near the user (`_buildMarkers` iterates `jobs`, falling back to *synthesised sample jobs* when none are real). To satisfy "nearby **crews**," it needs crew/trade markers from real `trade_profiles` geo data.

12. **Admin "manage payments" (#21)** — the admin web app (`lib/admin/`) covers Dashboard stats, Users, User detail, Jobs, Verifications, and an Audit log. But:
    - **Users & Jobs are view-only** — no suspend/ban/edit/delete (admin repos have no `.update/.insert/.delete/.rpc` mutation calls). Only **Verifications** are actionable (`review_verification_document` + `revoke_verification` RPCs).
    - **Payments management does not exist** because there is **no payment system** in the product at all.
    - **To build:** user moderation actions (suspend/ban), job moderation, and — gated on a payments system existing — a payments admin surface.

13. **Licence / insurance expiry reminders (#22)** — `expire_stale_verifications()` exists (`supabase/migrations/20260531000004_…`), flips past-due licences to `expired` and notifies the holder. **But it is not scheduled** — the migration explicitly notes pg_cron is not installed and no scheduled edge function calls it, so nothing runs it. Also, it only fires *on/after* expiry; there is **no advance "expiring in 30 days" reminder**.
    - **To build:** wire a schedule (enable pg_cron *or* a scheduled edge function) + add advance-warning notifications ahead of `expires_at`.

### C. Caveat on an otherwise-✅ item

14. **Insurance verification (part of #5)** — ABN and state trade-licence are **auto-verified** against real registers via mature edge functions (`verify-abn`, `verify-licence`: rate-limits, circuit breakers, audit trail, per-state adapters). However `docTypeToVerificationKind` only maps `trade_licence → licence` and `abn_certificate → abn`. **Insurance (public liability), white card, and photo ID are manual document uploads reviewed by an admin — not automatically verified.** That's industry-normal (no public insurer register API), but worth stating: an "insurance verified" badge today means *an admin eyeballed an uploaded certificate*, not an automated check.

---

## Cross-cutting infrastructure gaps

These underpin several of the missing features and should be sequenced first:

- **No payments rail.** No `payment`/`payout`/`invoice`/`transaction` tables, no Stripe/PayID integration. This blocks **#17 (earnings dashboard)** and the payments half of **#21 (admin)**. Quotes (#18) and loyalty/discounts (#19) also lean on it.
- **No push delivery rail.** No push SDK, no device-token storage, no fan-out. Blocks **#8** and limits the usefulness of the existing in-app notification centre.
- **No scheduled-job runner.** pg_cron is not installed and there is no scheduled edge function. Blocks **#22** (expiry sweep/reminders) and any future digest/match notifications.

---

## What's genuinely solid (don't rebuild)

- **Auth** — email/password, phone OTP, Google/Apple SSO, role resolution, JWT `user_role` claim hook, non-self-assignable admin role, separate admin login gate.
- **Profiles** — builder + trade/crew, trade categories, portfolio, completeness scoring, soft-delete, places/geo columns.
- **Jobs** — full CRUD, urgency flag, certification requirements, application counts, real map feed.
- **Applications** — `pending → shortlisted → hired/rejected/withdrawn/declined_by_trade` lifecycle (covers accept/decline).
- **Messaging** — realtime threads via Supabase streams with optimistic send.
- **Reviews** — submit/list/average, per-job uniqueness constraint.
- **Verification** — the most mature subsystem: ABN + multi-state licence auto-verify edge functions, manual-upload fallback, admin review queue, revoke, badges. (See `docs/VERIFICATION_FLOW_AUDIT.md`.)
- **Uploads** — `ImageUploadService` pick/crop/compress + 5 storage buckets + zoom viewer.
- **Admin web** — read dashboards for users/jobs + full verification review workflow + audit log.

---

## Suggested build order for the gaps

1. **Trade search + availability (#9, #13, #10)** — highest product value; the data layer is half-there. Add `availability` to `trade_profiles`, build the geo/rating/availability query, replace the home sample list with it, and switch the map to crew markers.
2. **Push rail → new-job notifications (#8)** — pick the SDK, add token storage, trigger on `jobs` insert.
3. **Scheduled runner → expiry reminders (#22)** — enable pg_cron / scheduled edge fn; add advance-warning notices.
4. **Admin moderation (#21, users/jobs)** — suspend/ban/edit actions on the existing read-only screens.
5. **Payments rail → earnings dashboard (#17, payments admin)** — the big one; unblocks earnings, quotes, and loyalty.
6. **Quotes (#18), scheduling/timesheets (#15, #16), loyalty (#19), referrals (#20)** — greenfield; sequence per client priority.
7. **AI auto-match (#23)** — explicitly future; defer until match data accrues.

---

*Generated by reading the repo on 2026-06-01. Every status is traceable to a cited file; re-run the audit after each gap is closed.*
