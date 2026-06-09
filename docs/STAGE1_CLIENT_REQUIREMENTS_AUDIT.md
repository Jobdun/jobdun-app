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
| 8 | Push notifications for new jobs | ✅ | FCM rail end-to-end: `device_tokens` + `push-send` edge fn + new-job fan-out + per-user prefs + message/application-status producers. *(2026-06-09)* |
| 9 | Search trades by location / rating / availability | ✅ | `search_trades` RPC (bounding-box + haversine + rating + availability); `lib/features/discovery/` module; home builder mini-list + `/discovery` page; trade `OPEN FOR WORK` toggle. *(2026-06-04)* |
| 10 | GPS / map view for nearby crews | ✅ | `/discovery/map` plots real trade pins from `search_trades`; `/jobs/map` plots jobs. *(2026-06-09)* |
| 11 | In-app messaging / chat | ✅ | Realtime Supabase `.stream()` threads + conversations. |
| 12 | Photo / file uploads | ✅ | Pick/crop/compress pipeline, 5 storage buckets, zoom viewer. |
| 13 | Availability calendar | ✅ | Filter (2026-06-04) **+ weekly `table_calendar`**: trade blocks dates (`unavailable_dates`) at `/settings/availability`. *(2026-06-10, code; migration pending push)* |
| 14 | Accept / decline job requests | ✅ | Application flow: shortlist/hire/reject + trade withdraw/decline. |
| 15 | Scheduling calendar | ✅ | `bookings` table + `/schedule` (`table_calendar`); builder schedules a hired trade from the applicant screen; both see it. *(2026-06-10, code; migration pending push)* |
| 16 | Timesheets / check in–out | ✅ | `timesheets` table; trade clocks on/off per job with best-effort GPS; both parties view entries. *(2026-06-10, code; migration pending push)* |
| 17 | Trade earnings dashboard | ❌ | `fl_chart` declared but **unused**; no earnings/payments data. |
| 18 | Quote request system | ✅ | Trade quote-on-apply **+ standalone builder-initiated requests** (`quote_requests`): builder asks from the applicant screen, trade responds/declines in a `/quotes` inbox. *(2026-06-10, code; migration pending push. accept→invoice rides with payments)* |
| 19 | Loyalty rewards / discounts | ❌ | Nothing. |
| 20 | Referral system | ❌ | Nothing. |
| 21 | Admin dashboard (users / jobs / payments) | 🟡 | Verifications + **user AND job moderation** wired in admin-web (`admin_set_user_status`/`admin_set_job_status`); **broadcast console**; **payments-admin still absent** (Rail C). *(job-mod 2026-06-10)* |
| 22 | Licence / insurance expiry reminders | ✅ | pg_cron schedules the expiry sweep daily + a 30-day advance warning (`notify_expiring_verifications`) — live on the DB. *(2026-06-09)* |
| 23 | AI auto-match / smart recommendations | ❌ | Marked *future* by client; no recommendation code. |

**Tally:** ✅ 18 done · 🟡 1 partial · ❌ 4 not started. *(Updated 2026-06-10: the non-payment build — #13 calendar, #15 scheduling, #16 timesheets, #18 standalone quotes all ✅; #21 job-moderation wired. **Everything still open is payments-gated (#17 earnings, #19 loyalty, #20 referrals, #21 payments-admin) or client-deferred (#23 AI).** 06-09: #8 ✅ push rail; 06-04/09: #9/#10/#22/#13-filter.)*

> **2026-06-10 — "finish all the needed, payments last" build** (branch `feat/stage1-finish-non-payment`, off `6a41283`). Built end-to-end (code) + TDD-tested (full suite 460 pass / 0 fail; arch 7/7; analyze clean):
> - **#21 job moderation** → wired (`admin_set_job_status` in admin-web + CLOSE/CANCEL/REOPEN card).
> - **#13 availability calendar** → `unavailable_dates` + `/settings/availability` `table_calendar`.
> - **#18 standalone quote requests** → `lib/features/quotes/` (`quote_requests`), builder asks on applicant screen, trade `/quotes` inbox responds/declines.
> - **#15 scheduling** → `lib/features/scheduling/` (`bookings`), `/schedule` calendar, builder schedules a hired trade.
> - **#16 timesheets** → `lib/features/timesheets/` (`timesheets`), trade clocks on/off per job with GPS, both view.
> ⚠️ **Not yet live:** 4 migrations (`20260610000001–04`) need `supabase db push`, and the branch is unmerged. Admin-web needs a `deploy-admin.sh` redeploy to surface the wired job-moderation card.

> **2026-06-09 (post-push-merge) — what changed this merge.** The full push-notifications program landed on `main`/`develop` (commit `6a41283`):
> - **#8 Push → ✅ end-to-end.** `firebase_messaging` ^16.3.0 + `lib/core/services/push_notifications.dart` (token registration), a `device_tokens` table + per-user `notification_preferences` (`…06`), the `push-send` edge function, and a **central push trigger** (`…07`) that fans new-job notifications out to matching trades (`…04`/`…05`). Plus **producers** for new messages (`…09`) and application-status changes (`…10`), and a mobile **notification-preferences screen** (`lib/features/profile/.../notification_settings_page.dart`).
> - **#21 user moderation → wired in admin-web.** `admin_set_user_status` is now called from `admin_user_detail_repository_impl.dart`; job-moderation RPC (`admin_set_job_status`) exists but the admin jobs screen is still read-only.
> - **Broadcast console (bonus, beyond the 23).** `lib/admin/features/admin_broadcast/*` + `…08_admin_broadcast.sql` — admin push + in-app announcements to targeted audiences.
> - **Rails laid:** Rail B (push) ✅ and Rail A (scheduled runner) ✅. **Only Rail C (payments) remains un-laid.**

> **2026-06-09 refresh:** **Live on DB this session:** builder reviews from tradies (S14) + the #22 cron/advance-warning. Also shipped (mobile, committed): the profile P2–P5 credibility program — `/settings` route, incomplete-profile CTA, 96dp verified-ring avatar, rating block + review count, service-area/crew lines, and a **public builder profile** (`/builders/:id`) a tradie can vet before applying.

---

## ⛔ NOT YET IMPLEMENTED — the gap list

This is the part you asked for: everything that still needs building before Stage 1 is complete.

### A. Whole features with **zero code** (greenfield)

*Struck-through items have shipped since 2026-06-01 (date noted on each); the rest remain greenfield.*

1. ~~**Push notifications for new jobs (#8)**~~ — ✅ **DONE (2026-06-09).** Shipped end-to-end: `firebase_messaging` + `lib/core/services/push_notifications.dart` (token registration), `device_tokens` + `notification_preferences` tables (`…06`), the `push-send` edge function, and a central trigger (`…07`) that fans new-job/message/application-status notifications out to matching trades (`…04`/`…05`/`…09`/`…10`). See **"What's genuinely solid."**

2. ~~**Search trades by location / rating / availability (#9)**~~ — ✅ **DONE (2026-06-04).** `search_trades` RPC (bounding-box + haversine + rating + availability) backs the `lib/features/discovery/` module, the home builder mini-list, and the `/discovery` page; trades toggle `OPEN FOR WORK`. The home sample-data list was replaced with the real query.

3. ~~**Availability calendar (#13)**~~ — ✅ **DONE (2026-06-10).** Weekly `table_calendar` of blocked dates (`trade_profiles.unavailable_dates`) at `/settings/availability`, on top of the 06-04 filter.

4. ~~**Scheduling calendar (#15)**~~ — ✅ **DONE (2026-06-10).** `bookings` table + `/schedule` calendar; builder schedules a hired trade from the applicant screen.

5. ~~**Timesheets / check in–out (#16)**~~ — ✅ **DONE (2026-06-10).** `timesheets` table; trade clocks on/off per job with best-effort GPS.

6. **Trade earnings dashboard (#17)** — `fl_chart` is in `pubspec.yaml` but has **0 usages** in `lib/`. There is **no payment/earnings data anywhere** to chart (see cross-cutting gap below). **Blocked on the payments rail.**

7. ~~**Quote request system (#18)**~~ — ✅ **DONE (2026-06-10).** Standalone builder-initiated requests (`quote_requests`) + trade `/quotes` inbox, alongside the existing quote-on-apply. (accept→invoice rides with payments.)

8. **Loyalty rewards / discounts (#19)** — nothing.

9. **Referral system (#20)** — nothing (no referral codes, no `referrals` table).

10. **AI auto-match / smart recommendations (#23)** — client-flagged *future*; no recommendation/matching code.

### B. Partials that need finishing

11. ~~**GPS / map view for *nearby crews* (#10)**~~ — ✅ **DONE (2026-06-09).** `/discovery/map` plots real trade pins from `search_trades`; `/jobs/map` plots jobs. Crew markers are sourced from live `trade_profiles` geo data.

12. **Admin moderation + "manage payments" (#21)** — the admin web app (`lib/admin/`) covers Dashboard, Users, User detail, Jobs, Verifications, an Audit log, and (new) a **Broadcast console**. Remaining:
    - **User moderation = ✅ wired** (suspend/ban/reactivate via `admin_set_user_status` + moderation card). **Verifications** also actionable.
    - **Job moderation = ✅ wired (2026-06-10).** `admin_set_job_status` now called from `admin_jobs_repository_impl.dart`; the job-detail screen has a CLOSE / CANCEL / REOPEN card (`_JobModerationCard`).
    - **Payments management = ❌** because there is **no payment system** in the product at all (blocked on Rail C). **This is the only remaining piece of #21.**
    - **To build:** gated on a payments rail — a payments admin surface.

13. ~~**Licence / insurance expiry reminders (#22)**~~ — ✅ **DONE (2026-06-09).** pg_cron schedules `expire_stale_verifications()` daily plus a 30-day advance warning (`notify_expiring_verifications`); both live on the DB. (Rail A laid.)

### C. Caveat on an otherwise-✅ item

14. **Insurance verification (part of #5)** — ABN and state trade-licence are **auto-verified** against real registers via mature edge functions (`verify-abn`, `verify-licence`: rate-limits, circuit breakers, audit trail, per-state adapters). However `docTypeToVerificationKind` only maps `trade_licence → licence` and `abn_certificate → abn`. **Insurance (public liability), white card, and photo ID are manual document uploads reviewed by an admin — not automatically verified.** That's industry-normal (no public insurer register API), but worth stating: an "insurance verified" badge today means *an admin eyeballed an uploaded certificate*, not an automated check.

---

## Cross-cutting infrastructure gaps

These underpin several of the missing features and should be sequenced first:

- **No payments rail. ← the only rail still missing.** No `payment`/`payout`/`invoice`/`transaction` tables, no Stripe/PayID integration. This blocks **#17 (earnings dashboard)** and the payments half of **#21 (admin)**. Quotes (#18) and loyalty/discounts (#19) also lean on it.
- ~~No push delivery rail~~ — ✅ **LAID (2026-06-09).** `firebase_messaging` + `device_tokens` + `push-send` edge fn + central fan-out trigger now power **#8** and supercharge the in-app notification centre (now fed by new jobs, messages, and application-status changes).
- ~~No scheduled-job runner~~ — ✅ **LAID (2026-06-09).** pg_cron runs the verification expiry sweep + a 30-day advance warning daily (**#22**); available for future digests/match jobs.

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
- **Push & notifications** — FCM device-token rail (`lib/core/services/push_notifications.dart`) + `push-send` edge fn + per-user notification preferences; the in-app centre is fed by new-job fan-out, new messages, and application-status changes.
- **Scheduled runner** — pg_cron runs the verification expiry sweep + a 30-day advance warning daily.
- **Admin web** — read dashboards for users/jobs + full verification review workflow + audit log + **user moderation** (suspend/ban/reactivate) + a **broadcast console** (admin push + in-app announcements, `lib/admin/features/admin_broadcast/`).

---

## Suggested build order for the *remaining* gaps

*All **non-payment** Stage-1 work is now ✅ (2026-06-10): #8/#9/#10/#13/#15/#16/#18 + #21 moderation + #22. Everything left is gated on the payments decision, plus deferred AI.*

1. **Rail C — Payments (decision-gated, the big unlock).** Pick the processor with the client (**Stripe Connect** recommended; Airwallex / PayID-PayTo as AU-local alternatives). Unblocks everything below — don't build until it's chosen.
2. **#17 earnings dashboard + #21 payments-admin** — once Rail C exists (finally uses the declared `fl_chart`).
3. **#19 loyalty + #20 referrals** — lean on payments / credits.
4. **#23 AI auto-match** — client-deferred; defer until match/booking data accrues.

> **Before any of this is live:** push the 4 pending migrations (`20260610000001–04`) and merge `feat/stage1-finish-non-payment`; redeploy admin-web for the job-moderation card.

---

*Generated by reading the repo on 2026-06-01. Every status is traceable to a cited file; re-run the audit after each gap is closed.*
