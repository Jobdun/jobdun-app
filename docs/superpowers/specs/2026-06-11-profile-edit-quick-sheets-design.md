# Profile Edit — Quick-Edit Sheets (Setup B)

**Date:** 2026-06-11
**Status:** Implemented 2026-06-11 (plan: `docs/superpowers/plans/2026-06-11-profile-edit-quick-sheets.md`).
Implementation note: the dirty guard uses a scoped willPop callback
(`WillPopScope`, registered from first build) instead of `PopScope` —
modal_bottom_sheet's drag-dismiss bypasses `PopScope` and snapshots its
close-veto at route build. Verified by widget test.
**Branch:** feat/trade-credentials-trust-layer (or successor)

## Context

The edit-profile hub (`profile_edit_hub_page.dart`, shipped 2026-06-11) lists profile
sections with current values and amber MISSING flags. In v1 every row pushes the same
600-line form (`/profile/edit/form?focus=…`) and one SAVE writes the whole profile,
because the data layer does full-row writes — `update(profile.toJson())` /
`upsert(profile.toJson())` (`profile_remote_datasource.dart:96–115`) null any column
not supplied.

Research pass (ui-ux-pro-max + context7 + platform conventions): per-section editing is
the universal pattern (LinkedIn, Instagram, Airbnb, Uber, Airtasker). For least
taps/friction the user chose **quick-edit bottom sheets**: 2 taps per section, zero
page transitions, hub stays visible behind the sheet so MISSING flags update live
(Goal-Gradient), controls in the thumb zone (Fitts), 3–4 fields per surface (Hick,
Miller).

## Decision

Each hub row opens a `showJSheet` containing only that section's fields and an
all-caps SAVE. Exception: **About** (long text) gets a full-screen editor page.
Saves are **partial**: only the touched section's columns are written.

## Architecture

### 1. Domain — patch entities (new)

Per-table patch value objects in `domain/entities/`, fields typed
`Option<T>` (fpdart, already a domain dependency):

- `none()` → column untouched (not in payload)
- `some(v)` → column written; `some(null)` clears a nullable column (e.g. postcode)

Types: `UserProfilePatch`, `TradeProfilePatch`, `BuilderProfilePatch` — only the
user-editable fields (no stats/verification/portfolio columns). Each exposes
`bool get isEmpty` so empty patches short-circuit to success.

### 2. Repository contract + impl

```dart
Future<Either<Failure, void>> patchUserProfile(String userId, UserProfilePatch p);
Future<Either<Failure, void>> patchTradeProfile(String userId, TradeProfilePatch p);
Future<Either<Failure, void>> patchBuilderProfile(String userId, BuilderProfilePatch p);
```

Datasource builds a column map from `some` fields only:

- `profiles` → `.update(map)` (row always exists via `handle_new_user`)
- `trade_profiles` / `builder_profiles` → `.upsert({user-id key, …map})` — PostgREST
  upsert only touches supplied columns, safe for both new and existing rows.

Existing full-save methods stay until the long form is deleted (last step), then the
unused ones go with it.

### 3. Use cases

`PatchUserProfile`, `PatchTradeProfile`, `PatchBuilderProfile` — thin wrappers, same
shape as existing `UpdateProfile`. Controller calls use cases (layer rule).

### 4. Controller

`ProfileController` gains one public method,
`savePatches({UserProfilePatch? user, TradeProfilePatch? trade, BuilderProfilePatch? builder})`
(3 named params, within the ≤4 rule; covers the Identity sheet's two-table save in one call),
returning `bool` like its sibling mutations. On success it refreshes **only the
patched table** via the existing repo getters + `state.copyWith(...)` (house
pattern from `setTradeAvailability`; entities have no copyWith so applying the
patch client-side isn't available). Sheet-local loading/error state lives in
the sheet.

### 5. Presentation — sheets

`presentation/widgets/edit_sheets/`, all built on a shared `EditSheetScaffold`
(title, ✕, SAVE with loading state, inline error, keyboard inset + scroll):

| Sheet | Role | Fields | Patches |
|---|---|---|---|
| Identity & photo | both | avatar (existing picker on top), display_name; tradie also full_name | profiles (+ trade_profiles for full_name) |
| Trade & experience | tradie | primary_trade (+ trade_other), years_experience, availability (is_available + available_from — lived in the old form's trade section) | trade_profiles |
| Rates | tradie | hourly_rate_min/max (cross-field max ≥ min), hourly_rate_visible toggle | trade_profiles |
| Business details | builder | company_name, abn (verified-lock preserved), years_in_business, website, contact_name, contact_phone | builder_profiles |
| Location | both | suburb/state/postcode + geocode fields (existing `profile_location_field`) | role table |
| About | both | full-screen page `/profile/edit/about`, multiline + char count | role table |

Amendments vs the first draft (2026-06-11, during planning): `crew_size` and
`service_radius_km` dropped — the old form never edited them (YAGNI);
availability moved into the Trade & experience sheet so deleting the form
doesn't orphan `available_from`.

Validation: existing FormBuilder validators move verbatim into each sheet.

### 6. Dirty guard

Each sheet tracks dirty state. Drag-down / ✕ with unsaved edits → existing
KEEP EDITING / DISCARD CHANGES confirm. Clean sheets dismiss freely.

### 7. Deletions (final step)

- `profile_edit_page.dart` (600 LOC), `profile_edit_form_fields.dart`,
  `/profile/edit/form` route + `?focus=` scroll machinery. Field widgets are
  recycled into sheets, not rewritten.
- Back button on `/profile` page (separate user request, same pass).
- Hub keeps its back button (pushed route).

## Error handling

- Save failure → inline error inside the sheet, fields keep user input.
- Empty patch (nothing changed) → SAVE acts as dismiss, no network call.
- Identity sheet's two-table save: patch profiles first, then trade_profiles;
  on partial failure show error and keep the sheet open (both patches idempotent).

## Testing

- **Null-wipe regression (the key test):** patch → column-map mapping asserts
  untouched fields are *absent* from the payload, and `some(null)` maps to SQL null.
- Repo impl patch methods (mocktail datasource).
- Controller `saveSection` success/error + state `copyWith` application.
- Widget test: rates sheet — validation, save, hub flag clears.

## Out of scope

Verification flows, portfolio, availability calendar (own surfaces); per-field
autosave (Setup C, rejected); server-side changes (none needed).
