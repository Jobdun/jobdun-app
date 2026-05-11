# Jobdun — Quality-of-Life Audit

> **Generated:** 2026-05-11  
> **Branch:** develop  
> **Dart files:** 134 | **Features:** 10 | **Test files:** 1

This document gives any engineer (or AI agent) a fast snapshot of where the project stands — what's solid, what's broken, what's unused, and what still needs to be built.

---

## Executive Summary

| Category | Status | Priority |
|---|---|---|
| Architecture | ✅ Solid | Low |
| State Management | ⚠️ Inconsistent | Medium |
| Theme & Design Tokens | ✅ Good | Low |
| Navigation & Routing | ✅ Good | Low |
| Error Handling | ❌ Partial | High |
| Test Coverage | ❌ Critical | Critical |
| Package Usage | ⚠️ Bloated | Medium |
| Feature Completeness | ⚠️ Partial | Medium |
| Code Quality | ⚠️ Fair | Low |
| DX / Tooling | ❌ Missing | Medium |

### Top 3 to fix first

1. **Tests** — 1 scaffold test file, 0 meaningful tests. Every domain use case is untested.
2. **Error handling** — Silent `catch (_)` blocks swallow failures; raw `.toString()` shown to users.
3. **Mock data** — `jobs_page.dart` renders a hardcoded `_mockJobs` list. The feed is not real.

---

## 1. Architecture Health

**Rating: ✅ Solid**

Feature-first clean architecture is consistently applied across all 10 features. The domain layer has no Flutter or Supabase imports. Repositories are correctly defined as contracts in domain and implemented in data.

### Minor violations

- **`home_page.dart`** imports `Job`, `JobApplication`, `BuilderProfile`, `TradeProfile` entity types directly from sibling feature domain layers. Should access these only via providers.
- **`app_router.dart`** imports all 24 page classes at the top level (lines 5–24). Any page rename or move breaks the router. Consider lazy builders or per-feature route files.

### What's working well

- `Either<Failure, T>` from `fpdart` used consistently in all use cases.
- Datasources → repositories → use cases → providers layering is clean.
- No cross-feature data layer access found.

---

## 2. State Management

**Rating: ⚠️ Inconsistent**

Riverpod `NotifierProvider` is used correctly for the main controllers (`authControllerProvider`, `jobsControllerProvider`, `profileControllerProvider`). The pattern is: datasource provider → repository provider → `NotifierProvider` controller.

### Issues

| Issue | Location |
|---|---|
| Manual `copyWith()` everywhere — Freezed blocked | `pubspec.yaml` line ~196 (comment explains) |
| `ThemeNotifier._load()` is async but returns `ThemeMode.dark` synchronously first — causes a UI re-render on every cold launch | `lib/app/theme/theme_provider.dart:13` |
| `Future.microtask(_loadProfile)` called inside `build()` — async side-effect in synchronous build | `lib/features/auth/presentation/providers/auth_provider.dart:56` |
| No cache invalidation when auth state changes — providers hold stale data after sign-out | All feature providers |
| Mixed reactive patterns — auth is stream-driven (`onAuthStateChange.listen`); jobs is fetch-once | auth_provider vs jobs_provider |

### Fix for ThemeNotifier race condition
Replace the sync `build()` default with an `AsyncNotifier` or load prefs before app init in `main.dart` and pass the initial value.

---

## 3. Theme & Design Tokens

**Rating: ✅ Good**

The `JColors` ThemeExtension with `context.c` shorthand is the correct pattern and is used throughout. All semantic tokens are defined: `action` (orange), `verified` (green), `urgent` (red), `available` (blue), `text1/2/3`, `surface`, `background`.

### What's solid
- `AppSpacing` and `AppRadius` constants used consistently — no raw pixel values spotted.
- `Gap(n)` used instead of `SizedBox` throughout.
- `flutter_screenutil` `.w/.h/.sp/.r` extensions used on all sizing.

### Gaps

| Issue | Location |
|---|---|
| 15+ `Colors.white` hardcoded — most are intentional (white-on-action, overlay) but some are not | profile_page.dart:154, various |
| `Colors.black45` for avatar upload overlay — no token for overlay opacity | `profile_page.dart:154` |
| Light theme was private until 2026-05-11 toggle feature; now public but **untested** | `lib/app/theme/app_theme.dart` |
| Lottie empty states specified in CLAUDE.md but **not implemented anywhere** | All feature pages |
| `Skeletonizer` installed but not used — loading states are raw `CircularProgressIndicator` | All feature pages |
| CLAUDE.md specifies 150–200ms ease transitions; no explicit animation durations set | Most widgets |

---

## 4. Navigation & Routing

**Rating: ✅ Good**

GoRouter 17.2.3 with `StatefulShellRoute.indexedStack` for 5-tab shell navigation. Auth redirect logic correctly handles: unauthenticated → `/login`, pending email verification → `/verify-email`, incomplete onboarding → `/onboarding`.

### What's solid
- Nested routes on Jobs tab prevent `/jobs/create` matching `:id`.
- `refreshListenable` correctly tied to `authControllerProvider` changes.
- Full-screen routes (verification, reviews, notifications) sit outside the shell.

### Gaps

| Issue | Severity |
|---|---|
| No role-based route guards — builder vs trade checks happen inside widgets, not in redirect | Medium |
| No dismiss/pop routes after full-screen modals (verification, reviews, notifications complete states) | Medium |
| `JobDetailArgs` and `ConversationArgs` passed via `extra` — breaks on deep link or serialization need | Low |
| All 24 page imports in one file — tight coupling, refactor risk | Low |

---

## 5. Error Handling

**Rating: ❌ Partial**

Sealed `Failure` hierarchy exists (`ServerFailure`, `NetworkFailure`, `AuthFailure`, `StorageFailure`, `ValidationFailure`, `NotFoundFailure`, `PermissionFailure`). Domain use cases return `Either<Failure, T>`. Provider-level state holds `error: String?`.

### Critical gaps

| Issue | Location |
|---|---|
| Silent `catch (_) {}` swallows failures with no logging | `auth_provider.dart` (completeOnboarding), `auth_remote_datasource.dart` (_fetchProfile) |
| Raw `.toString()` sent to UI — not user friendly | `auth_provider.dart:178`, `auth_provider.dart:246` |
| No `Failure → user message` mapping — each provider does its own string | All providers |
| `connectivity_plus` installed but **never imported or used** — no offline detection | All files |
| No retry logic anywhere — network failure = permanent error state until manual refresh | All features |

### Recommended fix
Create `lib/core/errors/error_messages.dart` with a single `toMessage(Failure)` function. All providers call this instead of `.toString()`.

---

## 6. Test Coverage

**Rating: ❌ Critical**

```
test/
  widget_test.dart   ← Flutter default scaffold only
```

Zero meaningful tests exist. `mocktail` is in `dev_dependencies` but never imported.

### What's untested

- All domain use cases (signIn, signUp, getJobs, applyToJob, getProfile, …)
- All repository implementations (real Supabase query logic)
- All Riverpod controllers (AuthController, JobsController, ProfileController)
- All UI widgets and pages
- All error paths

### Recommended test priority

1. `test/features/auth/domain/usecases/sign_in_test.dart` — mock repository, test success + failure
2. `test/features/jobs/domain/usecases/get_jobs_test.dart`
3. `test/features/auth/presentation/providers/auth_provider_test.dart` — ProviderContainer tests
4. Widget tests for `AppButton`, `AppTextField`, `JobCard`

---

## 7. Package Usage

**Rating: ⚠️ Bloated — 13 packages installed but not yet used**

### Actively used (16)
`go_router`, `flutter_riverpod`, `supabase_flutter`, `equatable`, `fpdart`, `google_fonts`, `iconsax`, `flutter_screenutil`, `gap`, `flutter_animate`, `pinput`, `flutter_form_builder`, `form_builder_validators`, `flutter_svg`, `flutter_rating_bar`, `shared_preferences`

### Installed but not implemented (13)

| Package | Intended use (per CLAUDE.md) | Action |
|---|---|---|
| `smooth_page_indicator` | Onboarding carousel dots | Implement or remove |
| `flutter_slidable` | Swipe actions on job cards | Implement or remove |
| `badges` | Notification dot overlays | Implement or remove |
| `percent_indicator` | Progress bars | Implement or remove |
| `expandable` | Collapsible job descriptions | Implement or remove |
| `flutter_staggered_animations` | List item entrance animations | Implement or remove |
| `modal_bottom_sheet` | iOS-style bottom sheets | Implement or remove |
| `photo_view` | Zoomable document viewer (verification) | Implement or remove |
| `flutter_image_compress` | Compress avatar before upload | Implement or remove |
| `image_cropper` | Crop avatar before upload | Implement or remove |
| `fl_chart` | Earnings/analytics dashboard | Implement or remove |
| `table_calendar` | Trade availability calendar | Implement or remove |
| `infinite_scroll_pagination` | Paginated jobs feed | Implement — jobs feed needs this |

---

## 8. Feature Completeness

| Feature | Status | Notes |
|---|---|---|
| Auth — email sign-in/up | ✅ Real | Working end-to-end |
| Auth — Google OAuth | ✅ Real | Wired via `google_sign_in` |
| Auth — Apple OAuth | ✅ Real | Wired via `sign_in_with_apple` |
| Auth — email verification | ⚠️ Partial | Route exists; flow needs testing |
| Auth — forgot password | ⚠️ Partial | Page exists; untested |
| Auth — onboarding | ⚠️ Partial | Page exists; completion logic in provider |
| Jobs feed | ⚠️ Partial | Mock `_mockJobs` fallback renders when feed empty |
| Job create | 🔲 Stub | Page exists; no save/submit tested |
| Job detail | ⚠️ Partial | Display only; no apply button logic confirmed |
| Applications list | ⚠️ Partial | Tab filtering works; no empty state widget |
| Messaging — thread list | 🔲 Stub | Routes and page exist; no realtime |
| Messaging — thread view | 🔲 Stub | Page exists; no send/receive logic |
| Notifications | 🔲 Stub | Page exists; no push integration |
| Profile view | ⚠️ Partial | Hardcoded fallback stats shown to user |
| Profile edit | 🔲 Stub | Page exists; untested |
| Verification upload | 🔲 Stub | Page exists; upload logic not wired |
| Reviews | 🔲 Stub | Page exists; submit logic not wired |
| Dark / light mode toggle | ✅ Real | Persisted via `shared_preferences` |

**Legend:** ✅ Real · ⚠️ Partial · 🔲 Stub

---

## 9. Code Quality Issues

| Issue | Location |
|---|---|
| Duplicated `_fmtDate()` date formatter | `jobs_page.dart` and `job_detail_page.dart` |
| Trade type strings hardcoded in widget | `jobs_page.dart:31` |
| Fallback profile strings shown to real users ('Pinnacle Construct', '12 345 678 901') | `profile_page.dart:237–240` |
| `_nameFromEmail`, `_initials` static methods belong in `core/utils/` | `profile_page.dart:96–110` |
| No overlay opacity token — `Colors.black45` hardcoded | `profile_page.dart:154` |
| `home_page.dart` imports 5+ sibling feature domain entities directly | `home_page.dart:13–20` |
| `AppColors` static fallback class duplicates `JColors.dark` values | `app_colors.dart:183–220` — remove once all files use `context.c` |

---

## 10. Developer Experience (DX) Gaps

| Gap | Impact |
|---|---|
| No CI/CD pipeline — no GitHub Actions workflow file | High — no automated lint/test gate on PRs |
| No logging framework — raw `debugPrint` scattered | Medium — no structured logs for debugging |
| No error message catalogue — error strings scattered across providers | Medium — inconsistent UX copy |
| Freezed blocked — manual `copyWith()` everywhere | Medium — boilerplate risk as models grow |
| No codegen run check — `.g.dart` files not tracked | Low — `json_serializable` models could go stale |
| `flutter analyze` not enforced pre-commit | Low — add via git hook or CI |

---

## 11. Recommendations (Prioritised)

### Critical
1. Add unit tests for all domain use cases — start with auth, jobs, applications.

### High
2. Replace `_mockJobs` in `jobs_page.dart` with real `jobsControllerProvider` data binding.
3. Create `lib/core/errors/error_messages.dart` — single `toMessage(Failure f)` function used by all providers.
4. Fix silent `catch (_)` blocks — at minimum log the error; propagate where recoverable.

### Medium
5. Implement `connectivity_plus` for an offline banner in `HomeShellPage`.
6. Add role-based route guards in GoRouter redirect (builder vs trade tab visibility).
7. Implement or remove the 13 unused packages — carry weight in app bundle.
8. Set up GitHub Actions with `flutter analyze` + `flutter test` on every PR.

### Low
9. Move `_nameFromEmail`, `_initials`, `_fmtDate` to `lib/core/utils/string_utils.dart`.
10. Extract route definitions into per-feature files (e.g. `features/jobs/jobs_routes.dart`).
11. Add `lottie` empty states to jobs feed, applications list, messages, notifications.
12. Remove `AppColors` / `AppDarkColors` static fallback classes once all widgets use `context.c`.
