# Trade Search & Availability (M1 · slice 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let builders search for tradies by location, rating and availability — a live home mini-list plus a full filterable `/discovery` page — closing requirement #9 and #13's availability filter.

**Architecture:** New feature module `lib/features/discovery/` in feature-first Clean Architecture, mirroring `lib/features/jobs/`. A SECURITY-INVOKER `search_trades` Postgres RPC does a bounding-box + haversine geo search over `trade_profiles`; one `TradeSearchController` (Notifier) exposes both the home first-page list and a `PagingController` for the full page. Ratings are denormalised onto `trade_profiles` by a trigger on `reviews` (also fixes an existing model↔DB drift).

**Tech Stack:** Flutter, Riverpod 3 (`Notifier`), fpdart `Either<Failure,T>`, Supabase (PostgREST `.rpc`), `infinite_scroll_pagination`, mocktail. Design system: `tradie_card.dart`, `j_skeleton_list.dart`, `empty_state.dart`, `showJSheet`, `j_switch.dart`, `Gap`, screenutil, `AppIcons`.

**Spec:** `docs/superpowers/specs/2026-06-04-trade-search-design.md`

---

## File map

| File | Responsibility |
|------|----------------|
| `supabase/migrations/20260604000001_trade_search.sql` | availability + rating columns, indexes, rating trigger+backfill, `search_trades` RPC |
| `lib/features/discovery/domain/entities/trade_search_filter.dart` | search params value object |
| `lib/features/discovery/domain/entities/trade_search_result.dart` | `{ TradeProfile trade; double distanceKm }` |
| `lib/features/discovery/domain/repositories/trade_search_repository.dart` | repo contract |
| `lib/features/discovery/domain/usecases/search_trades.dart` | use case over repo |
| `lib/features/discovery/data/datasources/trade_search_remote_datasource.dart` | calls `search_trades` RPC |
| `lib/features/discovery/data/repositories/trade_search_repository_impl.dart` | exception→Failure boundary |
| `lib/features/discovery/presentation/providers/discovery_provider.dart` | providers + `TradeSearchController` + `TradeSearchState` |
| `lib/features/discovery/presentation/pages/discovery_page.dart` | full search page (`PagedListView`) |
| `lib/features/discovery/presentation/widgets/trade_filter_sheet.dart` | `showJSheet` filter content |
| `lib/features/discovery/presentation/widgets/discovery_tradie_tile.dart` | maps `TradeSearchResult`→`TradieCard` |
| `lib/features/profile/domain/entities/trade_profile.dart` | **modify** — add `isAvailable`/`availableFrom` |
| `lib/features/profile/data/models/trade_profile_model.dart` | **modify** — map + emit new columns |
| `lib/features/home/presentation/pages/home_page.dart` | **modify** — builder "TRADIES NEAR YOU" section |
| `lib/features/profile/presentation/pages/profile_edit_form_fields.dart` | **modify** — availability controls |
| `lib/app/router/app_router.dart` | **modify** — add `/discovery` |

Tests: `test/features/discovery/{trade_search_entities_test,search_trades_usecase_test,trade_search_repository_test,trade_search_controller_test}.dart`, `test/features/profile/trade_profile_model_availability_test.dart`, `test/golden/discovery_tradie_tile_test.dart`.

---

## Task 1: DB migration — availability + rating denormalisation + search_trades RPC

**Files:**
- Create: `supabase/migrations/20260604000001_trade_search.sql`

- [ ] **Step 1: Write the migration**

```sql
-- 20260604000001_trade_search.sql
-- M1 slice 1: trade availability + denormalised rating + geo search RPC.

-- 1. Availability columns + denormalised rating columns.
--    average_rating / rating_count fix an existing drift: TradeProfileModel
--    already reads them, but they were never created (ratings live in reviews).
ALTER TABLE public.trade_profiles
  ADD COLUMN IF NOT EXISTS is_available   boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS available_from date,
  ADD COLUMN IF NOT EXISTS average_rating numeric(3,2),
  ADD COLUMN IF NOT EXISTS rating_count   int NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS trade_profiles_is_available_idx
  ON public.trade_profiles (is_available);
CREATE INDEX IF NOT EXISTS trade_profiles_average_rating_idx
  ON public.trade_profiles (average_rating);

-- 2. Rating denormalisation: recompute one trade's average from reviews.
--    SECURITY DEFINER so the reviews trigger (fired by the reviewer, not the
--    trade owner) can update trade_profiles despite owner-only update RLS.
CREATE OR REPLACE FUNCTION public.recompute_trade_rating(p_trade_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.trade_profiles tp
  SET average_rating = sub.avg_rating,
      rating_count   = sub.cnt
  FROM (
    SELECT round(avg(rating)::numeric, 2) AS avg_rating, count(*)::int AS cnt
    FROM public.reviews
    WHERE reviewee_id = p_trade_id
  ) sub
  WHERE tp.id = p_trade_id;
$$;

CREATE OR REPLACE FUNCTION public.reviews_sync_trade_rating()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    PERFORM public.recompute_trade_rating(OLD.reviewee_id);
    RETURN OLD;
  END IF;
  PERFORM public.recompute_trade_rating(NEW.reviewee_id);
  IF (TG_OP = 'UPDATE' AND OLD.reviewee_id <> NEW.reviewee_id) THEN
    PERFORM public.recompute_trade_rating(OLD.reviewee_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS reviews_sync_trade_rating_trg ON public.reviews;
CREATE TRIGGER reviews_sync_trade_rating_trg
  AFTER INSERT OR UPDATE OR DELETE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.reviews_sync_trade_rating();

-- One-time backfill of existing reviews (no-op for builder reviewees).
UPDATE public.trade_profiles tp
SET average_rating = sub.avg_rating, rating_count = sub.cnt
FROM (
  SELECT reviewee_id,
         round(avg(rating)::numeric, 2) AS avg_rating,
         count(*)::int AS cnt
  FROM public.reviews
  GROUP BY reviewee_id
) sub
WHERE tp.id = sub.reviewee_id;

-- 3. Geo search RPC. Bounding-box prefilter (uses the existing
--    (base_latitude, base_longitude) btree) then haversine for exact distance.
--    SECURITY INVOKER → trade_profiles_select_authenticated RLS applies.
CREATE OR REPLACE FUNCTION public.search_trades(
  p_lat            double precision,
  p_lng            double precision,
  p_radius_km      int,
  p_min_rating     numeric DEFAULT NULL,
  p_available_only boolean DEFAULT false,
  p_query          text    DEFAULT NULL,
  p_limit          int     DEFAULT 20,
  p_offset         int     DEFAULT 0
)
RETURNS TABLE (
  id uuid, full_name text, primary_trade text, crew_size int,
  years_experience int, hourly_rate_min numeric, hourly_rate_max numeric,
  hourly_rate_visible boolean, service_radius_km int,
  base_suburb text, base_state text, base_postcode text,
  base_formatted_address text, base_place_id text,
  base_latitude double precision, base_longitude double precision,
  about text, trade_other text, licence_url text, portfolio_urls text[],
  is_verified boolean, verified_at timestamptz,
  average_rating numeric, rating_count int,
  is_available boolean, available_from date,
  distance_km double precision
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT * FROM (
    SELECT
      tp.id, tp.full_name, tp.primary_trade, tp.crew_size,
      tp.years_experience, tp.hourly_rate_min, tp.hourly_rate_max,
      tp.hourly_rate_visible, tp.service_radius_km,
      tp.base_suburb, tp.base_state, tp.base_postcode,
      tp.base_formatted_address, tp.base_place_id,
      tp.base_latitude, tp.base_longitude,
      tp.about, tp.trade_other, tp.licence_url, tp.portfolio_urls,
      tp.is_verified, tp.verified_at,
      tp.average_rating, tp.rating_count,
      tp.is_available, tp.available_from,
      (6371 * acos(least(1.0, greatest(-1.0,
        cos(radians(p_lat)) * cos(radians(tp.base_latitude)) *
        cos(radians(tp.base_longitude) - radians(p_lng)) +
        sin(radians(p_lat)) * sin(radians(tp.base_latitude))
      )))) AS distance_km
    FROM public.trade_profiles tp
    WHERE tp.deleted_at IS NULL
      AND tp.base_latitude  IS NOT NULL
      AND tp.base_longitude IS NOT NULL
      AND tp.base_latitude  BETWEEN
            (p_lat - (p_radius_km / 111.0)) AND (p_lat + (p_radius_km / 111.0))
      AND tp.base_longitude BETWEEN
            (p_lng - (p_radius_km / (111.0 * cos(radians(p_lat))))) AND
            (p_lng + (p_radius_km / (111.0 * cos(radians(p_lat)))))
      AND (NOT p_available_only
           OR tp.is_available = true
           OR tp.available_from <= current_date)
      AND (p_min_rating IS NULL OR tp.average_rating >= p_min_rating)
      AND (p_query IS NULL OR p_query = ''
           OR tp.full_name     ILIKE '%' || p_query || '%'
           OR tp.primary_trade ILIKE '%' || p_query || '%'
           OR COALESCE(tp.trade_other, '') ILIKE '%' || p_query || '%')
  ) sub
  WHERE sub.distance_km <= p_radius_km
  ORDER BY sub.distance_km ASC
  LIMIT p_limit OFFSET p_offset;
$$;

GRANT EXECUTE ON FUNCTION public.search_trades(
  double precision, double precision, int, numeric, boolean, text, int, int
) TO authenticated;
```

- [ ] **Step 2: Apply + verify**

Run (whichever applies to the environment):
`supabase db reset` (local) **or** apply the file via the migration pipeline.
Then verify:
```bash
psql "$SUPABASE_DB_URL" -c "\d public.trade_profiles" | grep -E "is_available|available_from|average_rating|rating_count"
psql "$SUPABASE_DB_URL" -c "select id, distance_km from public.search_trades(-33.8688, 151.2093, 50, null, false, null, 5, 0);"
```
Expected: the four columns are listed; the `search_trades` call returns rows (or zero rows) with a numeric `distance_km`, no error.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260604000001_trade_search.sql
git commit -m "feat(db): trade availability + denormalised rating + search_trades RPC"
```

---

## Task 2: Domain — search entities + repository contract

**Files:**
- Create: `lib/features/discovery/domain/entities/trade_search_filter.dart`
- Create: `lib/features/discovery/domain/entities/trade_search_result.dart`
- Create: `lib/features/discovery/domain/repositories/trade_search_repository.dart`
- Test: `test/features/discovery/trade_search_entities_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_filter.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_result.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';

void main() {
  test('TradeSearchFilter copyWith overrides only named fields', () {
    const f = TradeSearchFilter(originLat: -33.8, originLng: 151.2);
    final g = f.copyWith(radiusKm: 10, availableOnly: true);
    expect(g.radiusKm, 10);
    expect(g.availableOnly, isTrue);
    expect(g.originLat, -33.8); // unchanged
  });

  test('TradeSearchResult equality is by trade id + distance', () {
    const t = TradeProfile(id: 't1', fullName: 'Bob', primaryTrade: 'electrician');
    const a = TradeSearchResult(trade: t, distanceKm: 2.5);
    const b = TradeSearchResult(trade: t, distanceKm: 2.5);
    expect(a, equals(b));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/discovery/trade_search_entities_test.dart`
Expected: FAIL — `trade_search_filter.dart`/`trade_search_result.dart` don't exist.

- [ ] **Step 3: Write the entities + contract**

`trade_search_filter.dart`:
```dart
import 'package:equatable/equatable.dart';

/// Inputs for a trade-directory search. `origin*` is the point distance is
/// measured from (builder base → place override → device geo).
class TradeSearchFilter extends Equatable {
  const TradeSearchFilter({
    this.originLat,
    this.originLng,
    this.radiusKm = 25,
    this.minRating,
    this.availableOnly = false,
    this.query,
  });

  final double? originLat;
  final double? originLng;
  final int radiusKm;
  final double? minRating;
  final bool availableOnly;
  final String? query;

  bool get hasOrigin => originLat != null && originLng != null;

  TradeSearchFilter copyWith({
    double? originLat,
    double? originLng,
    int? radiusKm,
    double? minRating,
    bool clearMinRating = false,
    bool? availableOnly,
    String? query,
    bool clearQuery = false,
  }) => TradeSearchFilter(
    originLat: originLat ?? this.originLat,
    originLng: originLng ?? this.originLng,
    radiusKm: radiusKm ?? this.radiusKm,
    minRating: clearMinRating ? null : (minRating ?? this.minRating),
    availableOnly: availableOnly ?? this.availableOnly,
    query: clearQuery ? null : (query ?? this.query),
  );

  @override
  List<Object?> get props =>
      [originLat, originLng, radiusKm, minRating, availableOnly, query];
}
```

`trade_search_result.dart`:
```dart
import 'package:equatable/equatable.dart';

import '../../../profile/domain/entities/trade_profile.dart';

/// One search hit: the trade plus the per-query distance from the origin.
/// distance is contextual, so it lives here rather than on TradeProfile.
class TradeSearchResult extends Equatable {
  const TradeSearchResult({required this.trade, required this.distanceKm});

  final TradeProfile trade;
  final double distanceKm;

  @override
  List<Object?> get props => [trade.id, distanceKm];
}
```

`trade_search_repository.dart`:
```dart
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/trade_search_filter.dart';
import '../entities/trade_search_result.dart';

abstract interface class TradeSearchRepository {
  /// Geo + rating + availability search. When [limit] is null all matching
  /// rows are returned (one-shot, e.g. home mini-list); when set, returns the
  /// slice `[offset, offset + limit)`.
  Future<Either<Failure, List<TradeSearchResult>>> searchTrades({
    required TradeSearchFilter filter,
    int? limit,
    int? offset,
  });
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/discovery/trade_search_entities_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/discovery/domain test/features/discovery/trade_search_entities_test.dart
git commit -m "feat(discovery): trade-search domain entities + repo contract"
```

---

## Task 3: Domain — SearchTrades use case

**Files:**
- Create: `lib/features/discovery/domain/usecases/search_trades.dart`
- Test: `test/features/discovery/search_trades_usecase_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_filter.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_result.dart';
import 'package:jobdun/features/discovery/domain/repositories/trade_search_repository.dart';
import 'package:jobdun/features/discovery/domain/usecases/search_trades.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';

class MockTradeSearchRepository extends Mock implements TradeSearchRepository {}

void main() {
  late SearchTrades useCase;
  late MockTradeSearchRepository repo;
  const filter = TradeSearchFilter(originLat: -33.8, originLng: 151.2);

  setUpAll(() => registerFallbackValue(const TradeSearchFilter()));
  setUp(() {
    repo = MockTradeSearchRepository();
    useCase = SearchTrades(repo);
  });

  const result = TradeSearchResult(
    trade: TradeProfile(id: 't1', fullName: 'Bob', primaryTrade: 'electrician'),
    distanceKm: 2.5,
  );

  test('forwards filter/limit/offset and returns results', () async {
    when(() => repo.searchTrades(filter: filter, limit: 20, offset: 0))
        .thenAnswer((_) async => const Right([result]));

    final out = await useCase(filter: filter, limit: 20, offset: 0);

    expect(out.isRight(), isTrue);
    out.fold((_) => fail('expected results'), (l) => expect(l.length, 1));
    verify(() => repo.searchTrades(filter: filter, limit: 20, offset: 0))
        .called(1);
  });

  test('propagates ServerFailure', () async {
    when(() => repo.searchTrades(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        )).thenAnswer((_) async => const Left(ServerFailure('boom')));

    final out = await useCase(filter: filter);

    out.fold((f) => expect(f, isA<ServerFailure>()), (_) => fail('expected fail'));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/discovery/search_trades_usecase_test.dart`
Expected: FAIL — `search_trades.dart` use case missing.

- [ ] **Step 3: Write the use case**

```dart
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/trade_search_filter.dart';
import '../entities/trade_search_result.dart';
import '../repositories/trade_search_repository.dart';

class SearchTrades {
  const SearchTrades(this._repository);
  final TradeSearchRepository _repository;

  Future<Either<Failure, List<TradeSearchResult>>> call({
    required TradeSearchFilter filter,
    int? limit,
    int? offset,
  }) => _repository.searchTrades(filter: filter, limit: limit, offset: offset);
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/discovery/search_trades_usecase_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/discovery/domain/usecases/search_trades.dart test/features/discovery/search_trades_usecase_test.dart
git commit -m "feat(discovery): SearchTrades use case"
```

---

## Task 4: Extend TradeProfile entity + model with availability

**Files:**
- Modify: `lib/features/profile/domain/entities/trade_profile.dart`
- Modify: `lib/features/profile/data/models/trade_profile_model.dart`
- Test: `test/features/profile/trade_profile_model_availability_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/data/models/trade_profile_model.dart';

void main() {
  test('fromJson maps is_available + available_from', () {
    final m = TradeProfileModel.fromJson({
      'id': 't1',
      'full_name': 'Bob',
      'primary_trade': 'electrician',
      'is_available': false,
      'available_from': '2026-07-01',
    });
    expect(m.isAvailable, isFalse);
    expect(m.availableFrom, DateTime(2026, 7, 1));
  });

  test('fromJson defaults isAvailable to true when absent', () {
    final m = TradeProfileModel.fromJson({
      'id': 't1', 'full_name': 'Bob', 'primary_trade': 'electrician',
    });
    expect(m.isAvailable, isTrue);
    expect(m.availableFrom, isNull);
  });

  test('toJson emits availability when set', () {
    const m = TradeProfileModel(
      id: 't1', fullName: 'Bob', primaryTrade: 'electrician',
      isAvailable: false,
    );
    expect(m.toJson()['is_available'], isFalse);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/profile/trade_profile_model_availability_test.dart`
Expected: FAIL — `isAvailable`/`availableFrom` undefined.

- [ ] **Step 3: Add fields to the entity**

In `lib/features/profile/domain/entities/trade_profile.dart`, add to the constructor (with defaults) and as fields:
```dart
    this.isAvailable = true,
    this.availableFrom,
```
```dart
  final bool isAvailable;
  // When isAvailable is false, the date the trade becomes free again.
  // Search treats `isAvailable || availableFrom <= today` as available now.
  final DateTime? availableFrom;
```
Place them alongside the other availability-adjacent fields (after `averageRating`/`ratingCount`). Do **not** add them to `props` (props stays `[id, fullName, primaryTrade]`).

- [ ] **Step 4: Map them in the model**

In `lib/features/profile/data/models/trade_profile_model.dart`:
- Add to the constructor: `super.isAvailable,` and `super.availableFrom,`.
- Add to `fromJson`:
```dart
        isAvailable: json['is_available'] as bool? ?? true,
        availableFrom: json['available_from'] != null
            ? DateTime.parse(json['available_from'] as String)
            : null,
```
- Add to `toJson` (conditional emit, mirroring the post-MapTiler block so writes don't fail pre-migration):
```dart
    'is_available': isAvailable,
    if (availableFrom != null)
      'available_from': availableFrom!.toIso8601String().substring(0, 10),
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/features/profile/trade_profile_model_availability_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/profile/domain/entities/trade_profile.dart lib/features/profile/data/models/trade_profile_model.dart test/features/profile/trade_profile_model_availability_test.dart
git commit -m "feat(profile): add is_available/available_from to TradeProfile"
```

---

## Task 5: Data — remote datasource (RPC call)

**Files:**
- Create: `lib/features/discovery/data/datasources/trade_search_remote_datasource.dart`

No unit test (thin Supabase boundary, exercised via the repo test in Task 6 and integration — mirrors `job_remote_datasource.dart` which has no direct test).

- [ ] **Step 1: Write the datasource**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../profile/data/models/trade_profile_model.dart';
import '../../domain/entities/trade_search_filter.dart';
import '../../domain/entities/trade_search_result.dart';

abstract interface class TradeSearchRemoteDataSource {
  Future<List<TradeSearchResult>> searchTrades({
    required TradeSearchFilter filter,
    int? limit,
    int? offset,
  });
}

class TradeSearchRemoteDataSourceImpl implements TradeSearchRemoteDataSource {
  const TradeSearchRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<List<TradeSearchResult>> searchTrades({
    required TradeSearchFilter filter,
    int? limit,
    int? offset,
  }) async {
    try {
      final q = filter.query?.trim();
      final data = await _client.rpc(
        'search_trades',
        params: {
          'p_lat': filter.originLat,
          'p_lng': filter.originLng,
          'p_radius_km': filter.radiusKm,
          'p_min_rating': filter.minRating,
          'p_available_only': filter.availableOnly,
          'p_query': (q == null || q.isEmpty) ? null : q,
          'p_limit': limit ?? 1000,
          'p_offset': offset ?? 0,
        },
      ) as List<dynamic>;

      return data.map((e) {
        final row = e as Map<String, dynamic>;
        return TradeSearchResult(
          trade: TradeProfileModel.fromJson(row),
          distanceKm: (row['distance_km'] as num).toDouble(),
        );
      }).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/discovery/data/datasources/trade_search_remote_datasource.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/discovery/data/datasources/trade_search_remote_datasource.dart
git commit -m "feat(discovery): search_trades RPC datasource"
```

---

## Task 6: Data — repository impl (+ test)

**Files:**
- Create: `lib/features/discovery/data/repositories/trade_search_repository_impl.dart`
- Test: `test/features/discovery/trade_search_repository_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/exceptions.dart';
import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/discovery/data/datasources/trade_search_remote_datasource.dart';
import 'package:jobdun/features/discovery/data/repositories/trade_search_repository_impl.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_filter.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_result.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';

class MockDs extends Mock implements TradeSearchRemoteDataSource {}

void main() {
  late TradeSearchRepositoryImpl repo;
  late MockDs ds;
  const filter = TradeSearchFilter(originLat: -33.8, originLng: 151.2);
  const hit = TradeSearchResult(
    trade: TradeProfile(id: 't1', fullName: 'Bob', primaryTrade: 'electrician'),
    distanceKm: 2.5,
  );

  setUpAll(() => registerFallbackValue(const TradeSearchFilter()));
  setUp(() {
    ds = MockDs();
    repo = TradeSearchRepositoryImpl(ds);
  });

  test('returns Right(results) on success', () async {
    when(() => ds.searchTrades(filter: filter, limit: 20, offset: 0))
        .thenAnswer((_) async => const [hit]);

    final out = await repo.searchTrades(filter: filter, limit: 20, offset: 0);

    out.fold((_) => fail('expected results'), (l) => expect(l.single, hit));
  });

  test('maps ServerException to Left(ServerFailure)', () async {
    when(() => ds.searchTrades(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        )).thenThrow(const ServerException('rpc failed'));

    final out = await repo.searchTrades(filter: filter);

    out.fold((f) => expect(f, isA<ServerFailure>()), (_) => fail('expected fail'));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/discovery/trade_search_repository_test.dart`
Expected: FAIL — `trade_search_repository_impl.dart` missing.

- [ ] **Step 3: Write the repository impl**

```dart
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/trade_search_filter.dart';
import '../../domain/entities/trade_search_result.dart';
import '../../domain/repositories/trade_search_repository.dart';
import '../datasources/trade_search_remote_datasource.dart';

class TradeSearchRepositoryImpl implements TradeSearchRepository {
  const TradeSearchRepositoryImpl(this._datasource);
  final TradeSearchRemoteDataSource _datasource;

  @override
  Future<Either<Failure, List<TradeSearchResult>>> searchTrades({
    required TradeSearchFilter filter,
    int? limit,
    int? offset,
  }) async {
    try {
      return right(
        await _datasource.searchTrades(
          filter: filter,
          limit: limit,
          offset: offset,
        ),
      );
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/discovery/trade_search_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/discovery/data/repositories/trade_search_repository_impl.dart test/features/discovery/trade_search_repository_test.dart
git commit -m "feat(discovery): trade-search repository impl"
```

---

## Task 7: Presentation — providers, controller, state (+ test)

**Files:**
- Create: `lib/features/discovery/presentation/providers/discovery_provider.dart`
- Test: `test/features/discovery/trade_search_controller_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_filter.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_result.dart';
import 'package:jobdun/features/discovery/domain/repositories/trade_search_repository.dart';
import 'package:jobdun/features/discovery/presentation/providers/discovery_provider.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';

class MockRepo extends Mock implements TradeSearchRepository {}

TradeSearchResult _hit(String id, double d) => TradeSearchResult(
  trade: TradeProfile(id: id, fullName: 'T$id', primaryTrade: 'electrician'),
  distanceKm: d,
);

void main() {
  late MockRepo repo;
  setUpAll(() => registerFallbackValue(const TradeSearchFilter()));
  setUp(() => repo = MockRepo());

  ProviderContainer makeContainer() {
    final c = ProviderContainer(overrides: [
      tradeSearchRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWith((ref) => Stream.value('builder-1')),
      currentUserIdSyncProvider.overrideWithValue('builder-1'),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('loadFeed populates results from the repo', () async {
    when(() => repo.searchTrades(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        )).thenAnswer((_) async => Right([_hit('a', 1), _hit('b', 2)]));

    final c = makeContainer();
    await c.read(tradeSearchControllerProvider.notifier).loadFeed();

    expect(c.read(tradeSearchControllerProvider).results.length, 2);
  });

  test('updateFilter stores the new filter and reloads', () async {
    when(() => repo.searchTrades(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        )).thenAnswer((_) async => const Right([]));

    final c = makeContainer();
    await c.read(tradeSearchControllerProvider.notifier)
        .updateFilter(const TradeSearchFilter(radiusKm: 10, availableOnly: true));

    final s = c.read(tradeSearchControllerProvider);
    expect(s.filter.radiusKm, 10);
    expect(s.filter.availableOnly, isTrue);
  });

  test('error from repo lands on state.error', () async {
    when(() => repo.searchTrades(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        )).thenAnswer((_) async => const Left(ServerFailure('boom')));

    final c = makeContainer();
    await c.read(tradeSearchControllerProvider.notifier).loadFeed();

    expect(c.read(tradeSearchControllerProvider).error, isNotNull);
  });
}
```
(Add `import 'package:jobdun/core/errors/failures.dart';` for `ServerFailure`.)

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/discovery/trade_search_controller_test.dart`
Expected: FAIL — `discovery_provider.dart` missing.

- [ ] **Step 3: Write the providers + controller + state**

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../data/datasources/trade_search_remote_datasource.dart';
import '../../data/repositories/trade_search_repository_impl.dart';
import '../../domain/entities/trade_search_filter.dart';
import '../../domain/entities/trade_search_result.dart';
import '../../domain/repositories/trade_search_repository.dart';
import '../../domain/usecases/search_trades.dart';

// ── Data layer providers (public so tests can override) ──────────────────────
final tradeSearchDatasourceProvider = Provider<TradeSearchRemoteDataSource>(
  (ref) => TradeSearchRemoteDataSourceImpl(SupabaseConfig.client),
);

final tradeSearchRepositoryProvider = Provider<TradeSearchRepository>(
  (ref) => TradeSearchRepositoryImpl(ref.read(tradeSearchDatasourceProvider)),
);

final searchTradesUseCaseProvider = Provider(
  (ref) => SearchTrades(ref.read(tradeSearchRepositoryProvider)),
);

// ── Controller ───────────────────────────────────────────────────────────────
final tradeSearchControllerProvider =
    NotifierProvider<TradeSearchController, TradeSearchState>(
  TradeSearchController.new,
);

/// Owns the trade directory. Mirrors JobsController: one source of truth feeds
/// both the home mini-list (`state.results.take(3)`) and the full discovery
/// page (`pagingController` via PagedListView).
class TradeSearchController extends Notifier<TradeSearchState> {
  late SearchTrades _search;
  PagingController<int, TradeSearchResult>? _pagingController;

  static const _pageSize = 20;

  PagingController<int, TradeSearchResult> get pagingController {
    final existing = _pagingController;
    if (existing != null) return existing;
    final controller = PagingController<int, TradeSearchResult>(firstPageKey: 0);
    controller.addPageRequestListener(_fetchPage);
    _pagingController = controller;
    return controller;
  }

  @override
  TradeSearchState build() {
    _search = ref.read(searchTradesUseCaseProvider);

    ref.listen(currentUserIdProvider, (previous, next) {
      if (next.value == null ||
          (previous?.value != null && previous?.value != next.value)) {
        state = const TradeSearchState();
        _pagingController?.refresh();
      }
    });

    ref.onDispose(() => _pagingController?.dispose());
    return const TradeSearchState();
  }

  Future<void> _fetchPage(int pageKey) async {
    final result = await _search(
      filter: state.filter,
      limit: _pageSize,
      offset: pageKey * _pageSize,
    );
    result.fold((f) => _pagingController?.error = f.message, (hits) {
      if (pageKey == 0) state = state.copyWith(isLoading: false, results: hits);
      final isLast = hits.length < _pageSize;
      if (isLast) {
        _pagingController?.appendLastPage(hits);
      } else {
        _pagingController?.appendPage(hits, pageKey + 1);
      }
    });
  }

  /// One-shot first page (home mini-list) or refresh of the paged page.
  Future<void> loadFeed() async {
    final paging = _pagingController;
    if (paging != null) {
      paging.refresh();
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    final result = await _search(filter: state.filter, limit: _pageSize);
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (hits) => state = state.copyWith(isLoading: false, results: hits),
    );
  }

  Future<void> updateFilter(TradeSearchFilter filter) async {
    state = state.copyWith(filter: filter);
    await loadFeed();
  }

  Future<void> setOrigin(double lat, double lng) =>
      updateFilter(state.filter.copyWith(originLat: lat, originLng: lng));

  Future<void> refresh() => loadFeed();
}

class TradeSearchState {
  const TradeSearchState({
    this.results = const [],
    this.filter = const TradeSearchFilter(),
    this.isLoading = false,
    this.error,
  });

  final List<TradeSearchResult> results;
  final TradeSearchFilter filter;
  final bool isLoading;
  final String? error;

  TradeSearchState copyWith({
    List<TradeSearchResult>? results,
    TradeSearchFilter? filter,
    bool? isLoading,
    String? error,
  }) => TradeSearchState(
    results: results ?? this.results,
    filter: filter ?? this.filter,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/discovery/trade_search_controller_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/discovery/presentation/providers/discovery_provider.dart test/features/discovery/trade_search_controller_test.dart
git commit -m "feat(discovery): TradeSearchController + state + providers"
```

---

## Task 8: UI — discovery tradie tile (maps result → TradieCard)

**Files:**
- Create: `lib/features/discovery/presentation/widgets/discovery_tradie_tile.dart`

`TradieCard` already exposes `name, trade, suburb, rating, jobCount, isVerified, isAvailable, distanceKm, initials, onTap`. This tile adapts a `TradeSearchResult` to it.

- [ ] **Step 1: Write the tile**

```dart
import 'package:flutter/material.dart';

import '../../../../core/design/widgets/tradie_card.dart';
import '../../domain/entities/trade_search_result.dart';

class DiscoveryTradieTile extends StatelessWidget {
  const DiscoveryTradieTile({super.key, required this.result, this.onTap});

  final TradeSearchResult result;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = result.trade;
    return TradieCard(
      name: t.fullName,
      trade: t.displayTrade,
      suburb: t.baseSuburb ?? t.baseState ?? '',
      rating: t.averageRating ?? 0,
      jobCount: t.jobsCompleted,
      isVerified: t.isVerified,
      isAvailable:
          t.isAvailable ||
          (t.availableFrom != null &&
              !t.availableFrom!.isAfter(DateTime.now())),
      distanceKm: result.distanceKm,
      initials: _initials(t.fullName),
      onTap: onTap,
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/discovery/presentation/widgets/discovery_tradie_tile.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/discovery/presentation/widgets/discovery_tradie_tile.dart
git commit -m "feat(discovery): tradie result tile"
```

---

## Task 9: UI — filter sheet

**Files:**
- Create: `lib/features/discovery/presentation/widgets/trade_filter_sheet.dart`

> **At execution:** open `lib/core/design/widgets/j_bottom_sheet.dart` (for `showJSheet`'s signature), `j_switch.dart` (toggle API), and an existing sheet that uses `showJSheet` (e.g. under `lib/features/jobs/`) to match the construction pattern and button widgets (`JButton`). Build the sheet with a radius control, a min-rating control, an `ONLY SHOW AVAILABLE` `JSwitch`, a query field, and `SHOW TRADIES` / `CLEAR` actions. It returns a `TradeSearchFilter` (or calls back) that the page passes to `controller.updateFilter`.

Copy (from spec §5.1): title `FILTERS`, `DISTANCE` (value `Within 25 km`), `MINIMUM RATING`, `ONLY SHOW AVAILABLE`, apply `SHOW TRADIES`, `CLEAR`. AU spelling, ALL-CAPS buttons.

- [ ] **Step 1: Build the sheet widget** (single public `StatefulWidget`; seed controls from the passed-in current filter; on apply, pop with the new `TradeSearchFilter`). Keep ≤ 400 LOC.

- [ ] **Step 2:** `flutter analyze lib/features/discovery/presentation/widgets/trade_filter_sheet.dart` → no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/discovery/presentation/widgets/trade_filter_sheet.dart
git commit -m "feat(discovery): trade filter sheet"
```

---

## Task 10: UI — discovery page (PagedListView)

**Files:**
- Create: `lib/features/discovery/presentation/pages/discovery_page.dart`

> **At execution:** open `lib/features/jobs/presentation/pages/jobs_page.dart` and copy its `PagedListView` + `JSkeletonList` first-page + empty + tap-to-retry error + `RefreshIndicator` wiring, swapping `JobsController`→`TradeSearchController`, `JobCard`→`DiscoveryTradieTile`. Also open `lib/core/design/widgets/empty_state.dart` and `j_skeleton_list.dart` for their constructors.

Requirements:
- `ConsumerStatefulWidget`. In `initState`, resolve origin and seed it, then load: `Future.microtask(() => _resolveOriginThenLoad())`. Origin order: builder `service_latitude/service_longitude` (from the profile provider) → if null, device geolocation (reuse the `geolocator` call pattern from `home_map_view.dart`). Set via `controller.setOrigin(lat, lng)` (which reloads).
- Body: `RefreshIndicator(onRefresh: () async => controller.pagingController.refresh())` wrapping a `PagedListView<int, TradeSearchResult>` reading `controller.pagingController`, item builder → `DiscoveryTradieTile(result: ...)`.
- `firstPageProgressIndicatorBuilder` → `JSkeletonList`; `noItemsFoundIndicatorBuilder` → empty state (headline `NO TRADIES MATCH`, sub `Try a wider radius or fewer filters.`, CTA `CLEAR FILTERS` → resets filter keeping origin); `firstPageErrorIndicatorBuilder` → tap-to-retry (`Couldn't load tradies. Tap to try again.`).
- AppBar title `FIND A TRADIE`; a filter action (`AppIcons`) opens `trade_filter_sheet.dart` via `showJSheet`; on return, `controller.updateFilter(returned)`.
- Page file ≤ 400 LOC — split private widgets into `discovery_page_widgets.dart` if needed.

- [ ] **Step 1:** Build the page per the above.
- [ ] **Step 2:** `flutter analyze lib/features/discovery/presentation/pages/` → no errors.
- [ ] **Step 3: Commit**

```bash
git add lib/features/discovery/presentation/pages/
git commit -m "feat(discovery): full search page with pagination"
```

---

## Task 11: Routing — add /discovery

**Files:**
- Modify: `lib/app/router/app_router.dart`

> **At execution:** open `lib/app/router/app_router.dart`, find the `GoRoute` list (e.g. the `/jobs` route), and add a sibling route mirroring its style:

```dart
GoRoute(
  path: '/discovery',
  builder: (context, state) => const DiscoveryPage(),
),
```
Add `import '../../features/discovery/presentation/pages/discovery_page.dart';` at the top with the other feature-page imports.

- [ ] **Step 1:** Add the route + import.
- [ ] **Step 2:** `flutter analyze lib/app/router/app_router.dart` → no errors.
- [ ] **Step 3: Commit**

```bash
git add lib/app/router/app_router.dart
git commit -m "feat(discovery): /discovery route"
```

---

## Task 12: UI — home "TRADIES NEAR YOU" builder section

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart`

Currently (around line 342-383) only the **trade** role gets a list section ("Latest jobs"); the **builder** gets stats + post-a-job card only, with a comment that the tradie list is hidden until a search backend exists. That backend now exists.

> **At execution:** open `home_page.dart`. The widget is a `Consumer*` so it can `ref.watch(tradeSearchControllerProvider)`. Add a builder-only sliver section after the `_PrimaryActionCard` (sibling to the `if (!isBuilder) ...[ Latest jobs ]` block), using the same `SliverToBoxAdapter` header + `JStaggeredSliverList`/skeleton/empty structure already in the file.

Behaviour:
- On first build for a builder, trigger a one-shot load. Resolve origin from `profileState.builderProfile?.serviceLatitude/serviceLongitude` if available; otherwise device geo (same as discovery page). Use the existing `build()`-time microtask / existing load-trigger pattern in this file — do **not** add a new `addPostFrameCallback`.
- Header: `Text('TRADIES NEAR YOU', style: tt.titleLarge!.copyWith(color: c.text1))` (mirror the existing 'Latest jobs' header padding).
- Source: `final tradies = ref.watch(tradeSearchControllerProvider).results.take(3).toList();`
- If `tradies.isNotEmpty`: a `JStaggeredSliverList` of `DiscoveryTradieTile(result: tradies[i], onTap: () => context.push('/discovery'))` plus a trailing `SEE ALL` text-button row → `context.push('/discovery')`.
- Else if loading: `JSkeletonList` (sliver-wrapped as the file does for jobs).
- Else: a compact empty state (headline `NO TRADIES NEARBY`, sub `Widen your search radius.`, CTA `WIDEN SEARCH` → `context.push('/discovery')`) — reuse `empty_state.dart` or mirror `_HomeJobsEmpty`.

- [ ] **Step 1:** Add the builder section + import `DiscoveryTradieTile` and the discovery provider.
- [ ] **Step 2:** `flutter analyze lib/features/home/presentation/pages/home_page.dart` → no errors. Keep the file under its current budget; if it crosses 400 LOC, extract the new section into `home_page_widgets` per the existing split convention.
- [ ] **Step 3: Commit**

```bash
git add lib/features/home/presentation/pages/
git commit -m "feat(home): TRADIES NEAR YOU live section for builders"
```

---

## Task 13: UI — trade availability controls in profile-edit

**Files:**
- Modify: `lib/features/profile/presentation/pages/profile_edit_form_fields.dart`
- Possibly modify: the trade profile controller that builds the `TradeProfileModel` for `upsertTradeProfile` (find via `grep -rn "upsertTradeProfile\|TradeProfileModel(" lib/features/profile/presentation`).

> **At execution:** open `profile_edit_form_fields.dart` and the trade-profile edit controller. The model already round-trips `is_available`/`available_from` (Task 4). Add, in the trade-only section of the edit form:
> - an `OPEN FOR WORK` `JSwitch` bound to `isAvailable` (helper `Show up in builders' searches.`),
> - an optional `AVAILABLE FROM` date picker bound to `availableFrom`, shown when the switch is off (helper `Leave blank if you're ready now.`).
> Wire both into the existing edit state so they flow into the `TradeProfileModel` passed to `upsertTradeProfile`. Use `AppIcons`, `Gap`, theme roles — no raw colours/sizedbox.

- [ ] **Step 1:** Add the two controls + wire to the upsert payload.
- [ ] **Step 2:** `flutter analyze lib/features/profile/` → no errors.
- [ ] **Step 3:** Manual check (or existing profile test) that toggling persists. Add an assertion to an existing profile edit test if one covers the upsert payload.
- [ ] **Step 4: Commit**

```bash
git add lib/features/profile/
git commit -m "feat(profile): trade availability controls in profile edit"
```

---

## Task 14: Golden — discovery tradie tile

**Files:**
- Test: `test/golden/discovery_tradie_tile_test.dart`

> **At execution:** open `test/golden/_harness.dart` and an existing golden (e.g. `test/golden/j_card_test.dart`) to match the harness/pump + `expectLater(..., matchesGoldenFile(...))` convention and screenutil setup.

- [ ] **Step 1:** Write a golden pumping `DiscoveryTradieTile` with a representative `TradeSearchResult` (available, rating 4.8, 2.3 km) inside the standard golden harness.
- [ ] **Step 2:** Run: `flutter test --update-goldens test/golden/discovery_tradie_tile_test.dart` then `flutter test test/golden/discovery_tradie_tile_test.dart` → PASS.
- [ ] **Step 3: Commit**

```bash
git add test/golden/discovery_tradie_tile_test.dart test/golden/
git commit -m "test(discovery): golden for tradie result tile"
```

---

## Task 15: Final gate + audit scorecard update

**Files:**
- Modify: `docs/STAGE1_CLIENT_REQUIREMENTS_AUDIT.md`

- [ ] **Step 1: Run the architecture audit**

Run: `bash scripts/check-architecture.sh`
Expected: all 7 checks pass (discovery follows the layer rules — `presentation/` imports `domain/` only; the provider file is the lone `data/` seam; `domain/` is Flutter/Supabase-free).

- [ ] **Step 2: Run full validation**

Run: `bash scripts/validate.sh`
Expected: design-system grep checks, `dart format`, `flutter analyze`, and `flutter test` all green. Fix any design-token violations (Gap/screenutil/AppIcons/theme) the grep flags in the new files.

- [ ] **Step 3: Update the scorecard**

In `docs/STAGE1_CLIENT_REQUIREMENTS_AUDIT.md`: flip #9 ❌→✅; update #13's note to "availability filter shipped; full weekly calendar still deferred"; add a note under #10 that the crew-map fast-follow is next. Update the tally line.

- [ ] **Step 4: Commit**

```bash
git add docs/STAGE1_CLIENT_REQUIREMENTS_AUDIT.md
git commit -m "docs(audit): #9 trade search done; #13 availability filter shipped"
```

---

## Self-review notes (author)

- **Spec coverage:** DB columns+RPC+rating (Task 1) ✓; entities/usecase/repo/datasource/controller (2,3,5,6,7) ✓; model extension (4) ✓; home mini-list (12) ✓; discovery page+filter (9,10) ✓; availability controls (13) ✓; routing (11) ✓; copy §5.1 used in 9/10/12/13 ✓; tests (2,3,4,6,7,14) ✓; gate (15) ✓. Out-of-scope items (map #10, calendar #13-full, PostGIS) correctly excluded.
- **Type consistency:** `TradeSearchFilter` / `TradeSearchResult` / `searchTrades({filter,limit,offset})` / `tradeSearchRepositoryProvider` / `tradeSearchControllerProvider` / `loadFeed` / `updateFilter` / `setOrigin` are used identically across tasks 2–12. RPC return columns match `TradeProfileModel.fromJson` keys.
- **Known integration risks (resolve at execution by reading the named file):** exact `showJSheet`/`JSwitch`/`empty_state`/`JSkeletonList` constructors (tasks 9,10,12); the home load-trigger pattern and whether the home widget is already `Consumer` (task 12); the trade-edit controller's upsert path (task 13); `app_router.dart` route style (task 11). These are UI-wiring details, not design decisions.
