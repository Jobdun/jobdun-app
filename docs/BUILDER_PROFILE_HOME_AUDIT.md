# Builder Profile + Company Details + Home — Data & Verification Audit

**Date:** 2026-06-04 · **Branch:** `feat/discovery-trade-search` · **Type:** findings only, zero code changed.

**Scope.** The builder-facing **Profile page** (`/profile`), the **COMPANY DETAILS** card and how
each field is verified, and how all of that **compares to the builder Home page** (`/home`,
bento-grid direction #02). The question driving it: *does the profile show real data, and does it
agree with what Home shows?*

Companion docs (not duplicated here): `docs/VERIFICATION_FLOW_AUDIT.md` (full end-to-end
verification flow, both roles, 2026-05-30) and the schema-drift memory note
`memory/project_trade_profiles_schema_drift.md`.

Severity legend: **Critical** (broken/fake data a user sees) · **High** (visible
inconsistency / standards break) · **Med** (edge-case or hygiene) · **Low** (future-proofing).
Every claim is pinned to `file:line` and is provable from source.

---

## 0. TL;DR

- The builder Profile page's **top stat row — Rating / Reviews / Jobs posted — is 100% fake.**
  All three read columns that **do not exist on `builder_profiles`** (`average_rating`,
  `rating_count`, `total_jobs_posted`). The query never errors (it `SELECT`s `*` and the model
  defaults missing keys to `0`/`null`), so they render a permanent **`—` / `0` / `0`**. **[F1, Critical]**
- The builder **Home** page shows the **same metrics correctly** via dedicated providers
  (`builderActiveJobsCountProvider` counts real job rows; applicants come from the applications
  controller). So Home and Profile **disagree by construction**: Home says "3 active jobs",
  Profile says "0 jobs posted". **[F1, F2]**
- The **COMPANY DETAILS** card is the healthy part — it's wired to two real sources
  (self-entered `builder_profiles` columns + regulator-truth `verifications` rows) and degrades
  honestly to "Not set". One blemish: **Type defaults to a hard-coded `"Company"`** when no ABN is
  verified. **[F4, Med]**
- `_StatsRow`'s builder branch (`home_widgets.dart`) is **dead code for builders** and itself reads
  the same phantom columns — a trap for the next person who re-enables it. **[F3, Med]**
- Builders can be **reviewees** in `reviews`, but the rating-recompute trigger **only updates
  `trade_profiles`** — there is no builder rating aggregation anywhere in the schema, so a builder
  rating *cannot* be real today even if the column existed. **[F5, High]**

---

## 1. What each surface renders, and where the data comes from

### 1a. Builder Profile page — top stat row (the broken part)

`lib/features/profile/presentation/pages/profile_page_sections.dart:149-225`

```dart
final rating     = p?.averageRating?.toStringAsFixed(1) ?? '—';   // :149
final reviews    = (p?.ratingCount ?? 0).toString();              // :150
final jobsPosted = (p?.totalJobsPosted ?? 0).toString();          // :151
// → JStatBadge( Rating ), JStatBadge( Reviews ), JStatBadge( Jobs posted )  :205-225
```

These read `BuilderProfile.averageRating`, `.ratingCount`, `.totalJobsPosted`
(`domain/entities/builder_profile.dart:21-51`), populated by
`BuilderProfileModel.fromJson` from JSON keys `average_rating`, `rating_count`,
`total_jobs_posted` (`data/models/builder_profile_model.dart:45-49`).

**None of those keys are returned, because the columns don't exist** (see §3). Because
`fromJson` uses `as int? ?? 0` / `(… as num?)?.toDouble()`, a *missing* key is indistinguishable
from a real `0`/`null`. No exception is thrown (unlike the old `bio`/`onboarding_completed_at`
case which 400'd — `profile_remote_datasource.dart:38-42`), so the failure is **silent**.

### 1b. Builder Profile page — COMPANY DETAILS card (the healthy part)

`profile_page_sections.dart:228-291`. Two data sources, correctly separated:

| Row | Source | Real? |
|-----|--------|-------|
| Company | `builder_profiles.company_name` | ✅ real column |
| ABN | `builder_profiles.abn` (formatted `_formatAbn`); tick from verified ABN row | ✅ |
| Type | `verifications.entity_type` — **falls back to literal `"Company"`** | ⚠️ default fabricated |
| In business since | `verifications.abn_registered_at` | ✅ ABR truth |
| Registered | `verifications.abr_state` + `abr_postcode` | ✅ ABR truth |
| Phone | `builder_profiles.contact_phone` → falls back to `profiles.phone`; tick = `phone_verified_at` | ✅ |
| Services in | `builder_profiles.service_suburb`/`service_state` | ✅ |
| Website | `builder_profiles.website` | ✅ |

The ABR facts come from `myVerificationsProvider` (`verifications_provider.dart:53-57`), filtered
to the verified `abn` row (`profile_page_sections.dart:178-194`). The inline green tick on a row is
*just* a confirmation; the full receipt is the **WHAT'S BEEN CHECKED** panel below
(`VerificationReceipts`, `profile_page_sections.dart:286-291`).

### 1c. Builder Home page — bento grid (the reference for "real data")

`lib/features/home/presentation/pages/home_builder_bento.dart:40-108`

| Tile | Source | Real? |
|------|--------|-------|
| ACTIVE JOBS | `builderActiveJobsCountProvider` → `getBuilderJobs(uid)` then `where(status.isActive)` | ✅ real rows |
| APPLICANTS | `applicationsControllerProvider.pendingIncomingCount` | ✅ real |
| Tradies nearby | `tradeSearchControllerProvider.results` (origin = builder's service lat/lng) | ✅ real |
| POST A JOB / FIND A TRADIE / MESSAGES | navigation only | n/a |

`builderActiveJobsCountProvider` (`jobs_provider.dart:74-84`) exists **specifically because**
`builder_profiles.active_jobs_count` was a phantom column that always read 0 — see its own comment
at `jobs_provider.dart:69-73`. So Home already solved this problem; **Profile never got the fix.**

---

## 2. Profile ⇄ Home comparison (the core ask)

| Metric | Home (bento) | Profile (stat row) | Agree? |
|--------|--------------|--------------------|--------|
| Active / posted jobs | `builderActiveJobsCountProvider` — **real count** | `builder_profiles.total_jobs_posted` — **phantom → always 0** | ❌ contradict |
| Applicants | `pendingIncomingCount` — **real** | *(not shown on profile)* | n/a |
| Rating | *(not shown on home)* | `average_rating` — **phantom → `—`** | n/a (but fake) |
| Reviews | *(not shown on home)* | `rating_count` — **phantom → 0** | n/a (but fake) |
| Company / ABN / location | derived from `builderProfile.displayLocation` for the map label | full COMPANY DETAILS card — **real** | ✅ consistent |

**Net:** the COMPANY DETAILS card and the location label agree and are real. The **numeric
stat badges are the only place the two screens diverge, and Profile is the wrong one** — it shows
zeros/dashes for a builder who, per Home, demonstrably has live jobs.

---

## 3. Root cause — phantom `builder_profiles` columns

The real `builder_profiles` schema, assembled from migrations:

- `id, company_name, abn, created_at, updated_at` — `20260511000001_initial_schema.sql`
  (`logo_url`, `description` later **dropped** in `20260521000001_profile_schema_cleanup.sql:20-22`)
- `contact_name, contact_phone, about, website, years_in_business, service_suburb, service_state,
  service_postcode` — `20260512000005_profile_extended_columns.sql:15-23`
- `service_formatted_address, service_place_id, service_latitude, service_longitude` —
  `20260522000001_places_columns.sql`
- `deleted_at` — `20260522000002_profile_soft_delete.sql`

**Columns the model reads but that were never added to `builder_profiles`:**

| Read in model | Migration that adds it | Verdict |
|---------------|------------------------|---------|
| `total_jobs_posted` | — none — | ❌ phantom |
| `active_jobs_count` | — none — | ❌ phantom (already known: `jobs_provider.dart:69-73`) |
| `hire_count` | — none — | ❌ phantom |
| `average_rating` | only `trade_profiles` (`20260604000001_trade_search.sql:7-11`) | ❌ phantom on builder |
| `rating_count` | only `trade_profiles` (`20260604000001_trade_search.sql:7-11`) | ❌ phantom on builder |

`average_rating` / `rating_count` were added **exclusively to `trade_profiles`** in the M1
trade-search migration — `grep` confirms `20260604000001_trade_search.sql` is the *only* migration
that mentions them, and every `ALTER`/`UPDATE`/index there targets `trade_profiles`. They were
never mirrored onto `builder_profiles`.

---

## 4. Builder ratings cannot be real even with the column — review trigger is trade-only

`20260604000001_trade_search.sql:20-72`:

- `recompute_trade_rating(p_trade_id)` does `UPDATE public.trade_profiles … FROM reviews WHERE
  reviewee_id = p_trade_id`.
- The `reviews_sync_trade_rating` trigger (AFTER INSERT/UPDATE/DELETE on `reviews`) only ever calls
  that function — it **only writes `trade_profiles`**.
- The backfill comment literally says *"One-time backfill … (no-op for builder reviewees)."*

So even if a builder receives reviews, nothing aggregates them. Surfacing a real builder rating
needs **both** a `builder_profiles.average_rating/rating_count` column set **and** a
builder-aware recompute path (or a shared `recompute_rating` that branches on reviewee role).

---

## 5. The "separate code" — two parallel stacks for the same metrics

This is why Profile and Home drift: **they don't share a path.** The builder's job/rating metrics
exist in two unrelated places:

**Stack A — Home (correct, live-query):**
```
home_builder_bento.dart
  → builderActiveJobsCountProvider            (jobs_provider.dart:74-84)
  → GetBuilderJobs use case → jobRepository → builder jobs rows
  → count where status.isActive
```

**Stack B — Profile (broken, snapshot-column):**
```
profile_page_sections.dart  (_BuilderProfile stat row)
  → profileControllerProvider.builderProfile  (profile_provider.dart:90-94)
  → ProfileRepository.getBuilderProfile → SELECT * builder_profiles
  → BuilderProfileModel.totalJobsPosted / averageRating / ratingCount  ← phantom
```

**Dead third path — `_StatsRow` builder branch:** `home_widgets.dart:35-42` still computes
`builderProfile?.activeJobsCount` and `?.totalJobsPosted` for an `isBuilder` case that **never
runs on Home anymore** — builders render `_BuilderBentoGrid`, not `_StatsRow`
(`home_page.dart:334-335`; `_StatsRow` is only built in the `if (!isBuilder)` block at
`home_page.dart:339-352`). It's reachable only by the tradie branch (which reads
`tradeProfile`), so the builder columns there are pure dead weight — but they read the same
phantom fields, so re-enabling that branch would reintroduce the bug.

Meanwhile the **verification** stack is cleanly shared and not duplicated:
`myVerificationsProvider` / `verificationsForUserProvider`
(`verifications_provider.dart:44-57`) → `verifications` table; the counterparty trust badge a
*tradie sees on a builder* uses the separate `get_builder_public_verification` RPC
(`verifications_remote_datasource.dart:42-61`, RPC defined in
`20260530000001_verifications_display_projection.sql`) — a minimized, register-only projection.
Note there is **no public/counterparty builder *profile* route**; `/profile` is owner-only
(`VerificationReceipts` is always built with `isOwner: true`,
`profile_page_sections.dart:287-290`).

---

## 6. Findings

| # | Sev | Finding | Evidence |
|---|-----|---------|----------|
| **F1** | **Critical** | Builder profile Rating/Reviews/Jobs-posted are fake — phantom columns, silently default to `—`/`0`/`0`. | `profile_page_sections.dart:149-151`; `builder_profile_model.dart:45-49`; §3 |
| **F2** | High | Home and Profile contradict each other for the same builder (Home: real active jobs; Profile: 0 jobs posted). | §2; `home_builder_bento.dart:44`; `jobs_provider.dart:74-84` |
| **F3** | Med | `_StatsRow` builder branch is dead code that still reads phantom `activeJobsCount`/`totalJobsPosted` — a re-enable trap. | `home_widgets.dart:35-42`; `home_page.dart:334-352` |
| **F4** | Med | COMPANY DETAILS "Type" row shows hard-coded `"Company"` (no tick) when no ABN verified — a fabricated default, not user data. | `profile_page_sections.dart:245-247` |
| **F5** | High | No builder rating aggregation exists in the schema; review trigger is `trade_profiles`-only. A real builder rating is impossible today. | `20260604000001_trade_search.sql:20-72` |
| **F6** | Low | `ProfilePage` loads via `addPostFrameCallback` in `initState`; CLAUDE.md prefers `Future.microtask(_load)` inside `Notifier.build()`. Pre-existing pattern, not introduced here. | `profile_page.dart:41-46` |
| **F7** | Low | `BuilderProfile` entity carries `hireCount` (also phantom) — never read by UI today but invites the same trap. | `builder_profile.dart:23,49` |

---

## 7. Recommendations (no code changed in this pass)

**Pick one of two strategies for the broken stats (F1/F2):**

1. **Cheapest / matches Home (recommended):** drop `Rating`/`Reviews`/`Jobs posted` from the
   builder stat row's reliance on `builder_profiles`, and source **Jobs posted** from the same
   `getBuilderJobs(uid)` query Home already uses (a `builderJobsCountProvider` returning
   `jobs.length`; or reuse the active-count provider's underlying fetch). Rating/Reviews stay
   hidden for builders until F5 is solved — don't show a metric you can't compute.

2. **Schema-complete:** add real `total_jobs_posted` (maintained by a jobs trigger or computed
   view), and `average_rating`/`rating_count` to `builder_profiles` **plus** a builder-aware
   `recompute_rating` (generalise `recompute_trade_rating`). Heavier; only worth it if builder
   ratings are a near-term product requirement.

**Independent of the above:**

- **F3:** delete the builder branch of `_StatsRow` (or assert `!isBuilder`) so the phantom reads
  can't be resurrected.
- **F4:** render the Type row only when `entityType != null` (same pattern the "In business since"
  / "Registered" rows already use at `profile_page_sections.dart:248-261`), instead of defaulting
  to `"Company"`.
- **F7:** drop `hireCount` (and the still-declared `activeJobsCount`) from `BuilderProfile` once
  the stat row stops touching them, so the entity stops advertising columns that don't exist.

**What's already good and should NOT be touched:** the COMPANY DETAILS ↔ verifications split, the
WHAT'S BEEN CHECKED receipts panel, the counterparty `get_builder_public_verification` projection,
and Home's `builderActiveJobsCountProvider`. These are correctly wired to real data.
