# Location Picker Audit & Improvement Plan

**Status:** Audit + plan only — no code shipped in this pass
**Author:** Engineering
**Date:** 2026-05-22
**Branch context:** `feat/state-mgmt-followups`

---

## 1. Executive summary

Every place/location input in the Jobdun mobile app today is a plain `TextFormField`. Users hand-type suburb, state and postcode into 2- or 3-field rows on three surfaces (trade profile edit, builder profile edit, job create) and search by freetext on a fourth (jobs feed). There is no autocomplete, no current-location bias, no validation that the typed text is a real Australian place, and no lat/lng captured for profile records — only `jobs` carries coordinates.

The cost of this is concrete: typo'd suburbs (`Parramata`), mismatched state/postcode pairs (`Parramatta / VIC / 2000`), profile records that cannot be plotted on the home map (no lat/lng on `trade_profiles` or `builder_profiles`), weak distance matching in the jobs feed, and a missing-postcode bug on `job_create_page.dart` where the field is silently dropped from the form. Each of these compounds in the matching algorithm — a tradie in "Parramatta NSW 2150" never sees a job posted in "Paramatta NSW 2150".

The proposal is to introduce a single `JPlaceField` widget backed by a `PlacesService` core service, biased on the device's current location (the `geolocator` package is already wired for the map), restricted to Australia, and integrated with `flutter_form_builder`. The existing `suburb`/`state`/`postcode` columns stay populated (auto-filled from the Google Places result) for backward compatibility — three new columns (`formatted_address`, `place_id`, plus `latitude`/`longitude` on profile tables) are added alongside. The widget conforms to the existing Aggressive Flat design system; no new design vocabulary is introduced.

---

## 2. Current state inventory

### 2.1 Input surfaces

| # | Surface | File:line | Today | Persistence path |
|---|---------|-----------|-------|------------------|
| 1 | Trade profile edit (base location) | `lib/features/profile/presentation/pages/profile_edit_page.dart:485-533` | 3 fields: BASE SUBURB / STATE / POSTCODE (3-col row) | `profileControllerProvider.saveProfile` → `profileRepository` → `trade_profiles.{base_suburb, base_state, base_postcode}` |
| 2 | Builder profile edit (service location) | same widget, role-switched labels | 3 fields: SERVICE SUBURB / STATE / POSTCODE | Same controller → `builder_profiles.{service_suburb, service_state, service_postcode}` |
| 3 | Job create | `lib/features/jobs/presentation/pages/job_create_page.dart:160-194` | 2 fields: SUBURB / STATE (postcode silently dropped — bug) | `jobsController.createJob` → `jobsRepository` → `jobs.{suburb, state, postcode (empty), latitude (null), longitude (null)}` |
| 4 | Jobs search bar | `lib/features/jobs/presentation/pages/jobs_page.dart:144` | Freetext "Search trades, skills, suburbs…" | Debounced `search(query)` against `jobsRepository.search` — no structured location filter |

### 2.2 Validation today

| Surface | Field | Validator |
|---------|-------|-----------|
| Profile edit | Suburb | `FormBuilderValidators.required()` — no shape check |
| Profile edit | State | **None** — accepts `"new south wales"`, `"NSW"`, `"n.s.w."` interchangeably |
| Profile edit | Postcode | Regex `^\d{3,4}$` (AU format, but allows 3-digit which is invalid in AU) |
| Job create | Suburb | `required` only |
| Job create | State | `required` + `maxLength: 3` + caps hint — no semantic check |
| Job create | Postcode | Not captured in form |
| Jobs search | Query | None (debounced freetext) |

### 2.3 Cross-field validation

**None.** A user can save `Parramatta / VIC / 2150` (suburb is NSW, state is VIC, postcode is NSW). No referential check.

---

## 3. Schema inventory

### 3.1 Today

```
jobs.suburb               text NOT NULL DEFAULT ''
jobs.state                text NOT NULL DEFAULT ''
jobs.postcode             text NOT NULL DEFAULT ''
jobs.latitude             double precision NULL
jobs.longitude            double precision NULL

trade_profiles.base_suburb     text NULL
trade_profiles.base_state      text NULL
trade_profiles.base_postcode   text NULL
-- ⚠️ NO base_latitude / base_longitude

builder_profiles.service_suburb     text NULL
builder_profiles.service_state      text NULL
builder_profiles.service_postcode   text NULL
-- ⚠️ NO service_latitude / service_longitude
```

Source migrations: `supabase/migrations/20260511000002_jobs.sql`, `supabase/migrations/20260512000005_profile_extended_columns.sql`.

PostGIS is **not** enabled. Locations are denormalised text + (optionally on jobs) lat/lng pair. This is fine for the foreseeable feature set — radius queries can be done with the haversine formula in SQL, no need to migrate to PostGIS.

### 3.2 Target (after this initiative)

```
jobs.suburb               text NOT NULL  ← unchanged, auto-filled from Places
jobs.state                text NOT NULL  ← unchanged
jobs.postcode             text NOT NULL  ← unchanged (bug-fix: now actually captured)
jobs.latitude             double precision NULL  ← unchanged
jobs.longitude            double precision NULL  ← unchanged
+ jobs.formatted_address  text NULL
+ jobs.place_id           text NULL

trade_profiles.base_suburb / state / postcode  ← unchanged
+ trade_profiles.base_formatted_address  text NULL
+ trade_profiles.base_place_id           text NULL
+ trade_profiles.base_latitude           double precision NULL
+ trade_profiles.base_longitude          double precision NULL

builder_profiles.service_suburb / state / postcode  ← unchanged
+ builder_profiles.service_formatted_address  text NULL
+ builder_profiles.service_place_id           text NULL
+ builder_profiles.service_latitude           double precision NULL
+ builder_profiles.service_longitude          double precision NULL

CREATE INDEX idx_trade_profiles_base_latlng    ON trade_profiles    (base_latitude, base_longitude);
CREATE INDEX idx_builder_profiles_service_latlng ON builder_profiles (service_latitude, service_longitude);
```

---

## 4. Gap analysis

| Concern | Today | Required for Places |
|---------|-------|---------------------|
| GCP project | None for Places | New project (or reuse existing if any), Places API enabled, billing alert configured |
| API key | `GOOGLE_WEB_CLIENT_ID` / `GOOGLE_IOS_CLIENT_ID` exist for Sign-In only | New `GOOGLE_PLACES_API_KEY`, restricted by package + cert |
| Env wiring | `lib/core/config/env.dart` reads `--dart-define`s | Add `placesApiKey` getter |
| CI secret | `SUPABASE_*` set in GitHub Actions; Google Sign-In secrets intentionally empty | Add `GOOGLE_PLACES_API_KEY` secret (empty-ok in CI, Places not exercised in tests) |
| Flutter package | `geolocator` only | Add `google_places_flutter` (autocomplete-only, no Maps SDK) |
| Service layer | `lib/core/services/` has 6 services, none location-aware | Add `places_service.dart` + `places_service_provider.dart` |
| Widget layer | 19 widgets in `lib/core/design/widgets/`, none for location input | Add `j_place_field.dart` (+ extracted `j_place_field_suggestion_row.dart` if needed) |
| Schema | text-only location on profiles | 6 new columns, 2 new indexes (see §3.2) |
| Permissions | Android + iOS location permissions declared and used by `_MapView` | Reuse existing — no manifest/Info.plist changes needed except wording update on iOS |
| Privacy copy | Info.plist string mentions "map" only | Append "address suggestions" to `NSLocationWhenInUseUsageDescription`; update privacy policy |

---

## 5. Proposed architecture

### 5.1 `PlacesService` — `lib/core/services/places_service.dart`

Thin async wrapper over two Google Places REST endpoints:

```
GET https://maps.googleapis.com/maps/api/place/autocomplete/json
  ?input=<query>
  &components=country:au
  &location=<lat>,<lng>           ← optional, when geolocator returns a Position
  &radius=50000                    ← 50 km bias when location is available
  &sessiontoken=<uuid>             ← billing optimisation
  &key=<GOOGLE_PLACES_API_KEY>

GET https://maps.googleapis.com/maps/api/place/details/json
  ?place_id=<id>
  &fields=address_components,formatted_address,geometry
  &sessiontoken=<same uuid>
  &key=<GOOGLE_PLACES_API_KEY>
```

**API surface (Dart):**

```dart
abstract class PlacesService {
  /// Returns up to 5 AU-only suggestions for [query]. Biases on [near] when given.
  Future<List<JPlaceSuggestion>> autocomplete(
    String query, {
    LatLng? near,
    required PlacesSessionToken session,
  });

  /// Resolves [suggestion] to a full JPlaceResult with lat/lng + parsed address.
  Future<JPlaceResult> details(
    JPlaceSuggestion suggestion, {
    required PlacesSessionToken session,
  });

  /// Reverse-geocode current device location → nearest suburb suggestion.
  /// Used by the "USE MY CURRENT LOCATION" chip.
  Future<JPlaceResult?> reverseGeocodeCurrent();
}
```

**Provider wiring (Riverpod 3):**

```dart
final placesServiceProvider = Provider<PlacesService>((ref) {
  return PlacesServiceImpl(
    apiKey: Env.placesApiKey,
    httpClient: ref.watch(httpClientProvider),
    locationProvider: ref.watch(deviceLocationProvider),
  );
});
```

Per CLAUDE.md → Engineering Standards, this provider MUST be top-level public (no leading `_`) so tests can override it via `ProviderScope(overrides: [...])`.

**Architectural placement:** `lib/core/services/` is the right home — Places is a cross-feature concern (profile + jobs both consume it), exactly like `image_upload_service.dart`. This follows the documented auth-feature exception pattern from CLAUDE.md: a third-party stateful client (sessions, network) goes in `data/services/` or `core/services/`, not behind a `domain/usecases/` indirection. The indirection adds ceremony without value for this kind of client.

### 5.2 `JPlaceField` — `lib/core/design/widgets/j_place_field.dart`

A `FormBuilderField<JPlaceResult>` subclass that renders the Aggressive Flat input style and integrates with `flutter_form_builder` so the rest of each form (validators, save, reset) keeps working unchanged.

**Public API:**

```dart
class JPlaceField extends StatelessWidget {
  const JPlaceField({
    required this.name,           // FormBuilder field name
    required this.label,          // Oswald uppercase label
    this.initialValue,            // Pre-fill with saved place
    this.hint,
    this.onChanged,
    super.key,
  });

  final String name;
  final String label;
  final JPlaceResult? initialValue;
  final String? hint;
  final ValueChanged<JPlaceResult?>? onChanged;
}
```

On selection, the field exposes a single `JPlaceResult` value to FormBuilder. Parent pages then split that into the four hidden form fields the existing save path expects (suburb / state / postcode / lat / lng).

### 5.3 Data model

```dart
class JPlaceResult {
  final String placeId;
  final String formattedAddress;
  final String suburb;
  final String state;       // 2-3 letter AU abbreviation (NSW/VIC/QLD/WA/SA/TAS/ACT/NT)
  final String postcode;    // 4-digit AU
  final double latitude;
  final double longitude;
}

class JPlaceSuggestion {
  final String placeId;
  final String mainText;     // "Parramatta"
  final String secondaryText; // "NSW 2150, Australia"
}
```

---

## 6. Design System Compliance

This is non-negotiable. The widget MUST conform to `design-system/jobdun/MASTER.md` (Aggressive Flat, dark slate) and the conventions in CLAUDE.md → *UI/UX conventions*.

### 6.1 Hard rules (any one violation = redesign)

| # | Rule | Source | Enforced by |
|---|------|--------|-------------|
| 1 | Colour tokens via `Theme.of(context).colorScheme` only — never raw `Color(0xFF...)` in `lib/features/` or `lib/core/design/widgets/` | CLAUDE.md → CI/CD § "What validate.sh checks" | `scripts/validate.sh` grep |
| 2 | Fonts via `AppTheme.textTheme` only — never `GoogleFonts.*` outside `lib/app/theme/app_theme.dart` | CLAUDE.md → UI/UX conventions § "Fonts" | `scripts/validate.sh` grep |
| 3 | Spacing via `Gap(n)` — never `SizedBox(height:/width:)` in `lib/features/` | CLAUDE.md → UI/UX conventions § "Spacing" | `scripts/validate.sh` grep |
| 4 | Sizes via screenutil extensions (`.w`, `.h`, `.sp`, `.r`) — never raw px | CLAUDE.md → UI/UX conventions § "Sizing" | Review |
| 5 | Icons via `AppIcons.*` only — feature code must not import `phosphor_flutter` | CLAUDE.md → UI/UX conventions § "Icons" | Review |
| 6 | No emojis as UI icons | ui-ux-pro-max Common Rules § "Icons" | Review |
| 7 | No box-shadow, no gradient, no inline `Colors.white` | MASTER.md § "Anti-patterns" + validate.sh | `scripts/validate.sh` grep |
| 8 | Loading = `JSkeletonList`, never `CircularProgressIndicator` for the dropdown | CLAUDE.md → UI/UX conventions § "Loading" | Review |
| 9 | Animations 150–200 ms ease, no spring/bounce, no Material ripple | MASTER.md § "Transitions" | Review |
| 10 | Bottom sheets via `showJSheet`, never `showModalBottomSheet` | CLAUDE.md → UI/UX conventions § "Bottom sheets" | Review |

### 6.2 Token cheat sheet (resolved from MASTER.md)

```
Background        #0F172A   colorScheme.background       (page bg)
Surface           #1E293B   colorScheme.surface          (field bg)
Surface Raised    #334155   colorScheme.surfaceContainerHighest (dropdown bg, chip bg)
CTA / Accent      #F97316   colorScheme.primary          (focus ring, matched-substring highlight)
Primary Text      #F1F5F9   colorScheme.onSurface        (input text)
Secondary Text    #94A3B8   colorScheme.onSurfaceVariant (label, hint, secondary suggestion line)
Border            #334155   colorScheme.outline          (resting border, dividers)
Error             #EF4444   colorScheme.error            (error border, error text)
Success           #22C55E   (not used by this widget)
```

### 6.3 Existing AppIcons glyphs to use (verified present)

| Use | AppIcons key | Phosphor |
|-----|--------------|----------|
| Field leading icon (resting) | `AppIcons.location` | `PhosphorIconsBold.mapPin` |
| Field leading icon (selected) | `AppIcons.locationFilled` | `PhosphorIconsFill.mapPin` |
| "Use my current location" chip | `AppIcons.gps` | `PhosphorIconsBold.crosshair` |
| Active "near you" state | `AppIcons.gpsFilled` | `PhosphorIconsFill.crosshair` |
| Permission denied / no GPS | `AppIcons.locationUnavailable` | `PhosphorIconsBold.mapPinLine` |
| Clear input | `AppIcons.close` | `PhosphorIconsBold.x` |

**No new icons need to be added** — every glyph this widget needs is already in `lib/core/theme/app_icons.dart`.

### 6.4 ASCII mockups

**State 1 — Resting (empty, no value):**

```
┌────────────────────────────────────────────────────┐
│ BASE LOCATION                                      │  ← Oswald uppercase, 12.sp, onSurfaceVariant
│ ┌────────────────────────────────────────────────┐ │
│ │ [📍] Search suburb, postcode or address     [×]│ │  ← icons = AppIcons.location + AppIcons.close
│ └────────────────────────────────────────────────┘ │     border = colorScheme.outline (1.r)
└────────────────────────────────────────────────────┘     surface = colorScheme.surface
```

**State 2 — Focused (typing, no selection yet):**

```
┌────────────────────────────────────────────────────┐
│ BASE LOCATION                                      │
│ ┌════════════════════════════════════════════════┐ │  ← border = colorScheme.primary (2.r, orange)
│ │ [📍] parra|                                 [×]│ │
│ └════════════════════════════════════════════════┘ │
│ ┌────────────────────────────────────────────────┐ │  ← dropdown bg = surfaceContainerHighest
│ │ [⌖]  USE MY CURRENT LOCATION                   │ │  ← AppIcons.gps, Oswald, accent orange
│ ├────────────────────────────────────────────────┤ │
│ │ [📍] Parramatta                                │ │  ← Open Sans 16.sp, onSurface
│ │      NSW 2150, Australia                       │ │  ← Open Sans 13.sp, onSurfaceVariant
│ ├────────────────────────────────────────────────┤ │
│ │ [📍] Parramatta Park                           │ │
│ │      QLD 4870, Australia                       │ │
│ ├────────────────────────────────────────────────┤ │
│ │ [📍] North Parramatta                          │ │
│ │      NSW 2151, Australia                       │ │
│ └────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────┘
```

Matched substring "parra" rendered in `colorScheme.primary` (orange) — colour-only highlight, NOT bold/underline (consistent with Aggressive Flat).

**State 3 — Loading (request in flight, 250ms debounce already elapsed):**

```
┌────────────────────────────────────────────────────┐
│ BASE LOCATION                                      │
│ ┌════════════════════════════════════════════════┐ │
│ │ [📍] parramatta r|                          [×]│ │
│ └════════════════════════════════════════════════┘ │
│ ┌────────────────────────────────────────────────┐ │
│ │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │ │  ← JSkeletonList row 1
│ │ ▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │ │
│ ├────────────────────────────────────────────────┤ │
│ │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │ │  ← JSkeletonList row 2
│ │ ▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │ │
│ ├────────────────────────────────────────────────┤ │
│ │ ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │ │  ← JSkeletonList row 3
│ │ ▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │ │
│ └────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────┘
```

**State 4 — Selected (place picked, field shows formatted address):**

```
┌────────────────────────────────────────────────────┐
│ BASE LOCATION                                      │
│ ┌────────────────────────────────────────────────┐ │
│ │ [📍] Parramatta NSW 2150, Australia         [×]│ │  ← AppIcons.locationFilled, onSurface
│ └────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────┘
```

**State 5 — Error (network fail / no matches / invalid postcode):**

```
┌────────────────────────────────────────────────────┐
│ BASE LOCATION                                      │
│ ┌════════════════════════════════════════════════┐ │  ← border = colorScheme.error (red)
│ │ [📍] paramata|                              [×]│ │
│ └════════════════════════════════════════════════┘ │
│ Couldn't find that suburb. Try a postcode or       │  ← Open Sans 13.sp, colorScheme.error
│ tap the GPS icon to use your current location.     │
└────────────────────────────────────────────────────┘
```

### 6.5 Layer rules (`presentation/` ↔ `domain/` ↔ `data/`)

- `JPlaceField` lives in `lib/core/design/widgets/` — it's a shared widget, no feature ownership.
- It depends on `placesServiceProvider` (declared in `core/services/places_service_provider.dart`) via `ref.watch`.
- It does **not** import `package:supabase_flutter` — Places API is HTTP, not Supabase.
- Feature pages (`profile_edit_page.dart`, `job_create_page.dart`, `jobs_page.dart`) consume `JPlaceField` from `core/design/widgets/`. The pages then map `JPlaceResult` → existing hidden FormBuilder fields. This keeps the existing `domain/usecases/save_profile.dart` and `domain/usecases/create_job.dart` paths unchanged.

---

## 7. Guardrails (the "proper guardrails" requested)

| # | Rule | Implementation |
|---|------|---------------|
| 1 | **Structured-only submit** — form save is blocked unless the user picked a suggestion (no raw-typed acceptance) | `placeRequired()` validator returns "Pick a suggestion to continue" when `place_id == null` |
| 2 | **AU-only** | `components=country:au` at the API + a redundant `placeAustralian()` validator checking the parsed result |
| 3 | **Completeness check** — minimum {suburb, state, postcode, lat, lng} must all be non-null | `placeComplete()` validator. If Google omits any (some rural addresses), surface "We need a more specific address — try a nearby postcode" |
| 4 | **Postcode normalisation** | Trim whitespace; require exactly 4 digits at the parser layer; reject `"2000 "` |
| 5 | **State normalisation** | Map to the 2–3 letter AU abbreviation (NSW/VIC/QLD/WA/SA/TAS/ACT/NT) — Google returns "New South Wales" by default |
| 6 | **Suburb normalisation** | Title-case via `intl` package — `"PARRAMATTA"` → `"Parramatta"` |
| 7 | **Submission idempotency** | Store `place_id`; if the user re-saves the same place, the lat/lng comes from cached details (no re-fetch) |
| 8 | **No silent overwrites** | On profile-edit re-open, pre-fill the field with the saved `formatted_address`. Clearing the field clears all derived columns (suburb, state, postcode, lat, lng, place_id, formatted_address) atomically — never leave the row in a half-populated state |
| 9 | **Network-degraded fallback** | If `PlacesService.autocomplete` throws (offline, key revoked, quota exceeded), surface inline error and reveal an "Edit manually" toggle that re-shows the legacy 3-field form for that submission. Postcode regex `^\d{4}$` still applies |
| 10 | **Search-bar variant** (`jobs_page.dart`) | Debounced freetext stays the primary input. When Places returns a confident match for the query, render a tappable chip BELOW the input: `[📍 SUBURB: Parramatta NSW]` (Oswald uppercase, leading `AppIcons.location`, accent orange border, slate background). Tapping the chip scopes the search to that suburb's lat/lng radius |
| 11 | **Session token discipline** | One token per user-typing-session (creation → details fetch → reset). Costs $0.017 per session, regardless of how many keystrokes |
| 12 | **Debounce + minimum length** | No autocomplete fires before 3 characters typed; debounce 250 ms between keystrokes |

---

## 8. Phased rollout

Effort estimates assume one engineer familiar with the codebase. They include design-system audit + tests.

| Phase | Scope | Estimate |
|-------|-------|----------|
| **0 — Provisioning** | Create/reuse GCP project; enable Places API; create restricted key (Android pkg + SHA-1, iOS bundle ID); add `GOOGLE_PLACES_API_KEY` to `env.dart` + GitHub Actions secret; set up GCP billing alert at $50/month | 0.5 day |
| **1 — Foundation** | Add `google_places_flutter` to `pubspec.yaml`; implement `PlacesService` + provider + `JPlaceResult` model + `JPlaceSuggestion` model; implement `JPlaceField` widget with all 5 states; mocktail-based unit tests for service; widget test for field | 2 days |
| **2 — Schema migration** | One migration adds 6 columns + 2 indexes; regenerate DTOs (`build_runner`); update `profileRepository.save` + `jobsRepository.create` to round-trip the new columns | 0.5 day |
| **3 — Wire profile edit** | Replace 3-field row in `profile_edit_page.dart:485-533` with one `JPlaceField`. Hidden fields auto-fill from result. Behind `--dart-define=PLACES_ENABLED=true` for cautious rollout | 0.5 day |
| **4 — Wire job create** | Replace 2-field row in `job_create_page.dart:160-194` with one `JPlaceField`. **This also captures the missing postcode bug** | 0.5 day |
| **5 — Wire jobs search** | Add Places-match chip below `jobs_page.dart:144` search input. Wire chip tap → radius-scope the existing `jobsRepository.search` | 0.5 day |
| **6 — Cleanup** | Remove `PLACES_ENABLED` flag after a 1-week soak; delete legacy fallback paths; update `docs/MAP_USAGE_AUDIT.md` cross-reference | 0.25 day |

**Total: ~5 days.**

---

## 9. Risks + mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Billing surprises (Places Autocomplete is $0.00283/session + $0.017/details) | Medium | High | Session tokens (one billing session per user-typing-session); set GCP budget alert at $50/month; document a $200/month ceiling for v1 |
| Network failure leaving users stranded mid-form | Medium | Medium | Graceful degradation to legacy 3-field input behind a toggle (guardrail #9) |
| Privacy regression (sending device location to Google) | Low | Medium | Update Info.plist usage description to mention "address suggestions"; update privacy policy; respect denied permission (no `location=...` param) |
| Existing data quality (typo'd suburbs already in DB) | High | Low | One-off cleanup script optional; keeps working — old rows just won't have lat/lng/place_id until the user re-saves |
| `google_places_flutter` package abandonment | Low | Medium | Service-layer indirection lets us swap to `flutter_google_places_sdk` (official) without touching call sites |
| GPS permission denied → "use current location" chip looks broken | Medium | Low | Show the chip in `AppIcons.locationUnavailable` + secondary text colour with "Tap to enable location" copy; deep-link to settings on tap |
| iOS Info.plist string change requires App Store review | Low | Low | Bundle the copy change in the same release as the feature; it's a minor description tweak, not a new permission |

---

## 10. Open questions (resolve before Phase 1 starts)

1. **Billing ceiling**: confirm $200/month is acceptable for v1 or set a different cap.
2. **GCP project**: do we reuse an existing GCP project (which one?) or create a dedicated `jobdun-places` project?
3. **Jobs search chip**: ship in Phase 5 of this initiative, or defer to a separate follow-up after profile + job create are validated?
4. **Privacy policy**: who owns the wording update? (Legal vs engineering self-serve.)
5. **Data backfill**: should we run a one-off script to fill `lat/lng` for existing rows via reverse-geocoding their suburb+postcode, or wait for organic re-saves?
6. **Reverse geocoding limits**: the "use current location" chip calls Places Nearby Search — confirm this is in the same billing bucket and not a separate Geocoding API call.

---

## 11. Appendix A — GCP runbook (copy-paste)

```bash
# 1. Pick or create a GCP project
gcloud projects create jobdun-places --name="Jobdun Places" --set-as-default

# 2. Enable the Places API (new + legacy, in case the package uses the legacy endpoint)
gcloud services enable places.googleapis.com
gcloud services enable places-backend.googleapis.com   # legacy autocomplete endpoint

# 3. Set up billing alert
#    → https://console.cloud.google.com/billing/<id>/budgets
#    Budget: $50/month, alert at 50% / 90% / 100%

# 4. Create the API key
gcloud alpha services api-keys create --display-name="Jobdun Places (Mobile)" \
  --api-target=service=places.googleapis.com \
  --api-target=service=places-backend.googleapis.com \
  --allowed-application=sha1_fingerprint=<ANDROID_DEBUG_SHA1>,package_name=com.example.jobdun \
  --allowed-application=sha1_fingerprint=<ANDROID_RELEASE_SHA1>,package_name=com.example.jobdun \
  --allowed-ios-app-bundle-ids=com.example.jobdun

# 5. Retrieve the key string and add it to env
gcloud alpha services api-keys list --format=json
# Copy keyString; add to:
#   - flutter run --dart-define=GOOGLE_PLACES_API_KEY=<key>
#   - GitHub → Settings → Secrets → Actions → New repository secret
#       Name: GOOGLE_PLACES_API_KEY
#       Value: <key>   (or leave empty in CI — Places isn't exercised in tests)
```

---

## 12. Appendix B — Design-token cheat sheet

Pulled directly from `design-system/jobdun/MASTER.md`. Use these names — not hex literals — in code.

```dart
// Colours
colorScheme.background              // #0F172A  page background
colorScheme.surface                 // #1E293B  card/input background
colorScheme.surfaceContainerHighest // #334155  raised surface (dropdown, chips)
colorScheme.primary                 // #F97316  CTA, focus ring, accent
colorScheme.onSurface               // #F1F5F9  primary text on dark
colorScheme.onSurfaceVariant        // #94A3B8  secondary text on dark
colorScheme.outline                 // #334155  borders, dividers
colorScheme.error                   // #EF4444

// Typography (always via AppTheme.textTheme — never GoogleFonts.* in feature code)
textTheme.labelLarge   // Oswald, uppercase, 12.sp, letterSpacing 1.2  — labels, all-caps CTAs
textTheme.bodyMedium   // Open Sans, 16.sp                              — input text, body
textTheme.bodySmall    // Open Sans, 13.sp, onSurfaceVariant            — secondary lines, hints

// Spacing & sizing (Gap + screenutil — never raw SizedBox / raw px)
Gap(8.h) / Gap(12.h) / Gap(16.h) / Gap(24.h)  // vertical rhythm
SizedBox(width: 8.w) // ← NEVER — use Gap or padding instead

// Animation (150–200 ms ease, no spring)
.animate().fadeIn(duration: 180.ms, curve: Curves.easeOut)
.animate().slideY(begin: -0.02, end: 0, duration: 180.ms, curve: Curves.easeOut)

// Icons (AppIcons only — never PhosphorIconsBold.* in feature code)
AppIcons.location            // pin (Bold) — default leading
AppIcons.locationFilled      // pin (Fill) — selected/active
AppIcons.gps                 // crosshair (Bold) — use-current-location
AppIcons.gpsFilled           // crosshair (Fill) — active "near you"
AppIcons.locationUnavailable // pin line — GPS denied/unavailable
AppIcons.close               // x — clear input

// Loading
JSkeletonList(itemCount: 3, itemBuilder: ...)   // ← dropdown loading
// NEVER CircularProgressIndicator for the dropdown body

// Bottom sheets
showJSheet(context: context, builder: ...)
// NEVER showModalBottomSheet directly
```

---

**Next step:** resolve §10 open questions, then start Phase 0 in a new branch `feat/places-autocomplete`.
