# Trade Search & Availability (M1 · slice 1) — Design Spec

**Date:** 2026-06-04
**Branch:** `fix/core-job-loop` (M1 work will branch off the current tip)
**Closes:** Requirement #9 (search trades by location / rating / availability) and the availability *filter* portion of #13.
**Defers:** #10 crew-map markers (tight fast-follow), #13 full weekly availability calendar, trades-discovering-other-crews, any payments/booking coupling.
**Companions:** [`STAGE1_COMPLETION_PLAN.md`](../../STAGE1_COMPLETION_PLAN.md) (M1), [`STAGE1_CLIENT_REQUIREMENTS_AUDIT.md`](../../STAGE1_CLIENT_REQUIREMENTS_AUDIT.md) (#9/#10/#13).

---

## 1. Problem & context

The home screen used to show a "tradies nearby" list backed by `home_sample_data.dart`. That sample data was deleted (commit `0abcbbe`) and replaced with an empty state. There is **no real trade-directory search anywhere** in the app — `JobFilter` only filters *jobs*. This slice fills that empty state with a real geo + rating + availability search.

Foundations already in the repo (no rework needed):

- `trade_profiles.base_latitude/base_longitude` (+ composite btree index), `service_radius_km`, `average_rating`, `rating_count` — migration `20260522000001_places_columns.sql`.
- `builder_profiles.service_latitude/service_longitude` (+ index) — gives the builder a default search origin.
- Reusable widgets: `core/design/widgets/tradie_card.dart` (result card), `core/widgets/inputs/j_place_field.dart` + `features/jobs/presentation/widgets/jobs_search_place_chip.dart` (origin override), geolocator wiring in `home_map_view.dart`/`home_page.dart` (device origin).
- Proven pattern to mirror: `features/jobs/presentation/providers/jobs_provider.dart` (`JobsController` = single controller exposing a first-page list for home **and** a `PagingController` for the full page).

**Missing:** an `availability` field on `trade_profiles`, a search RPC, and the `discovery/` feature module.

## 2. Scope decisions (locked)

| Decision | Choice | Why |
|---|---|---|
| Availability model | `is_available bool` + `available_from date` | Simplest real model that satisfies #9's filter; full weekly calendar (#13) deferred. |
| Entry point | Home "tradies nearby" section (mini-list) → full discovery page | Reuses the slot the sample list vacated; no bottom-nav change. |
| Slice size | Search + list only (#9). Crew-map markers (#10) = fast-follow. | Smallest shippable, reviewable unit; proves `search_trades` before the map leans on it. |
| Geo backbone | **Bounding-box prefilter + haversine** (no PostGIS yet) | Index-friendly, no full-table scan, no new extension; clean migration to PostGIS only if volume demands. |
| Primary searcher | Builders | Builders hire trades. Trades-discovering-crews is out of scope. |

## 3. Architecture

New feature module `lib/features/discovery/`, following feature-first Clean Architecture exactly like `jobs/`. `presentation/` imports `domain/` only; the provider file is the single seam wiring `data/` impls into providers; `domain/` imports no Flutter/Supabase.

```
lib/features/discovery/
  domain/
    entities/trade_search_filter.dart      # origin(lat,lng) + radiusKm + minRating + availableOnly + query
    entities/trade_search_result.dart      # { TradeProfile trade; double distanceKm }  (match_score later)
    repositories/trade_search_repository.dart
    usecases/search_trades.dart            # Future<Either<Failure, List<TradeSearchResult>>>
  data/
    datasources/trade_search_remote_datasource.dart   # calls search_trades RPC, accepts limit/offset
    repositories/trade_search_repository_impl.dart
    # TradeProfileModel (in profile/) extended with is_available / available_from / distance_km mapping
  presentation/
    providers/discovery_provider.dart      # public tradeSearchRepositoryProvider + controller + state
    pages/discovery_page.dart              # full search page (PagedListView)
    pages/discovery_page_widgets.dart      # private widgets if discovery_page nears the LOC budget
    widgets/trade_filter_sheet.dart        # showJSheet content
```

### Why `TradeSearchResult` instead of adding `distanceKm` to `TradeProfile`

`distance_km` is computed per-query and is meaningless outside a search context. Putting it on the shared `TradeProfile` entity would make it null in ~90% of usages and invite "why is this null here?" bugs. The wrapper keeps the core entity clean and is the natural home for `match_score` when #23 (AI auto-match) arrives. The genuine table columns `is_available` / `available_from` **do** go on `TradeProfile` — they are real fields.

### Why one controller, two views

`TradeSearchController extends Notifier<TradeSearchState>` owns:

- `state.results` — latest first page; the home mini-list reads `take(3)`.
- a `PagingController<int, TradeSearchResult>` (page size 20) — the full discovery page reads it via `PagedListView`, back-filling on scroll.

One controller = one source of truth, no redundant second fetch for the home list. Clears state on logout/account-switch via `ref.listen(currentUserIdProvider, …)`, mirroring `JobsController`.

## 4. Database

One migration: `supabase/migrations/<ts>_trade_search.sql`.

### 4.1 Columns + indexes

> **Schema-drift fix (discovered during planning):** `TradeProfileModel.fromJson` already reads `average_rating` / `rating_count`, but **those columns were never created** — ratings live only in `reviews` (`reviewee_id`, `rating`). This migration adds the real columns and keeps them in sync, fixing the drift *and* giving the search an index-able rating to filter on. (`hire_count` / `jobs_completed` / `total_applications` are also phantom in the model but out of scope here — noted for a later cleanup.)

```sql
ALTER TABLE public.trade_profiles
  ADD COLUMN IF NOT EXISTS is_available   boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS available_from date,
  ADD COLUMN IF NOT EXISTS average_rating numeric(3,2),
  ADD COLUMN IF NOT EXISTS rating_count   int NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS trade_profiles_is_available_idx
  ON public.trade_profiles (is_available);
CREATE INDEX IF NOT EXISTS trade_profiles_average_rating_idx
  ON public.trade_profiles (average_rating);
-- composite (base_latitude, base_longitude) btree already exists (places_columns migration)
```

**Rating denormalisation** — `recompute_trade_rating(p_trade_id uuid)` recomputes `average_rating`/`rating_count` from `reviews` for one reviewee that has a `trade_profiles` row; an `AFTER INSERT/UPDATE/DELETE` trigger on `reviews` calls it for the affected `reviewee_id`; a one-time backfill seeds existing rows. Builders share the same model drift in `builder_profiles` — explicitly out of scope this slice.

### 4.2 `search_trades` RPC

- `SECURITY INVOKER` (respects existing `trade_profiles` RLS — reads public trade fields only).
- Signature: `search_trades(p_lat double precision, p_lng double precision, p_radius_km int, p_min_rating numeric, p_available_only boolean, p_query text, p_limit int, p_offset int)`.
- Behaviour:
  1. **Bounding-box prefilter** — compute lat/lng deltas for `p_radius_km` and constrain `base_latitude`/`base_longitude` to that box (lets the existing composite btree prune before any trig).
  2. **Haversine** — exact `distance_km` for the survivors; `WHERE distance_km <= p_radius_km`.
  3. **Availability** — when `p_available_only`, `(is_available = true OR available_from <= current_date)` so a future "free from" date auto-qualifies once it passes (no babysitter cron needed).
  4. **Rating** — when `p_min_rating` is set, `average_rating >= p_min_rating` (null ratings excluded).
  5. **Query** — when `p_query` non-empty, `ILIKE` over `full_name` / `primary_trade` / `trade_other`.
  6. Exclude `deleted_at IS NOT NULL`. Exclude null-geo rows when a radius is set.
  7. **Order** by `distance_km ASC`; `LIMIT p_limit OFFSET p_offset`.
- **Explicit return table** (stable contract — not `setof trade_profiles`): the trade fields the card needs **plus** `distance_km`.

## 5. UI / design system

All design tokens via the system (`Gap`, `.w/.h/.sp/.r`, `AppIcons.*`, theme `textTheme` roles). No raw `SizedBox` spacing, no `GoogleFonts.*`, no hardcoded colors.

- **Home mini-list** — replaces the tradies empty-state. Reads the shared controller's first page (`take(3)`). `JSkeletonList` while loading; Lottie + headline + CTA when empty; "See all" routes to the discovery page.
- **Discovery page** — `PagedListView` of `tradie_card.dart` (distance + rating + availability badge), page size 20. First-page `JSkeletonList`; empty = Lottie + headline + CTA; error = tap-to-retry indicator; wrapped in `RefreshIndicator` → `pagingController.refresh()`. Filter entry opens `trade_filter_sheet.dart` via `showJSheet` (radius slider, min-rating, available-only toggle, text query). Origin resolution: builder `service_lat/lng` default → `j_place_field` chip override → device geolocation fallback.
- **Trade availability controls** — add `is_available` toggle + optional `available_from` date to the trade profile-edit screen, wired through the existing profile controller/repo, so a trade can actually mark themselves available/unavailable (otherwise the filter has nothing to act on).

### 5.1 Voice & microcopy (Australian, on-system)

Jobdun's locked voice is **blunt, plain, no-handholding** (`MASTER.md`: "No handholding microcopy. No 'Yay!' empty states"; `auth-onboarding.md`: "Do NOT use soft welcome copy"). That already matches how Australian tradies talk — direct, concrete, no corporate fluff. So "easy for Aussies" here means **plain words + AU spelling (`licence`, `km`), not slang or chumminess.** Buttons/headlines render ALL-CAPS per the Aggressive-Flat style. No cutesy empty states; restrained Lottie + blunt headline + CTA.

| Where | Copy |
|---|---|
| Home section header | `TRADIES NEAR YOU` |
| Home "see all" affordance | `SEE ALL` |
| Home empty state | headline `NO TRADIES NEARBY` · sub `Widen your search radius.` · CTA `WIDEN SEARCH` |
| Discovery page title | `FIND A TRADIE` |
| Search field hint | `Search by trade or name` |
| Filter sheet | title `FILTERS` · `DISTANCE` (value `Within 25 km`) · `MINIMUM RATING` · `ONLY SHOW AVAILABLE` · apply `SHOW TRADIES` · `CLEAR` |
| Result card — availability badge | `AVAILABLE` (available now) · `FREE FROM 15 JUN` (future `available_from`) · hidden when off |
| Result card — meta | `2.3 km away` · `4.8 ★ (12)` |
| Discovery empty state | headline `NO TRADIES MATCH` · sub `Try a wider radius or fewer filters.` · CTA `CLEAR FILTERS` |
| Trade profile — availability toggle | `OPEN FOR WORK` · helper `Show up in builders' searches.` |
| Trade profile — from date | `AVAILABLE FROM` · helper `Leave blank if you're ready now.` |
| Load error (tap-to-retry) | `Couldn't load tradies. Tap to try again.` |

All user-facing strings in this feature MUST use AU spelling and the blunt voice above. No `Welcome`, no `Yay!`, no exclamation-heavy encouragement.

## 6. Routing

Add `/discovery` (builder-facing) to GoRouter, reached from the home "See all" affordance. No bottom-nav tab added in this slice.

## 7. Error / loading / empty handling

Per-action state on the controller (no single global `bool isLoading` + `String? error`). First-page skeleton, Lottie empty state, tap-to-retry error indicator on the paged list. Spinners reserved for inline/overlay only.

## 8. Testing

- **Repo unit** — `trade_search_repository_impl` over a mocktail datasource: maps RPC rows → `TradeSearchResult`, propagates failures as `Left(Failure)`.
- **Controller** — `TradeSearchController` with `ProviderScope` overrides + fake repo: first page populates `state.results`, append advances the page, short page → `appendLastPage`, logout clears state + refreshes paging.
- **Golden** — `tradie_card` in search context (distance + availability badge), since it's novel UI.

## 9. File-size budget

Every new `.dart` ≤ 400 LOC target / 500 ceiling. If `discovery_page.dart` grows, split private widgets into `discovery_page_widgets.dart`; if the controller spans sub-domains, split per the recipe. None of these files is expected to approach the ceiling.

## 10. Definition of done

- A real geo + rating + availability search returns live trades ordered by distance.
- The home "tradies nearby" section shows live results (no sample data) with a working empty state.
- A trade can toggle their availability and it affects search results.
- `bash scripts/check-architecture.sh && bash scripts/validate.sh` green.
- Audit scorecard updated: #9 ❌→✅, #13 note updated (availability filter done; calendar still deferred).

## 11. Explicitly out of scope (this slice)

- #10 crew-map markers (fast-follow once `search_trades` is proven).
- #13 full weekly availability calendar / `table_calendar` wiring.
- Trades searching/discovering other crews.
- PostGIS adoption (migration path noted; not needed at Stage-1 volume).
- Any payments, booking, or messaging coupling.
