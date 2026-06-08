# Stage 1 — Completion Plan & Alignment Audit

**Date:** 2026-06-01
**Branch:** `feat/admin-placeholder-scaffold`
**Companion to:** [`STAGE1_CLIENT_REQUIREMENTS_AUDIT.md`](./STAGE1_CLIENT_REQUIREMENTS_AUDIT.md) — that doc says *what's missing*; this doc says *how to finish it, in this repo, without breaking the architecture*.

This has two halves:
- **Part 1 — Alignment audit:** is the current mobile + backend foundation sound enough to build the remaining features on? (Short answer: yes — gaps are *additive*, not *corrective*.)
- **Parts 2–5 — Completion plan:** the 3 cross-cutting rails to lay first, then a step-by-step, repo-aligned build recipe for each gap, sequenced into milestones.

Re-verified against the repo on 2026-06-01: 11 mobile feature modules, 8 admin modules, 45 migrations, 2 edge functions (`verify-abn`, `verify-licence`). All requirement-audit claims still hold.

> **2026-06-09 progress.** Since this plan was written: **M1 shipped** (trade search #9 + crew map #10 via `lib/features/discovery/`). **Rail A laid** — pg_cron now schedules the expiry sweep + a 30-day advance warning, so **#22 is done (live)**. Builder reviews (S14) shipped + live; **public builder profile** (S13, `/builders/:id`) shipped, closing the surface-3 trust gap; applicant-detail enriched (S15). **#21a admin-moderation DB half** committed (`admin_set_user_status`/`admin_set_job_status` + `user_status`, audited) — admin-web wiring + push remain. **Rails B (push) and C (payments) are still un-laid** → #8, #17, and payments-admin remain blocked.

---

## Part 1 — Alignment Audit (foundation health)

> Purpose: confirm we're still building on the documented standards before adding 10 new features on top.

### 1.1 Mobile architecture — ✅ aligned

| Check | State | Evidence |
|-------|-------|----------|
| Feature-first Clean Architecture (data/domain/presentation per feature) | ✅ | All 11 modules under `lib/features/*` follow it |
| Domain purity (no Flutter/Supabase in `domain/`) | ✅ enforced | `scripts/check-architecture.sh` (7 checks) + CI |
| Use-case-over-repo (auth is the documented exception → `data/services/`) | ✅ | per `CLAUDE.md` |
| Riverpod 3 only — `Notifier`/`AsyncNotifier`, no Bloc/provider/GetIt | ✅ | state-mgmt rules in `CLAUDE.md` |
| File-size budget (≤400 target / 500 ceiling) | ✅ guarded | `scripts/validate.sh` allowlist |
| Design system (tokens, AppIcons, Gap/screenutil, JStaggered/JSkeleton/showJSheet) | ✅ | `design-system/jobdun/MASTER.md` |
| Typography → Google-aligned (body 16, Material 24dp icons) | ✅ **just shipped** | 2026-06-01 type-scale + icon conformance pass; every screen routes through theme roles |

**Verdict:** the app's skeleton is healthy and consistently applied. New features must follow the same per-feature layering (see the recipe in Part 4) and the design system — not invent new patterns.

### 1.2 Backend — ✅ aligned, with 3 known infra gaps

| Check | State | Evidence |
|-------|-------|----------|
| RLS on all tables, users read/write own data, admin role-gated | ✅ | 45 migrations; `20260528000001_admin_read_policies.sql` |
| `handle_new_user()` trigger seeds `profiles` on signup | ✅ | required-before-signup invariant |
| JWT `user_role` claim hook + non-self-assignable admin | ✅ | `custom_access_token_hook`, `forbid_self_admin` |
| Verification edge functions (rate-limit, circuit breaker, audit, per-state adapters) | ✅ mature | `verify-abn`, `verify-licence` |
| **Payments rail** (tables / processor) | ❌ missing | no `payment/payout/invoice/transaction` tables |
| **Push delivery rail** (SDK / device tokens / fan-out) | ❌ missing | no push SDK, no `device_tokens` table |
| **Scheduled-job runner** (pg_cron / scheduled edge fn) | ❌ missing | `expire_stale_verifications()` exists but nothing runs it |

**Verdict:** the data layer and auth/verification subsystems are production-grade. The three missing pieces are **rails** — shared infrastructure that several gap-features depend on. Lay them first (Part 2) so features land cleanly on top instead of each one half-inventing its own.

### 1.3 Foundation verdict

Nothing in the current setup needs *undoing* to finish Stage 1. Every remaining requirement is **net-new feature work** that plugs into the existing architecture. Proceed.

---

## Part 2 — The 3 cross-cutting rails (build these FIRST)

These unblock multiple features; sequencing them first avoids rework.

### Rail A — Scheduled-job runner *(unblocks #22; enables future digests/match jobs)*
- **Pick:** native **`pg_cron`** (free, in-database) over an external cron — least moving parts, no extra SDK. Supabase supports it as an extension.
- **Steps:**
  1. Migration: `create extension if not exists pg_cron;`
  2. Migration: `select cron.schedule('expire-verifications-daily','0 2 * * *', $$ select public.expire_stale_verifications(); $$);`
  3. New SQL function `notify_expiring_verifications(days int)` → inserts advance-warning `notifications` rows for docs whose `expires_at` is within N days; schedule it daily too.
- **Done when:** a past-due licence flips to `expired` overnight without manual SQL, and a "expires in 30 days" notification appears.

### Rail B — Push delivery rail *(unblocks #8; supercharges the in-app notification centre)*
- **Pick:** **Firebase Cloud Messaging** (`firebase_messaging`) — free, first-class Flutter Android+iOS support. (OneSignal is the fallback if you want a console + segmentation without managing FCM keys; it has a free tier.)
- **Steps:**
  1. Add `firebase_messaging` + platform config (google-services.json / APNs key). Register device token on login.
  2. Migration: `device_tokens (user_id, token, platform, updated_at)` with RLS (owner-only write).
  3. Edge function `push-send` (service-role) wrapping the FCM HTTP v1 API — mirror the `verify-*` function structure (`_shared` client, audit, error envelope).
  4. Fan-out: DB trigger or edge function on `jobs` INSERT → select matching trades (trade type ∩ geo radius) → enqueue → `push-send`.
- **Done when:** posting a job pushes a notification to matching trades' devices **and** writes the in-app `notifications` row.

### Rail C — Payments rail *(unblocks #17 earnings, #21 payments-admin; underpins #18, #19)*
- ⚠️ **The one place paid SaaS is unavoidable** — moving real money has no OSS substitute. Per the project's prefer-OSS stance, this is the documented exception. Surface options to the client:
  - **Stripe Connect** (industry standard for marketplaces; supports AU payouts) — recommended.
  - **Airwallex / PayID-PayTo** — AU-local alternatives worth pricing if Stripe fees bite.
- **Steps (processor-agnostic shape):**
  1. Migrations: `payments`, `payouts`, `invoices`/`transactions` tables + RLS (party-scoped reads).
  2. Edge functions for checkout/intent + a **webhook** receiver (verify signature) updating payment state.
  3. Only *after* the rail exists: build #17 (earnings dashboard) and the payments half of #21.
- **Done when:** a completed job can record a payment and a trade can see it in earnings.

---

## Part 3 — Step-by-step build, per gap (in sequence)

Build order follows the requirements audit's value ranking. Each gap lists **DB → backend → mobile layers → design → tests**, following the repo's feature-first recipe (Part 4).

### M1 · Trade search + availability + crew map  (#9, #13, #10) — *highest value, data half-there*

1. **DB** — add availability to `trade_profiles`:
   - Migration: `is_available boolean not null default true`, `available_from date null` (pragmatic Stage-1 model). Optional follow-up: weekly-pattern table for `table_calendar`.
   - RPC `search_trades(lat, lng, radius_km, min_rating, available_only, q, limit, offset)` — haversine on `base_latitude/longitude` (or PostGIS `earth_distance`), filter on `average_rating` + `is_available`, order by distance. RLS-safe (reads public trade fields only).
2. **Mobile — new module `lib/features/discovery/`** (trade directory; keep `home/` lean):
   - `data/`: `trade_search_remote_datasource.dart` (calls the RPC, accepts `limit`/`offset`), `trade_search_repository_impl.dart`, reuse/extend `TradeProfileModel`.
   - `domain/`: `entities/trade_search_filter.dart`, `repositories/trade_search_repository.dart`, `usecases/search_trades.dart` → `Future<Either<Failure, List<TradeProfile>>>`.
   - `presentation/`: top-level public `tradeSearchRepositoryProvider`; `TradeSearchController extends AsyncNotifier`; page with `infinite_scroll_pagination` `PagedListView` (page size 20), `JSkeletonList` first-page, empty-state (Lottie + CTA), tap-to-retry. Filter UI in a `showJSheet`.
3. **Replace sample data** — delete the home "tradies nearby" dependency on `home_sample_data.dart`; feed `TradieCard`s from the real query (one-shot, `limit:null`).
4. **Map (#10)** — in `home_map_view.dart`, add a crew `MarkerLayer` sourced from `search_trades` geo results (keep the jobs layer; toggle or layer both). Markers use `AppIcons` + theme colors.
5. **Tests** — RPC unit (mocktail repo), controller paging test, golden for the results card.
6. **Done when:** a real geo+rating+availability search returns live trades, the home list and map both use it, and `table_calendar` is either wired to availability or removed from `pubspec`.

### M2 · Scheduled runner → expiry reminders  (#22) — *Rail A*
Build **Rail A** (Part 2). Then add the advance-warning function + schedule. Mobile side already renders `notifications`, so no UI work beyond copy. **Done when** expiry + 30-day-warning notifications fire on a schedule.

### M3 · Push rail → new-job notifications  (#8) — *Rail B*
Build **Rail B** (Part 2). Fan-out query reuses M1's geo/trade-type matching. **Done when** a posted job pushes to matching trades and writes the in-app row.

### M4 · Admin moderation — users & jobs  (#21, non-payments half)
The `feat/admin-placeholder-scaffold` moderation card is **UI-only today** (no mutation calls). To make it real:
1. **DB** — `user_status` enum (`active/suspended/banned`) on `profiles` (or a `moderation_actions` table) + admin-only RLS; SECURITY DEFINER RPCs `admin_set_user_status`, `admin_set_job_status` that also write to the existing `admin_actions` audit table.
2. **Admin web** — add `.rpc(...)` mutations in `admin_users`/`admin_jobs` repos (currently read-only); wire the placeholder moderation card + a job-actions menu. Use `AdminText` tokens + `JButton.danger` (already in the admin design system).
3. **Done when** an admin can suspend/ban a user and close a job, each landing in the audit log.

### M5 · Payments rail → earnings dashboard + payments admin  (#17, #21 payments) — *Rail C, the big one*
Build **Rail C** (Part 2). Then:
- **#17 earnings:** new `lib/features/earnings/` (data/domain/presentation), `fl_chart` for the trend (finally using the declared package); `LinearPercentIndicator` for goals; `JSkeletonList` loading.
- **#21 payments admin:** new `lib/admin/features/admin_payments/` read+refund surface.
- **Done when** completed jobs produce payment records, trades see earnings charts, admins see a payments table.

### M6 · Greenfield, client-priority order  (#18, #15, #16, #19, #20)
Each is a clean new feature module following Part 4. Suggested internal order:
- **#18 Quotes** — `quotes` table (job_id, trade_id, amount, status, message), request/respond flow; leans lightly on the payments rail for "accept → invoice".
- **#15 Scheduling** + **#16 Timesheets** — `bookings` + `timesheets` (check-in/out with `geolocator` capture); `table_calendar` for the schedule view.
- **#19 Loyalty** / **#20 Referrals** — `referrals` (code, referrer, referee, reward_state) + `loyalty_ledger`; both depend on payments/credits.

### M7 · AI auto-match  (#23) — *deferred*
Client-flagged future. Defer until match/booking data accrues; then a `match_score` RPC over trade_profiles × job requirements before any ML.

---

## Part 4 — "Implement properly here" — the per-feature recipe

Every new feature in M1–M7 must be built this way (this is what keeps you *aligned*):

```
☐ DB first      migration + RLS (users see own / parties scoped; admin via role) → run check
☐ Backend       edge function ONLY for privileged/service-role work; mirror verify-* (_shared, audit, error envelope)
☐ domain/       entities (Equatable, no Flutter/Supabase imports)
                repositories/<x>_repository.dart (contract)
                usecases/<verb>_<noun>.dart → Future<Either<Failure, T>>   (fpdart)
☐ data/         models (json_serializable), <x>_remote_datasource.dart, <x>_repository_impl.dart
                repo methods accept optional limit/offset for any list that can exceed ~50 rows
☐ presentation/ TOP-LEVEL public <x>RepositoryProvider (overridable in tests)
                Controller extends AsyncNotifier; initial load in build() via Future.microtask
                currentUserId via readCurrentUserId(ref) — never SupabaseConfig.client.auth directly
                per-action AsyncValue, not a global bool isLoading
☐ UI           design system ONLY: Gap(n), .w/.h/.sp/.r, AppIcons.*, theme textTheme roles,
                JStaggeredList (4+ items), JSkeletonList (loading), showJSheet (sheets),
                empty state = Lottie + headline + CTA, PagedListView (long lists)
☐ Tests        repo unit (mocktail), controller test (ProviderScope overrides), golden if novel UI
☐ Gate         bash scripts/check-architecture.sh && bash scripts/validate.sh  → green before PR
☐ File size    every .dart ≤ 400 LOC target / 500 ceiling; split page→widgets, controller→sub-notifiers
```

**Hard rules that fail CI if broken:** no `GoogleFonts.*` outside theme, no `Colors.white` without `// intentional`, no raw `SizedBox` spacing in features, no hardcoded `Color(0xFF…)`, `presentation/` never imports sibling `data/`, `domain/` never imports Flutter/Supabase.

---

## Part 5 — Milestones & dependencies

| Milestone | Delivers | Depends on | Rough size |
|-----------|----------|-----------|-----------|
| **M1** | Trade search + availability + crew map (#9,#13,#10) | — (data half-there) | M |
| **M2** | Expiry reminders (#22) | Rail A | S |
| **M3** | New-job push (#8) | Rail B + M1 matching | M |
| **M4** | Admin user/job moderation (#21a) | — (placeholder exists) | S–M |
| **M5** | Payments rail + earnings + payments-admin (#17,#21b) | Rail C | L |
| **M6** | Quotes, scheduling, timesheets, loyalty, referrals (#18,#15,#16,#19,#20) | M5 (most) | L |
| **M7** | AI auto-match (#23) | data accrual | deferred |

**Critical path for "Stage 1 functionally complete":** Rails A+B+C → M1 → M2 → M3 → M4 → M5 → M6. M1 and M4 can run in parallel with the rails since they need no new infra.

---

## Appendix — re-audit after each gap

```bash
bash scripts/check-architecture.sh          # 7 Clean-Architecture checks
bash scripts/validate.sh                     # design + format + lint + tests
grep -rn "sample" lib/features/home          # #9: is the tradie list still sample data?
grep -rl "table_calendar\|fl_chart" lib/     # #13/#17: are the declared packages used yet?
ls supabase/functions                        # push-send? payments webhook? present yet?
psql "$SUPABASE_DB_URL" -c "select * from cron.job;"   # #22: is the sweep scheduled?
```

Update `STAGE1_CLIENT_REQUIREMENTS_AUDIT.md`'s scorecard as each gap flips ❌/🟡 → ✅.

---

*Grounded in a repo read on 2026-06-01. Build order optimises for product value and rail-dependency, not requirement number.*
