# Profile Edit Quick-Edit Sheets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 600-line edit-profile form with per-section quick-edit bottom sheets launched from the existing hub, backed by partial (patch) saves that only write the touched columns.

**Architecture:** Domain patch entities use fpdart `Option<T>` (`none` = column untouched, `some(v)` = write, `some(null)` = clear). Pure mapper functions in the data layer turn patches into Supabase column maps (`update` for `profiles`, partial `upsert` for `trade_profiles`/`builder_profiles`). One new controller method `savePatches` routes through three thin use cases, then refreshes only the patched table via the existing repo getters (house pattern from `setTradeAvailability`). Sheets are `ConsumerStatefulWidget`s on a shared `EditSheetScaffold` with dirty-guard via `PopScope`.

**Tech Stack:** Flutter, Riverpod 3 `Notifier`, fpdart, flutter_form_builder, mocktail, modal_bottom_sheet (via `showJSheet`).

**Spec:** `docs/superpowers/specs/2026-06-11-profile-edit-quick-sheets-design.md`

**Read first:** `CLAUDE.md` → Engineering Standards (file budget ≤400 LOC, layer rules, widget rules), `design-system/jobdun/MASTER.md`, `design-system/jobdun/pages/profile-dashboard.md`.

**Plan-level decisions (amendments to spec, already reflected there):**
- `crew_size` and `service_radius_km` are NOT in any sheet — the old form never edited them (YAGNI).
- Availability (`is_available` + `available_from`) moves into the **Trade & experience sheet** (it lived in the old form's trade section; losing it would orphan `available_from`).
- Post-save state refresh = targeted repo getter + `state.copyWith(...)`, not entity copyWith (entities have no copyWith).
- `ProfileController` temporarily hits 11 public methods; Task 12 deletes `saveProfile`, returning it to 10.

---

### Task 1: Patch entities + column mappers (the null-wipe fix)

**Files:**
- Create: `lib/features/profile/domain/entities/profile_patches.dart`
- Create: `lib/features/profile/data/models/profile_patch_mappers.dart`
- Test: `test/features/profile/profile_patch_mappers_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/features/profile/data/models/profile_patch_mappers.dart';
import 'package:jobdun/features/profile/domain/entities/profile_patches.dart';

void main() {
  group('tradeProfilePatchColumns', () {
    test('omits untouched fields entirely (null-wipe regression)', () {
      const patch = TradeProfilePatch(
        hourlyRateMin: Some(55.0),
        hourlyRateMax: Some(95.0),
        hourlyRateVisible: Some(true),
      );
      final map = tradeProfilePatchColumns(patch);
      expect(map, {
        'hourly_rate_min': 55.0,
        'hourly_rate_max': 95.0,
        'hourly_rate_visible': true,
      });
      // The dangerous bug: untouched columns must be ABSENT, not null.
      expect(map.containsKey('about'), isFalse);
      expect(map.containsKey('base_suburb'), isFalse);
      expect(map.containsKey('full_name'), isFalse);
    });

    test('some(null) clears a nullable column', () {
      const patch = TradeProfilePatch(basePostcode: Some(null));
      expect(tradeProfilePatchColumns(patch), {'base_postcode': null});
    });

    test('availableFrom serialises to ISO-8601, none stays absent', () {
      final patch = TradeProfilePatch(
        isAvailable: const Some(false),
        availableFrom: Some(DateTime.utc(2026, 7, 1)),
      );
      final map = tradeProfilePatchColumns(patch);
      expect(map['is_available'], false);
      expect(map['available_from'], '2026-07-01T00:00:00.000Z');
    });

    test('isEmpty short-circuits', () {
      expect(const TradeProfilePatch().isEmpty, isTrue);
      expect(const TradeProfilePatch(about: Some('hi')).isEmpty, isFalse);
    });
  });

  group('userProfilePatchColumns', () {
    test('maps displayName only when set', () {
      expect(
        userProfilePatchColumns(const UserProfilePatch(displayName: Some('Ken'))),
        {'display_name': 'Ken'},
      );
      expect(userProfilePatchColumns(const UserProfilePatch()), isEmpty);
    });
  });

  group('builderProfilePatchColumns', () {
    test('maps set fields, omits the rest', () {
      const patch = BuilderProfilePatch(
        companyName: Some('Pinnacle Construct'),
        website: Some(null),
      );
      expect(builderProfilePatchColumns(patch), {
        'company_name': 'Pinnacle Construct',
        'website': null,
      });
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/profile/profile_patch_mappers_test.dart`
Expected: FAIL — `profile_patches.dart` / `profile_patch_mappers.dart` don't exist.

- [ ] **Step 3: Write the patch entities (domain — fpdart only, no Flutter/Supabase imports)**

`lib/features/profile/domain/entities/profile_patches.dart`:

```dart
import 'package:fpdart/fpdart.dart';

/// Partial-update payloads for the three profile tables. Semantics:
/// `None` = leave the column untouched (absent from the write payload),
/// `Some(v)` = write v, `Some(null)` = clear a nullable column.
///
/// This is the fix for the null-wipe hazard: the legacy full-row save
/// (`update(profile.toJson())`) nulled every column it wasn't handed.
class UserProfilePatch {
  const UserProfilePatch({this.displayName = const None()});

  final Option<String> displayName;

  bool get isEmpty => displayName.isNone();
}

class TradeProfilePatch {
  const TradeProfilePatch({
    this.fullName = const None(),
    this.primaryTrade = const None(),
    this.tradeOther = const None(),
    this.yearsExperience = const None(),
    this.hourlyRateMin = const None(),
    this.hourlyRateMax = const None(),
    this.hourlyRateVisible = const None(),
    this.isAvailable = const None(),
    this.availableFrom = const None(),
    this.baseSuburb = const None(),
    this.baseState = const None(),
    this.basePostcode = const None(),
    this.baseFormattedAddress = const None(),
    this.basePlaceId = const None(),
    this.baseLatitude = const None(),
    this.baseLongitude = const None(),
    this.about = const None(),
  });

  final Option<String> fullName;
  final Option<String> primaryTrade;
  final Option<String?> tradeOther;
  final Option<int?> yearsExperience;
  final Option<double?> hourlyRateMin;
  final Option<double?> hourlyRateMax;
  final Option<bool> hourlyRateVisible;
  final Option<bool> isAvailable;
  final Option<DateTime?> availableFrom;
  final Option<String?> baseSuburb;
  final Option<String?> baseState;
  final Option<String?> basePostcode;
  final Option<String?> baseFormattedAddress;
  final Option<String?> basePlaceId;
  final Option<double?> baseLatitude;
  final Option<double?> baseLongitude;
  final Option<String?> about;

  bool get isEmpty =>
      fullName.isNone() &&
      primaryTrade.isNone() &&
      tradeOther.isNone() &&
      yearsExperience.isNone() &&
      hourlyRateMin.isNone() &&
      hourlyRateMax.isNone() &&
      hourlyRateVisible.isNone() &&
      isAvailable.isNone() &&
      availableFrom.isNone() &&
      baseSuburb.isNone() &&
      baseState.isNone() &&
      basePostcode.isNone() &&
      baseFormattedAddress.isNone() &&
      basePlaceId.isNone() &&
      baseLatitude.isNone() &&
      baseLongitude.isNone() &&
      about.isNone();
}

class BuilderProfilePatch {
  const BuilderProfilePatch({
    this.companyName = const None(),
    this.abn = const None(),
    this.contactName = const None(),
    this.contactPhone = const None(),
    this.yearsInBusiness = const None(),
    this.website = const None(),
    this.serviceSuburb = const None(),
    this.serviceState = const None(),
    this.servicePostcode = const None(),
    this.serviceFormattedAddress = const None(),
    this.servicePlaceId = const None(),
    this.serviceLatitude = const None(),
    this.serviceLongitude = const None(),
    this.about = const None(),
  });

  final Option<String> companyName;
  final Option<String?> abn;
  final Option<String?> contactName;
  final Option<String?> contactPhone;
  final Option<int?> yearsInBusiness;
  final Option<String?> website;
  final Option<String?> serviceSuburb;
  final Option<String?> serviceState;
  final Option<String?> servicePostcode;
  final Option<String?> serviceFormattedAddress;
  final Option<String?> servicePlaceId;
  final Option<double?> serviceLatitude;
  final Option<double?> serviceLongitude;
  final Option<String?> about;

  bool get isEmpty =>
      companyName.isNone() &&
      abn.isNone() &&
      contactName.isNone() &&
      contactPhone.isNone() &&
      yearsInBusiness.isNone() &&
      website.isNone() &&
      serviceSuburb.isNone() &&
      serviceState.isNone() &&
      servicePostcode.isNone() &&
      serviceFormattedAddress.isNone() &&
      servicePlaceId.isNone() &&
      serviceLatitude.isNone() &&
      serviceLongitude.isNone() &&
      about.isNone();
}
```

- [ ] **Step 4: Write the mappers (data layer)**

`lib/features/profile/data/models/profile_patch_mappers.dart`:

```dart
import 'package:fpdart/fpdart.dart';

import '../../domain/entities/profile_patches.dart';

// Pure patch → Supabase column-map builders. Column names mirror the
// `toJson()` maps of the corresponding *_model.dart files. A column appears
// in the result ONLY when the patch field is Some — this is what makes
// section saves safe (test: profile_patch_mappers_test.dart).

void _put<T>(Map<String, dynamic> map, String column, Option<T> field) {
  field.match(() {}, (v) => map[column] = v);
}

Map<String, dynamic> userProfilePatchColumns(UserProfilePatch p) {
  final map = <String, dynamic>{};
  _put(map, 'display_name', p.displayName);
  return map;
}

Map<String, dynamic> tradeProfilePatchColumns(TradeProfilePatch p) {
  final map = <String, dynamic>{};
  _put(map, 'full_name', p.fullName);
  _put(map, 'primary_trade', p.primaryTrade);
  _put(map, 'trade_other', p.tradeOther);
  _put(map, 'years_experience', p.yearsExperience);
  _put(map, 'hourly_rate_min', p.hourlyRateMin);
  _put(map, 'hourly_rate_max', p.hourlyRateMax);
  _put(map, 'hourly_rate_visible', p.hourlyRateVisible);
  _put(map, 'is_available', p.isAvailable);
  p.availableFrom.match(
    () {},
    (v) => map['available_from'] = v?.toIso8601String(),
  );
  _put(map, 'base_suburb', p.baseSuburb);
  _put(map, 'base_state', p.baseState);
  _put(map, 'base_postcode', p.basePostcode);
  _put(map, 'base_formatted_address', p.baseFormattedAddress);
  _put(map, 'base_place_id', p.basePlaceId);
  _put(map, 'base_latitude', p.baseLatitude);
  _put(map, 'base_longitude', p.baseLongitude);
  _put(map, 'about', p.about);
  return map;
}

Map<String, dynamic> builderProfilePatchColumns(BuilderProfilePatch p) {
  final map = <String, dynamic>{};
  _put(map, 'company_name', p.companyName);
  _put(map, 'abn', p.abn);
  _put(map, 'contact_name', p.contactName);
  _put(map, 'contact_phone', p.contactPhone);
  _put(map, 'years_in_business', p.yearsInBusiness);
  _put(map, 'website', p.website);
  _put(map, 'service_suburb', p.serviceSuburb);
  _put(map, 'service_state', p.serviceState);
  _put(map, 'service_postcode', p.servicePostcode);
  _put(map, 'service_formatted_address', p.serviceFormattedAddress);
  _put(map, 'service_place_id', p.servicePlaceId);
  _put(map, 'service_latitude', p.serviceLatitude);
  _put(map, 'service_longitude', p.serviceLongitude);
  _put(map, 'about', p.about);
  return map;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/profile/profile_patch_mappers_test.dart`
Expected: PASS (4 groups, all green).

- [ ] **Step 6: Commit**

```bash
git add lib/features/profile/domain/entities/profile_patches.dart \
        lib/features/profile/data/models/profile_patch_mappers.dart \
        test/features/profile/profile_patch_mappers_test.dart
git commit -m "feat(profile): patch entities + column mappers for partial saves"
```

---

### Task 2: Datasource + repository patch methods

**Files:**
- Modify: `lib/features/profile/data/datasources/profile_remote_datasource.dart` (interface ~line 15, impl ~line 92)
- Modify: `lib/features/profile/domain/repositories/profile_repository.dart:16` (after `upsertTradeProfile`)
- Modify: `lib/features/profile/data/repositories/profile_repository_impl.dart:130` (after `upsertTradeProfile`)
- Test: `test/features/profile/profile_patch_repository_test.dart`

- [ ] **Step 1: Write the failing repo test (mocktail datasource)**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/core/cache/cache_store.dart';
import 'package:jobdun/core/errors/exceptions.dart';
import 'package:jobdun/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:jobdun/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:jobdun/features/profile/domain/entities/profile_patches.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements ProfileRemoteDataSource {}

class _MockCache extends Mock implements CacheStore {}

void main() {
  late _MockDatasource ds;
  late ProfileRepositoryImpl repo;

  setUp(() {
    ds = _MockDatasource();
    repo = ProfileRepositoryImpl(ds, _MockCache());
  });

  test('patchTradeProfile forwards userId + patch and returns right', () async {
    const patch = TradeProfilePatch(about: Some('Brickie, 10 yrs'));
    when(() => ds.patchTradeProfile('u1', patch)).thenAnswer((_) async {});
    final r = await repo.patchTradeProfile('u1', patch);
    expect(r.isRight(), isTrue);
    verify(() => ds.patchTradeProfile('u1', patch)).called(1);
  });

  test('patchUserProfile maps ServerException to ServerFailure', () async {
    const patch = UserProfilePatch(displayName: Some('Ken'));
    when(() => ds.patchUserProfile('u1', patch))
        .thenThrow(const ServerException('boom'));
    final r = await repo.patchUserProfile('u1', patch);
    expect(r.isLeft(), isTrue);
  });

  test('empty patch short-circuits without a network call', () async {
    final r = await repo.patchBuilderProfile('u1', const BuilderProfilePatch());
    expect(r.isRight(), isTrue);
    verifyNever(() => ds.patchBuilderProfile(any(), any()));
  });
}
```

If `verifyNever(... any())` needs a fallback value, add in `setUpAll`:
`registerFallbackValue(const BuilderProfilePatch());`

Check `ServerException`'s constructor in `lib/core/errors/exceptions.dart` — if it isn't `const`/positional-message, match the existing usage found in `profile_remote_datasource_test.dart`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/profile/profile_patch_repository_test.dart`
Expected: FAIL — methods don't exist.

- [ ] **Step 3: Add datasource interface methods + impl**

Interface (next to the other update methods, ~line 15):

```dart
  Future<void> patchUserProfile(String userId, UserProfilePatch patch);
  Future<void> patchTradeProfile(String userId, TradeProfilePatch patch);
  Future<void> patchBuilderProfile(String userId, BuilderProfilePatch patch);
```

Impl (mirror the try/catch → `ServerException` style of `updateProfile` at line 92):

```dart
  @override
  Future<void> patchUserProfile(String userId, UserProfilePatch patch) async {
    try {
      await _client
          .from('profiles')
          .update(userProfilePatchColumns(patch))
          .eq('id', userId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  // trade_profiles / builder_profiles rows are keyed by id = auth user id and
  // created at onboarding. Partial upsert (PostgREST merge-duplicates) only
  // touches the supplied columns on existing rows, and tolerates the
  // first-write case for fresh accounts.
  @override
  Future<void> patchTradeProfile(String userId, TradeProfilePatch patch) async {
    try {
      await _client
          .from('trade_profiles')
          .upsert({'id': userId, ...tradeProfilePatchColumns(patch)});
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> patchBuilderProfile(
    String userId,
    BuilderProfilePatch patch,
  ) async {
    try {
      await _client
          .from('builder_profiles')
          .upsert({'id': userId, ...builderProfilePatchColumns(patch)});
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
```

Match the EXACT exception-wrapping style already used in this file (read the existing `updateProfile` body first and copy its catch shape). Add imports for `profile_patches.dart` and `profile_patch_mappers.dart`.

- [ ] **Step 4: Add repo contract + impl methods**

Contract (`profile_repository.dart`, after `upsertTradeProfile`; import `profile_patches.dart`):

```dart
  // Partial updates — only columns set on the patch are written. Empty
  // patches resolve to success without touching the network.
  Future<Either<Failure, void>> patchUserProfile(
    String userId,
    UserProfilePatch patch,
  );
  Future<Either<Failure, void>> patchTradeProfile(
    String userId,
    TradeProfilePatch patch,
  );
  Future<Either<Failure, void>> patchBuilderProfile(
    String userId,
    BuilderProfilePatch patch,
  );
```

Impl (`profile_repository_impl.dart`, after `upsertTradeProfile` at line 130 — same try/catch shape as its siblings):

```dart
  @override
  Future<Either<Failure, void>> patchUserProfile(
    String userId,
    UserProfilePatch patch,
  ) async {
    if (patch.isEmpty) return right(null);
    try {
      await _datasource.patchUserProfile(userId, patch);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> patchTradeProfile(
    String userId,
    TradeProfilePatch patch,
  ) async {
    if (patch.isEmpty) return right(null);
    try {
      await _datasource.patchTradeProfile(userId, patch);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> patchBuilderProfile(
    String userId,
    BuilderProfilePatch patch,
  ) async {
    if (patch.isEmpty) return right(null);
    try {
      await _datasource.patchBuilderProfile(userId, patch);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/profile/profile_patch_repository_test.dart test/features/profile/profile_remote_datasource_test.dart`
Expected: PASS (new test green, existing datasource test unaffected).

- [ ] **Step 6: Commit**

```bash
git add -A lib/features/profile/data lib/features/profile/domain test/features/profile/profile_patch_repository_test.dart
git commit -m "feat(profile): partial patch methods through datasource + repository"
```

---

### Task 3: Use cases + providers

**Files:**
- Create: `lib/features/profile/domain/usecases/patch_profile_section.dart`
- Modify: `lib/features/profile/presentation/providers/profile_provider.dart:46` (use-case providers block)

- [ ] **Step 1: Write the use cases** (one file, three classes — they form one bounded concern and each is ~6 lines; mirrors `update_profile.dart` style)

```dart
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/profile_patches.dart';
import '../repositories/profile_repository.dart';

class PatchUserProfile {
  const PatchUserProfile(this._repository);
  final ProfileRepository _repository;

  Future<Either<Failure, void>> call(String userId, UserProfilePatch patch) =>
      _repository.patchUserProfile(userId, patch);
}

class PatchTradeProfile {
  const PatchTradeProfile(this._repository);
  final ProfileRepository _repository;

  Future<Either<Failure, void>> call(String userId, TradeProfilePatch patch) =>
      _repository.patchTradeProfile(userId, patch);
}

class PatchBuilderProfile {
  const PatchBuilderProfile(this._repository);
  final ProfileRepository _repository;

  Future<Either<Failure, void>> call(
    String userId,
    BuilderProfilePatch patch,
  ) =>
      _repository.patchBuilderProfile(userId, patch);
}
```

Note: `prefer-single-widget-per-file` applies to widgets, not plain classes; if `dart_code_linter` still complains, split into three files `patch_user_profile.dart` etc.

- [ ] **Step 2: Register providers** in `profile_provider.dart` after `updateProfileUseCaseProvider`:

```dart
final patchUserProfileUseCaseProvider = Provider(
  (ref) => PatchUserProfile(ref.read(profileRepositoryProvider)),
);

final patchTradeProfileUseCaseProvider = Provider(
  (ref) => PatchTradeProfile(ref.read(profileRepositoryProvider)),
);

final patchBuilderProfileUseCaseProvider = Provider(
  (ref) => PatchBuilderProfile(ref.read(profileRepositoryProvider)),
);
```

Add import: `'../../domain/usecases/patch_profile_section.dart'`.

- [ ] **Step 3: Analyze + commit**

Run: `flutter analyze --no-fatal-infos` → no new issues.

```bash
git add lib/features/profile/domain/usecases/patch_profile_section.dart \
        lib/features/profile/presentation/providers/profile_provider.dart
git commit -m "feat(profile): patch use cases + providers"
```

---

### Task 4: Controller `savePatches`

**Files:**
- Modify: `lib/features/profile/presentation/providers/profile_provider.dart` (inside `ProfileController`, after `saveProfile`)
- Test: `test/features/profile/profile_save_patches_test.dart`

- [ ] **Step 1: Write the failing controller test**

Mirror the override style of the existing controller tests (see `test/features/profile/trade_availability_test.dart` for the house pattern of overriding `profileRepositoryProvider` + the current-user provider; copy its setup helper). Core cases:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/profile/domain/entities/profile_patches.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';
import 'package:jobdun/features/profile/domain/repositories/profile_repository.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';
import 'package:mocktail/mocktail.dart';

// + the same currentUserId override import the existing tests use
// (core/providers/current_user_provider.dart).

class _MockRepo extends Mock implements ProfileRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const TradeProfilePatch());
    registerFallbackValue(const UserProfilePatch());
    registerFallbackValue(const BuilderProfilePatch());
  });

  test('savePatches patches trade table then refreshes it', () async {
    final repo = _MockRepo();
    when(() => repo.patchTradeProfile('u1', any()))
        .thenAnswer((_) async => right(null));
    when(() => repo.getTradeProfile('u1')).thenAnswer(
      (_) async => right(
        // Minimal valid TradeProfile — copy the fixture constructor used in
        // trade_availability_test.dart and set about: 'Brickie, 10 yrs'.
        _tradeProfileFixture(about: 'Brickie, 10 yrs'),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        // currentUserIdSyncProvider override → 'u1' (same as house pattern)
      ],
    );
    addTearDown(container.dispose);

    final ok = await container
        .read(profileControllerProvider.notifier)
        .savePatches(trade: const TradeProfilePatch(about: Some('Brickie, 10 yrs')));

    expect(ok, isTrue);
    expect(
      container.read(profileControllerProvider).tradeProfile?.about,
      'Brickie, 10 yrs',
    );
    verify(() => repo.patchTradeProfile('u1', any())).called(1);
    verifyNever(() => repo.getBuilderProfile(any()));
  });

  test('savePatches surfaces failure and returns false', () async {
    final repo = _MockRepo();
    when(() => repo.patchTradeProfile('u1', any()))
        .thenAnswer((_) async => left(const ServerFailure('offline')));

    final container = ProviderContainer(overrides: [/* same as above */]);
    addTearDown(container.dispose);

    final ok = await container
        .read(profileControllerProvider.notifier)
        .savePatches(trade: const TradeProfilePatch(about: Some('x')));

    expect(ok, isFalse);
    expect(container.read(profileControllerProvider).error, contains('offline'));
    verifyNever(() => repo.getTradeProfile(any()));
  });
}
```

Replace the two commented override lines and `_tradeProfileFixture` with the exact helpers from `trade_availability_test.dart` — do not invent new fixture shapes.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/profile/profile_save_patches_test.dart`
Expected: FAIL — `savePatches` undefined.

- [ ] **Step 3: Implement `savePatches`** (in `ProfileController`, after `saveProfile`):

```dart
  /// Section save for the quick-edit sheets: writes only the columns set on
  /// the supplied patches, then refreshes just the touched tables (house
  /// pattern from setTradeAvailability). Sheets own their button spinner;
  /// failures land in state.error like every other mutation here.
  Future<bool> savePatches({
    UserProfilePatch? user,
    TradeProfilePatch? trade,
    BuilderProfilePatch? builder,
  }) async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return false;
    state = state.copyWith(error: null);

    if (user != null) {
      final r = await ref.read(patchUserProfileUseCaseProvider).call(userId, user);
      if (r.isLeft()) {
        state = state.copyWith(error: r.fold((f) => f.message, (_) => null));
        return false;
      }
    }
    if (trade != null) {
      final r = await ref.read(patchTradeProfileUseCaseProvider).call(userId, trade);
      if (r.isLeft()) {
        state = state.copyWith(error: r.fold((f) => f.message, (_) => null));
        return false;
      }
    }
    if (builder != null) {
      final r = await ref
          .read(patchBuilderProfileUseCaseProvider)
          .call(userId, builder);
      if (r.isLeft()) {
        state = state.copyWith(error: r.fold((f) => f.message, (_) => null));
        return false;
      }
    }

    // Targeted refresh — only re-read what we wrote.
    if (user != null) {
      final r = await ref.read(getProfileUseCaseProvider).call(userId);
      r.fold((_) {}, (p) => state = state.copyWith(profile: p));
    }
    if (trade != null) {
      final r = await _repo.getTradeProfile(userId);
      r.fold((_) {}, (tp) => state = state.copyWith(tradeProfile: tp));
    }
    if (builder != null) {
      final r = await _repo.getBuilderProfile(userId);
      r.fold((_) {}, (bp) => state = state.copyWith(builderProfile: bp));
    }
    return true;
  }
```

Add import of `profile_patches.dart` to `profile_provider.dart`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/profile/`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/profile/presentation/providers/profile_provider.dart \
        test/features/profile/profile_save_patches_test.dart
git commit -m "feat(profile): ProfileController.savePatches with targeted refresh"
```

---

### Task 5: Sheet chrome — discard confirm helper + `EditSheetScaffold`

**Files:**
- Create: `lib/features/profile/presentation/widgets/edit_sheets/discard_changes_sheet.dart`
- Create: `lib/features/profile/presentation/widgets/edit_sheets/edit_sheet_scaffold.dart`

- [ ] **Step 1: Extract the discard confirm** (content lifted from `profile_edit_page.dart:333-382`'s `_confirmDiscard`, generalised; the About page reuses it in Task 11):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../../core/design/widgets/j_button.dart';

/// Unsaved-changes confirm. Returns true when the user chose to discard.
Future<bool> showDiscardChangesSheet(BuildContext context) async {
  final discard = await showJSheet<bool>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetCtx) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discard your changes?',
              style: Theme.of(sheetCtx).textTheme.headlineSmall!
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            Gap(8.h),
            Text(
              "You've edited your profile but haven't saved.",
              style: Theme.of(sheetCtx).textTheme.bodyMedium,
            ),
            Gap(16.h),
            SizedBox(
              width: double.infinity,
              child: JButton(
                label: 'KEEP EDITING',
                variant: JButtonVariant.primary,
                onPressed: () => Navigator.of(sheetCtx).pop(false),
              ),
            ),
            Gap(8.h),
            SizedBox(
              width: double.infinity,
              child: JButton(
                label: 'DISCARD CHANGES',
                variant: JButtonVariant.secondary,
                onPressed: () => Navigator.of(sheetCtx).pop(true),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return discard ?? false;
}
```

Use `context.c.card` for the background (import `core/design/colors.dart`) instead of `colorScheme.surface` if that's the house token — check how other sheets in the codebase paint their surface and copy it.

- [ ] **Step 2: Build `EditSheetScaffold`:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/design/widgets/j_button.dart';
import 'discard_changes_sheet.dart';

/// Shared chrome for the quick-edit profile sheets: header (eyebrow + ✕),
/// scrollable body that rides above the keyboard, inline error line, and the
/// all-caps SAVE button. Dirty dismissal (drag-down, barrier tap, system
/// back) is intercepted via PopScope → discard confirm.
class EditSheetScaffold extends StatelessWidget {
  const EditSheetScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.onSave,
    required this.isSaving,
    required this.isDirty,
    this.error,
  });

  final String title;
  final Widget body;
  final VoidCallback onSave;
  final bool isSaving;
  final bool isDirty;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDiscardChangesSheet(context);
        if (discard && context.mounted) Navigator.of(context).pop();
      },
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 14.h, 8.w, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: tt.titleMedium!.copyWith(
                          color: c.text1,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Close',
                      icon: Icon(
                        AppIcons.close,
                        size: AppIconSize.md.r,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 0),
                  child: body,
                ),
              ),
              if (error != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 0),
                  child: Text(
                    error!,
                    style: tt.bodySmall!.copyWith(color: c.urgent),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
                child: SizedBox(
                  width: double.infinity,
                  child: JButton(
                    label: 'SAVE',
                    isLoading: isSaving,
                    onPressed: isSaving ? null : onSave,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Verify `AppIcons.close` exists in `lib/core/theme/app_icons.dart` (grep it); if the token is named differently (e.g. `AppIcons.x`), use the existing name.

⚠️ **Dirty-guard verification:** `modal_bottom_sheet`'s drag-dismiss may bypass `PopScope`. After Task 6's sheet exists, manually verify (or via the Task 6 widget test) that drag-down with edits triggers the confirm. If it doesn't: keep `PopScope` for system back, and additionally pass a `shouldClose`-style guard — `showJSheet` forwards to `showMaterialModalBottomSheet`, so extend `showJSheet` with the package's `ModalBottomSheetRoute`-supported close veto (it consults `RoutePopDisposition` via `willPop`) or open edit sheets with `enableDrag: false, isDismissible: false` once that's confirmed broken. Document whichever lands in the sheet file header.

- [ ] **Step 3: Analyze + commit**

Run: `flutter analyze --no-fatal-infos`

```bash
git add lib/features/profile/presentation/widgets/edit_sheets/
git commit -m "feat(profile): edit-sheet chrome (scaffold + discard confirm)"
```

---

### Task 6: Rates sheet + hub wiring + widget test

**Files:**
- Create: `lib/features/profile/presentation/widgets/edit_sheets/rates_sheet.dart`
- Modify: `lib/features/profile/presentation/pages/profile_edit_hub_page.dart` (row onTap dispatch + rates preview)
- Test: `test/features/profile/rates_sheet_test.dart`

- [ ] **Step 1: Build the sheet.** Move `_RateVisibilityRow` (from `profile_edit_widgets.dart:134`) into this file unchanged as a private widget. Sheet:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';
import 'package:fpdart/fpdart.dart' show Some;

import '../../../../../core/design/colors.dart';
import '../../../../../core/design/widgets/field_label.dart';
import '../../../../../core/widgets/inputs/j_text_field.dart';
import '../../../domain/entities/profile_patches.dart';
import '../../providers/profile_provider.dart';
import 'edit_sheet_scaffold.dart';

/// Quick-edit sheet for hourly rates (tradies). Saves ONLY the three rate
/// columns via TradeProfilePatch — other profile fields are untouchable from
/// here by construction.
class RatesSheet extends ConsumerStatefulWidget {
  const RatesSheet({super.key});

  @override
  ConsumerState<RatesSheet> createState() => _RatesSheetState();
}

class _RatesSheetState extends ConsumerState<RatesSheet> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _dirty = false;
  bool _saving = false;
  String? _error;
  late bool _rateVisible;

  @override
  void initState() {
    super.initState();
    _rateVisible =
        ref.read(profileControllerProvider).tradeProfile?.hourlyRateVisible ??
        true;
  }

  double? _parse(Object? v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : double.tryParse(s);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .savePatches(
          trade: TradeProfilePatch(
            hourlyRateMin: Some(_parse(values['hourly_rate_min'])),
            hourlyRateMax: Some(_parse(values['hourly_rate_max'])),
            hourlyRateVisible: Some(_rateVisible),
          ),
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error =
            ref.read(profileControllerProvider).error ??
            "Couldn't save. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tp = ref.read(profileControllerProvider).tradeProfile;
    return EditSheetScaffold(
      title: 'Rates',
      isDirty: _dirty,
      isSaving: _saving,
      error: _error,
      onSave: _save,
      body: FormBuilder(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: () {
          if (!_dirty) setState(() => _dirty = true);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const FieldLabel('HOURLY RATE (AUD)'),
            Gap(AppSpacing.sm.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: JTextField(
                    name: 'hourly_rate_min',
                    hint: 'Min',
                    initialValue: tp?.hourlyRateMin?.toStringAsFixed(0),
                    keyboardType: TextInputType.number,
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.numeric(errorText: 'Numbers only.'),
                      FormBuilderValidators.min(
                        0,
                        errorText: 'Must be 0 or more.',
                      ),
                    ]),
                  ),
                ),
                Gap(10.w),
                Expanded(
                  child: JTextField(
                    name: 'hourly_rate_max',
                    hint: 'Max',
                    initialValue: tp?.hourlyRateMax?.toStringAsFixed(0),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final max = double.tryParse(v);
                      if (max == null) return 'Numbers only.';
                      if (max < 0) return 'Must be 0 or more.';
                      final minStr = _formKey
                          .currentState
                          ?.fields['hourly_rate_min']
                          ?.value as String?;
                      final min = double.tryParse(minStr ?? '');
                      if (min != null && max < min) return 'Must be ≥ min.';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            Gap(AppSpacing.md.h),
            _RateVisibilityRow(
              value: _rateVisible,
              onChanged: (v) => setState(() {
                _rateVisible = v;
                _dirty = true;
              }),
            ),
            Gap(AppSpacing.sm.h),
          ],
        ),
      ),
    );
  }
}

// _RateVisibilityRow moved verbatim from profile_edit_widgets.dart:134-182.
// (Paste the class here unchanged; it keeps a single caller in this file.)
```

- [ ] **Step 2: Wire the hub.** In `profile_edit_hub_page.dart`, replace the `focus` string on `_HubRowSpec` with a `VoidCallback`-producing dispatch. Change `_HubRowSpec.focus` to `final ProfileSection section;` with `enum ProfileSection { identity, tradeDetails, rates, business, location, about }`, and in `_HubRow.onTap`:

```dart
        onTap: () => switch (spec.section) {
          ProfileSection.rates => showJSheet<bool>(
              context: context,
              builder: (_) => const RatesSheet(),
            ),
          // Other sections keep pushing the form until their sheet task
          // lands, then switch over:
          _ => context.push('/profile/edit/form?focus=${spec.legacyFocus}'),
        },
```

(Keep a `legacyFocus` string on the spec until Task 11 removes the last form push, then delete it.)
Also upgrade the rates preview while here: replace the `rates` local with the design-system format —

```dart
    String rates = '';
    final min = tp?.hourlyRateMin, max = tp?.hourlyRateMax;
    if (min != null && max != null && max != min) {
      rates = '\$${min.toStringAsFixed(0)}–${max.toStringAsFixed(0)}/hr';
    } else if (min != null) {
      rates = '\$${min.toStringAsFixed(0)}/hr';
    }
```

- [ ] **Step 3: Widget test** (`test/features/profile/rates_sheet_test.dart`). Copy the pump harness (ScreenUtil + ProviderScope + MaterialApp wrapper) from an existing widget test in `test/features/profile/` (e.g. `profile_incomplete_banner_test.dart`) — do not hand-roll a new harness. Cases:
  1. enter min 90 / max 55 → tap SAVE → expect text `'Must be ≥ min.'`, and verify mock repo got no patch call.
  2. enter min 55 / max 95 → tap SAVE → verify `patchTradeProfile` called once with a map-producing patch whose `hourlyRateMin` is `Some(55.0)` (capture with mocktail `captureAny`), and the sheet pops.

- [ ] **Step 4: Run tests + manual dirty-guard check**

Run: `flutter test test/features/profile/rates_sheet_test.dart`
Expected: PASS. Then `flutter run`, open hub → Rates, edit, drag down → discard confirm must appear (see Task 5 warning; fix forward if the package bypasses PopScope).

- [ ] **Step 5: Commit**

```bash
git add -A lib/features/profile test/features/profile/rates_sheet_test.dart
git commit -m "feat(profile): rates quick-edit sheet wired from hub"
```

---

### Task 7: Identity & photo sheet

**Files:**
- Create: `lib/features/profile/presentation/widgets/edit_sheets/identity_sheet.dart`
- Modify: `lib/features/profile/presentation/pages/profile_edit_hub_page.dart` (identity row → sheet)

- [ ] **Step 1: Build the sheet.** Same skeleton as `RatesSheet` (form key, dirty, saving, error, `EditSheetScaffold`). Body:
  - `ProfileEditAvatarHeader` (import from `../profile_edit_avatar.dart`) — move the `_pickAvatar` flow from `profile_edit_page.dart:160-218` into this sheet as a private method, including the `_avatarError` + `_avatarCacheGen` locals it needs. The avatar picker sheet stacks on top of this sheet — that's fine (proven pattern).
  - `FieldLabel('DISPLAY NAME')` + `JTextField(name: 'display_name', initialValue: profile?.displayName, validator: required)` (copy from `profile_edit_form_fields.dart:303-312`).
  - Tradie only (`authControllerProvider.select(role) == UserRole.trade`): `FieldLabel('LEGAL NAME')` + `JTextField(name: 'full_name', initialValue: tp?.fullName ?? metadataFullName, validator: required)` (copy from `profile_edit_form_fields.dart:149-158` including the `_metadataFullName` getter from `profile_edit_page.dart:115-120`).
  - Save:

```dart
    final ok = await ref.read(profileControllerProvider.notifier).savePatches(
          user: UserProfilePatch(
            displayName: Some((values['display_name'] as String).trim()),
          ),
          trade: isTrade
              ? TradeProfilePatch(
                  fullName: Some((values['full_name'] as String).trim()),
                )
              : null,
        );
```

  Avatar uploads save instantly through the existing `controller.uploadAvatar` (unchanged behaviour) — avatar changes do NOT set `_dirty` because they're already persisted.

- [ ] **Step 2: Hub wiring** — `ProfileSection.identity => showJSheet<bool>(context: context, builder: (_) => const IdentitySheet())`.

- [ ] **Step 3: Verify + commit**

Run: `flutter analyze --no-fatal-infos && flutter test test/features/profile/`

```bash
git add -A lib/features/profile
git commit -m "feat(profile): identity & photo quick-edit sheet"
```

---

### Task 8: Trade & experience sheet (incl. availability)

**Files:**
- Create: `lib/features/profile/presentation/widgets/edit_sheets/trade_details_sheet.dart`
- Modify: `lib/features/profile/presentation/pages/profile_edit_hub_page.dart` (tradeDetails row → sheet)

- [ ] **Step 1: Build the sheet.** Same skeleton. Move these private widgets verbatim out of `profile_edit_widgets.dart` into this file: `_TradePickerTile` (line 57), `_AvailabilityToggleRow` (184), `_AvailableFromField` (234), plus `_AvailabilityFields` from `profile_edit_form_fields.dart:252-279`. Body order: TRADE picker → YEARS OF EXPERIENCE → AVAILABILITY (toggle + conditional AVAILABLE FROM). Local state: `_tradeSlug`, `_tradeOther`, `_showTradeError` plus `_pickTrade()` moved from `profile_edit_page.dart:146-158` (selecting a trade sets `_dirty = true`). Field code copies from `profile_edit_form_fields.dart:160-188` (trade tile + years) — drop the legal-name field (it moved to Identity).
  Save:

```dart
    final isAvailable = values['is_available'] as bool? ?? true;
    final ok = await ref.read(profileControllerProvider.notifier).savePatches(
          trade: TradeProfilePatch(
            primaryTrade: Some(_tradeSlug!),
            tradeOther: Some(_tradeSlug == 'other' ? _tradeOther : null),
            yearsExperience: Some(_parseIntOrNull(values['years_experience'])),
            isAvailable: Some(isAvailable),
            availableFrom: Some(
              isAvailable ? null : values['available_from'] as DateTime?,
            ),
          ),
        );
```

  (`_parseIntOrNull` — copy the 8-line helper from `profile_edit_form_fields.dart:5-10` into this file as a private function; Task 12 deletes the original.) Validate `_tradeSlug != null` before saving, mirroring `profile_edit_page.dart:231-235`.

- [ ] **Step 2: Hub wiring** — `ProfileSection.tradeDetails => showJSheet(...)`. Hub preview for the row stays `tp?.primaryTrade`.

- [ ] **Step 3: Verify + commit** — same commands as Task 7, message `"feat(profile): trade & experience quick-edit sheet"`.

---

### Task 9: Business details sheet (builders)

**Files:**
- Create: `lib/features/profile/presentation/widgets/edit_sheets/business_details_sheet.dart`
- Modify: `lib/features/profile/presentation/pages/profile_edit_hub_page.dart` (business row → sheet)

- [ ] **Step 1: Build the sheet.** Move `_VerifiedLockedField` verbatim from `profile_edit_widgets.dart:403` into this file. Field stack copies from `_BuilderFields` (`profile_edit_form_fields.dart:29-113`): YOUR NAME (`contact_name`), COMPANY NAME + ABN (verified-locked — keep the `_isAbnVerified(bp)` lock logic and its comment), YEARS IN BUSINESS, WEBSITE, plus CONTACT PHONE moved from `_CommonFields` (`profile_edit_form_fields.dart:329-337`).
  Save (`nullIfBlank` = copy the 2-line helper from `profile_provider.dart:143-144`):

```dart
    final ok = await ref.read(profileControllerProvider.notifier).savePatches(
          builder: BuilderProfilePatch(
            companyName: Some((values['company_name'] as String).trim()),
            abn: Some(nullIfBlank(values['abn'] as String?)),
            contactName: Some(nullIfBlank(values['contact_name'] as String?)),
            contactPhone: Some(nullIfBlank(values['contact_phone'] as String?)),
            yearsInBusiness: Some(_parseIntOrNull(values['years_in_business'])),
            website: Some(nullIfBlank(values['website'] as String?)),
          ),
        );
```

  When the ABN lock is active, the locked fields are read-only — exclude them from the patch (use `const None()` instead of `Some`) so a locked save can never alter verified columns.

- [ ] **Step 2: Hub wiring** — `ProfileSection.business => showJSheet(...)`.

- [ ] **Step 3: Verify + commit** — message `"feat(profile): business details quick-edit sheet"`.

---

### Task 10: Location sheet

**Files:**
- Create: `lib/features/profile/presentation/widgets/edit_sheets/location_sheet.dart`
- Modify: `lib/features/profile/presentation/pages/profile_edit_hub_page.dart` (location row → sheet)

- [ ] **Step 1: Build the sheet.** Same skeleton, role-aware. Body = `ProfileLocationField` exactly as used in `profile_edit_form_fields.dart:314-326` (label `SERVICE LOCATION`/`BASE LOCATION`, `legacyInitial`, `placeInitial` via `buildProfilePlaceInitial`). Save resolves place-vs-legacy exactly like `profile_edit_page.dart:246-252`:

```dart
    final pickedPlace = values['place'] as JPlaceResult?;
    final suburb = pickedPlace?.suburb ?? (values['suburb'] as String?) ?? '';
    final auState = pickedPlace?.state ?? values['state'] as String?;
    final postcode = pickedPlace?.postcode ?? values['postcode'] as String?;
```

  then patches the role table (trade shown; builder mirrors with `service*` fields):

```dart
    trade: TradeProfilePatch(
      baseSuburb: Some(nullIfBlank(suburb)),
      baseState: Some(nullIfBlank(auState)),
      basePostcode: Some(nullIfBlank(postcode)),
      baseFormattedAddress: Some(nullIfBlank(pickedPlace?.formattedAddress)),
      basePlaceId: Some(nullIfBlank(pickedPlace?.placeId)),
      baseLatitude: Some(pickedPlace?.latitude),
      baseLongitude: Some(pickedPlace?.longitude),
    ),
```

  ⚠️ Only include the four place-extras (`formattedAddress/placeId/lat/lng`) when `pickedPlace != null` — a legacy 3-field edit must not wipe stored coordinates. Use `pickedPlace == null ? const None() : Some(...)` per field.

- [ ] **Step 2: Hub wiring** — `ProfileSection.location => showJSheet(...)`.

- [ ] **Step 3: Verify + commit** — message `"feat(profile): location quick-edit sheet"`.

---

### Task 11: About full-screen editor + route

**Files:**
- Create: `lib/features/profile/presentation/pages/about_edit_page.dart`
- Modify: `lib/app/router/app_router.dart:385-395` (add `about` route under `edit`)
- Modify: `lib/features/profile/presentation/pages/profile_edit_hub_page.dart` (about row → push; delete `legacyFocus`)

- [ ] **Step 1: Build the page.** Full-screen Scaffold matching the hub's header chrome (back button + `PageHeader(eyebrow: 'EDIT PROFILE', title: 'About')`), `PopScope` dirty guard via `showDiscardChangesSheet`, body = `JTextField(name: 'about', maxLines: 8, maxLength: 600, initialValue: isBuilder ? bp?.about : tp?.about, hint: <role-specific copy from profile_edit_form_fields.dart:343-345>)` inside a `FormBuilder`, footer = `BottomActionBar(primary: JButton(label: 'SAVE', ...))` (pattern from `profile_edit_page.dart:583-592`). Save patches `about` into the role table and pops with the success snackbar pattern from `profile_edit_page.dart:286-309`.

- [ ] **Step 2: Route** — inside the existing `edit` route's `routes: [...]`:

```dart
              GoRoute(
                path: 'about',
                builder: (_, _) => const AboutEditPage(),
              ),
```

- [ ] **Step 3: Hub wiring** — `ProfileSection.about => context.push('/profile/edit/about')`. All six sections now dispatch to sheets/page; delete `legacyFocus` and the `_ =>` fallback arm.

- [ ] **Step 4: Verify + commit** — `flutter analyze --no-fatal-infos && flutter test test/features/profile/`, message `"feat(profile): full-screen About editor; hub fully on quick-edit sheets"`.

---

### Task 12: Delete the long form + remove profile back button

**Files:**
- Delete: `lib/features/profile/presentation/pages/profile_edit_page.dart`
- Delete: `lib/features/profile/presentation/pages/profile_edit_form_fields.dart`
- Delete: `lib/features/profile/presentation/pages/profile_edit_widgets.dart`
- Delete: `lib/features/profile/domain/usecases/update_profile.dart`
- Modify: `lib/app/router/app_router.dart` (remove the `form` child route + `ProfileEditPage` import)
- Modify: `lib/features/profile/presentation/providers/profile_provider.dart` (delete `saveProfile` + `updateProfileUseCaseProvider` + `UpdateProfile` import; delete `updateProfile` from repo contract/impl/datasource ONLY if `grep -rn "updateProfile" lib` shows no remaining caller)
- Modify: `lib/features/profile/presentation/pages/profile_page.dart:115-130` (remove the back `IconButton`)
- Modify: `lib/features/profile/presentation/pages/profile_edit_hub_page.dart` (update the stale doc-comment at lines 13-18 — v2 partial saves are now real)

- [ ] **Step 1: Pre-delete safety greps** — each must return only the files being deleted:

```bash
grep -rn "ProfileEditPage\|profile/edit/form" lib test
grep -rn "saveProfile\|updateProfileUseCaseProvider" lib test
grep -rn "_StatusRow\|_SaveErrorBanner\|_VerificationSection" lib
```

If a test file references `saveProfile`/`ProfileEditPage`, port the test to the equivalent sheet behaviour or delete it with justification in the commit message.

- [ ] **Step 2: Delete + detach.** Remove the three page files, the use case, the router `form` route, controller `saveProfile`, and the provider. Remove the `/profile` page back-button `IconButton` (lines 115-130 region — keep the surrounding header Row layout intact; the dock + system back cover navigation, per user request 2026-06-11).

- [ ] **Step 3: Full verification**

Run: `bash scripts/validate.sh`
Expected: design checks, format, analyze, tests all green. Every new file ≤400 LOC (`wc -l lib/features/profile/presentation/widgets/edit_sheets/*.dart`).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(profile)!: quick-edit sheets replace the long edit form

- per-section partial saves (null-wipe fixed at the data layer)
- 600-line ProfileEditPage + form parts deleted
- /profile back button removed (dock + system back cover it)"
```

---

### Task 13: Docs + final checks

**Files:**
- Modify: `design-system/jobdun/pages/profile-dashboard.md` (document the sheet pattern under Component Overrides; code wins → doc patched in same PR)
- Modify: `docs/superpowers/specs/2026-06-11-profile-edit-quick-sheets-design.md` (mark Status: Implemented)

- [ ] **Step 1:** Add a "Quick-edit sheets" subsection to the design-system page override: hub rows open `showJSheet` editors built on `EditSheetScaffold`; About is the full-screen exception; per-section SAVE; dirty guard = discard confirm.
- [ ] **Step 2:** Run `bash scripts/validate.sh` one final time; fix anything red before claiming done (verification-before-completion).
- [ ] **Step 3: Commit** — `git commit -m "docs(profile): design-system + spec notes for quick-edit sheets"`.
