# State Management Audit — Jobdun (Flutter)

> Date: **2026-05-22** (refactor pass applied same day)
> Branch: `feat/profile-improvements`
> Scope: every `presentation/providers/*` file, `app/theme/theme_provider.dart`, `app/router/app_router.dart`, plus how widgets consume the providers.
> Library: **Riverpod 3.3.1** (`flutter_riverpod`), no Bloc, no Provider, no GetIt.

## Refactor status (post-pass)

Pre-refactor rating: **6.5 / 10**. Post-refactor: **8 / 10**. AuthController god-class split and `.select()` / `AsyncValue` adoption are intentionally deferred — they need their own PRs.

| Audit finding | Status | Notes |
|---|---|---|
| `currentUserIdProvider` missing | ✅ Done | `lib/core/providers/current_user_provider.dart` — Stream + sync read |
| Private repo/datasource providers | ✅ Done | All renamed to public (`jobRepositoryProvider`, `profileRepositoryProvider`, etc.) |
| `ProfileController.saveProfile` Supabase bypass | ✅ Done | Now routes through `_repo.upsertBuilderProfile` / `upsertTradeProfile`; `tradeOther` added to entity + model |
| `NotificationsController` stub | ✅ Done | Wired to repo + 3 use cases, realtime watch, optimistic markRead/markAllRead |
| `ReviewsController` stub | ✅ Done | Wired to repo + 3 use cases (loadFor, submit) |
| `VerificationController` stub | ✅ Done | Wired to repo + 3 use cases, realtime watch |
| Use case layer was dead | ✅ Done | All active controllers route through existing use cases via `*UseCaseProvider`; `GetJobs` extended with `limit`/`offset` |
| File-size budget enforcement | ✅ Done | `analysis_options.yaml` + `scripts/validate.sh` hard ceiling at 500 LOC |
| AuthController god-class (1086 LOC) | 🟥 Deferred | Split into AuthSession/Email/OAuth/Phone notifiers — own PR |
| `addPostFrameCallback` page-side loads | 🟧 Partial | New stub controllers load in `build()`; old pages still use `addPostFrameCallback` — migrate as touched |
| `.select()` at hot read sites | 🟥 Deferred | Still only 3 across the app — per-widget pass |
| `AsyncValue<T>` per action | 🟥 Deferred | Still single `error: String?` + `isLoading` — architectural change |

---

## TL;DR

**Overall rating: 6.5 / 10.**

The bones are right — Riverpod 3, `NotifierProvider`, repo-backed controllers, `ProviderScope` bootstrap, realtime subscriptions cleaned up via `ref.onDispose`. But the execution is uneven:

- The **`auth_provider.dart` is a 1086-line god controller** doing session listening, JWT decoding, password/Google/Apple/phone sign-in, password reset, register draft, profile preload — should be 3-4 separate notifiers.
- Three feature notifiers (**`notifications`, `verification`, `reviews`**) are **dead stubs** — `build()` returns const state, no methods.
- The **`domain/usecases/` layer is bypassed**: 29 use-case files exist; **zero** are referenced by any provider. The data layer is called directly from controllers.
- **`ProfileController.saveProfile`** writes to Supabase directly (`SupabaseConfig.client.from(...)`) instead of going through the repo it already injected. Single inconsistency, but a tell.
- **~46 `setState` calls + 18 `addPostFrameCallback`/`Future.microtask` page-side load triggers** — initial data fetches live on the page, not on the provider. This is fragile (any new entry-point to the screen has to remember to re-trigger).
- Only **3 `ref.watch(provider.select(...))`** calls across the whole app — most screens re-render on every state-shape change.
- **0 provider/notifier unit tests** (26 test files exist, but they're widget/golden/use-case tests). Repo providers are `final _xRepositoryProvider = ...` (file-private), so even adding tests would need an API change.

What's solid: a single state library (no mixing), modern `Notifier<T>` API (not legacy `StateNotifier`), `autoDispose` where it matters (FTUE geo, family lookups), optimistic updates with rollback (`jobs.toggleSaveJob`), and a router that listens to `auth + ftue` state correctly.

---

## Inventory

13 provider files, 2367 lines combined.

| File | LOC | Type | Status |
|---|---:|---|---|
| `lib/features/auth/.../auth_provider.dart` | **1086** | `NotifierProvider<AuthController, AuthState>` | Active — god controller |
| `lib/features/profile/.../profile_provider.dart` | 342 | `NotifierProvider<ProfileController, ProfileState>` | Active — bypasses repo in `saveProfile` |
| `lib/features/jobs/.../jobs_provider.dart` | 299 | `NotifierProvider<JobsController, JobsState>` + 4 internal `Provider` | Active — best of the lot |
| `lib/features/messaging/.../messaging_provider.dart` | 187 | `NotifierProvider<MessagingController, MessagingState>` | Active |
| `lib/features/applications/.../applications_provider.dart` | 109 | `NotifierProvider<ApplicationsController, ApplicationsState>` | Active |
| `lib/features/legal/.../legal_provider.dart` | 84 | 4× `FutureProvider` + 2× `Provider` (functional style) | Active |
| `lib/features/ftue/.../ftue_gate_provider.dart` | 47 | `NotifierProvider<FtueGate, FtueGateState>` | Active |
| `lib/features/ftue/.../ftue_geo_provider.dart` | 41 | `FutureProvider.autoDispose<GeoResult?>` | Active |
| `lib/app/theme/theme_provider.dart` | 39 | `NotifierProvider<ThemeNotifier, ThemeMode>` | Active — bootstrap override |
| `lib/features/notifications/.../notifications_provider.dart` | **39** | `NotifierProvider` | **Stub — no methods** |
| `lib/features/reviews/.../reviews_provider.dart` | **37** | `NotifierProvider` | **Stub — no methods** |
| `lib/features/verification/.../verification_provider.dart` | **35** | `NotifierProvider` | **Stub — no methods** |
| `lib/features/profile/.../trade_categories_provider.dart` | 22 | `FutureProvider<List<TradeCategory>>` | Active — session-cached |

Plus one helper used by `GoRouter` (`_RouterNotifier extends ChangeNotifier`) in `app_router.dart:33`.

---

## Detailed findings

### 1. Library + version — **9 / 10**

- `flutter_riverpod: ^3.3.1` — current major. No legacy `StateNotifier`, no `ChangeNotifierProvider`. Uses `Notifier<T>` consistently.
- No competing state library in `pubspec.yaml` — Bloc/Provider/GetIt all absent despite CLAUDE.md mentioning Bloc as a fallback.
- **No code-gen** (`@riverpod` / `riverpod_annotation`). Hand-written providers everywhere. Means family params and dependencies aren't compile-time-checked. Not a defect, but you forfeit the strongest feature of Riverpod 3.

### 2. Architecture & layering — **6 / 10**

The shape is Clean Architecture:

```
presentation/providers ─→ Provider<Repository> ─→ data/repositories/*Impl ─→ data/datasources/* ─→ Supabase
                              ↑
                       domain/repositories/* (contract)
                              ↑
                       domain/usecases/*  ← UNUSED
```

Problems:

- **Use case layer is dead.** `find lib/features -path '*/domain/usecases/*' -name '*.dart'` returns 29 files, `grep` for `ref.read(...Usecase|UseCase` returns **0**. Controllers call `_repo.method()` directly. Either delete the use-case files, or route the controllers through them. Right now they are documentation of intent, not code.
- **One controller writes directly to Supabase**: `profile_provider.dart:101-137` in `saveProfile()` uses `SupabaseConfig.client.from('builder_profiles').upsert(...)` instead of `_repo.update(...)`. The repo *is* injected in the same class and used by every other method (`uploadAvatar`, `uploadTradeLicence`, `addPortfolioImage`). One outlier — move it.
- **Direct singleton access from providers**: 53 calls to `SupabaseConfig.client` inside `presentation/providers/*`. Most are `currentUser?.id`, which is reasonable, but it means controllers depend on the global singleton — overriding the auth client in tests is impossible without monkey-patching.
- **Private repo providers** (`final _jobRepositoryProvider`, `final _profileDatasourceProvider`, …) — file-scoped underscores. They cannot be overridden from outside the file, which precludes the standard Riverpod test pattern `ProviderContainer(overrides: [_jobRepositoryProvider.overrideWithValue(fake)])`.

### 3. Provider granularity — **5 / 10**

- **God state objects.** `AuthState` carries: `isAuthenticated`, `isLoading`, `email`, `role`, `onboardingComplete`, `isRoleLoaded`, `errorMessage`, `infoMessage`, `pendingVerificationEmail`, `registerDraft`, plus a `clearXxx` flag set in `copyWith`. Every screen that calls `ref.watch(authControllerProvider)` rebuilds when *any* of those change.
- **Only 3 `.select(...)` call sites in the whole codebase.** `grep -rEn "\\.select\\(" lib | wc -l` → 3. So when the loading spinner flips on the login page, the home tab, the splash route, and the router all rebuild too.
- **AsyncValue isn't used for action results.** Controllers store `String? error` and `bool isLoading` on the state instead of returning `AsyncValue<T>` per action. That makes per-button error/loading impossible to render correctly — a global error wipes the previous one even if it came from a different action.

### 4. Lifecycle & disposal — **8 / 10**

- `ref.onDispose(...)` is used correctly to cancel stream subscriptions in `auth`, `messaging`, and `jobs`. No leaks observed.
- `FutureProvider.autoDispose` for the FTUE IP-geo lookup (the comment even calls out *why*: don't leak IP data past the carousel). Good instinct.
- `jobs_provider.dart` lazily allocates its `PagingController` so the home mini-feed doesn't pay the listener cost. Genuinely thoughtful.
- One nit: `_pagingController?.dispose()` is called in `onDispose`, but the controller is created from a getter — if multiple readers race the getter pre-`build()`, you could theoretically leak. In practice `build()` runs first, so safe.

### 5. Side effects & initial-load pattern — **5 / 10**

- **18 page-side `addPostFrameCallback`/`Future.microtask` calls** to trigger initial loads (`home_page`, `jobs_page`, `applications_page`, `messages_page`, `profile_page`, `verification_page`, `auth/login_page`, etc.). The provider doesn't load itself when first read — the page has to remember to kick it. Any new entry point (deep link, push-notification handler, tab restore) has to repeat the same `addPostFrameCallback` boilerplate, and the first frame paints empty state.
- The cleanest counter-example is the same file you're worried about: `ftue_gate_provider.dart:19` does `Future.microtask(_load)` *inside* `build()`. That pattern is correct — the load happens once when the provider is first observed, regardless of which screen reads it.
- Recommendation: move first-load into `build()` for `profile`, `jobs`, `applications`, `messaging` (gated on `auth.isAuthenticated`).

### 6. Error handling — **6 / 10**

- Pattern is `state = state.copyWith(error: f.message)` everywhere. Single `String? error` per state. Snackbar listeners then pick it up via `ref.listen`.
- `copyWith(error: error)` *always* overwrites with the supplied value (including null), so an error from action A is silently wiped when action B starts. Often you want this; sometimes you don't.
- `fpdart`'s `Either<Failure, T>` is used at the repo boundary, then immediately collapsed to `String?` at the controller. Information loss — UI can't distinguish `NetworkFailure` from `AuthFailure` to decide whether to retry, sign out, or both.
- `ErrorMessages.from(failure)` is correctly used in `auth_provider.dart` but nowhere else.

### 7. Testability — **4 / 10**

- **No provider unit tests.** `find test -name "*provider*test*.dart"` → 0. The 26 test files cover widgets, golden, FTUE flow, legal flow, and *domain* use-cases (which the providers don't call).
- Repo providers are private (`_jobRepositoryProvider`), so overriding them requires either making them public or exporting them.
- Controllers call `SupabaseConfig.client.auth.currentUser?.id` directly — to fake the current user in a test, you'd have to fully initialise Supabase. There's no `currentUserIdProvider` to override.
- `AuthController` also dials directly into `GoogleSignIn` and `SignInWithApple` SDKs — these are not injected.

### 8. Completeness — **5 / 10**

Three feature notifiers exist only as skeletons:

```dart
// reviews_provider.dart, verification_provider.dart, notifications_provider.dart
class ReviewsController extends Notifier<ReviewsState> {
  @override
  ReviewsState build() => const ReviewsState();
}
```

No load, no mutate, no realtime — yet UI surfaces (notifications bell, verification page, reviews tab) presumably need them. Either they're being driven from another provider (in which case delete these), or they're actively used and just empty (in which case they'll break silently when state never updates).

### 9. Realtime / streaming — **8 / 10**

- `messaging_provider.dart` watches both conversation list and per-thread message stream, keyed by `conversationId`. Each subscription is tracked in a map and cancelled individually via `unsubscribeMessages`. Good.
- `jobs_provider.dart:watchBuilderJobs` does the same for the builder's own posted jobs.
- Both controllers cancel-all in `onDispose`. Solid.
- Optimistic mutations + rollback in `toggleSaveJob`, `hideJob`, `archiveConversation` — server reconciles via the realtime watch. This is the right pattern; matches the `swipe_actions` migration philosophy.

### 10. Bootstrap & persistence — **8 / 10**

- `main.dart` awaits `loadSavedTheme()` *before* `runApp`, then injects via `ProviderScope.overrides`. No light→dark flash on first frame. Clean.
- `flutter_dotenv` env load + `SupabaseConfig.initialize()` happen pre-`runApp`. No race between provider `build()` and Supabase init (each provider also checks `SupabaseConfig.isInitialized` defensively).
- Router is itself a `Provider<GoRouter>` and listens to `auth + ftue` via `ref.listen` — refreshes on auth state transitions without manual `notifyListeners()` plumbing.
- `SharedPreferences` is read once for theme, once for FTUE gate. No `Hive` / drift / persisted state beyond that, which is fine for the current feature set.

---

## Scoring summary

| Axis | Score | Notes |
|---|---:|---|
| 1. Library + version | 9 | Riverpod 3 only, modern Notifier API |
| 2. Architecture & layering | 6 | Use-case layer is dead; one repo bypass |
| 3. Provider granularity | 5 | God state objects; ~3 `.select` calls |
| 4. Lifecycle & disposal | 8 | Good `onDispose`, justified `autoDispose` |
| 5. Initial-load pattern | 5 | 18 page-side `addPostFrameCallback` triggers |
| 6. Error handling | 6 | Single `String?` per state, fpdart info loss |
| 7. Testability | 4 | 0 provider tests, private repo providers |
| 8. Completeness | 5 | 3 notifiers are empty stubs |
| 9. Realtime / streams | 8 | Subscriptions tracked + cancelled correctly |
| 10. Bootstrap | 8 | Theme + Supabase init order is clean |

**Weighted overall: 6.5 / 10.**

---

## Recommended fix order

### Quick wins (1–2 hrs each)

1. **Move `ProfileController.saveProfile` Supabase calls into `ProfileRepositoryImpl`** (or `ProfileRemoteDataSourceImpl`). Match the pattern of the other ProfileController methods. — file: `lib/features/profile/presentation/providers/profile_provider.dart:99-151`.
2. **Delete or wire up the three stub notifiers.** If `notifications`, `reviews`, `verification` UIs are using `applicationsControllerProvider` / `profileControllerProvider` instead, delete the stubs. If they're going to be filled in for Sprint P6+, add a `// TODO(P6)` comment so they're not mistaken for finished work.
3. **Make repo providers package-public** (drop the leading `_`). Required for any future provider tests. No behaviour change.
4. **Introduce a `currentUserIdProvider`** that wraps `SupabaseConfig.client.auth.currentUser?.id` so controllers can `ref.watch(currentUserIdProvider)` and tests can override it.

### Medium (half-day each)

5. **Split `AuthController`.** Suggested cut: `AuthSessionNotifier` (session + JWT + role), `EmailAuthNotifier` (signIn/register/forgotPassword/verifyEmail), `OAuthNotifier` (Google/Apple), `PhoneAuthNotifier` (OTP). 1086-line files cost reviewer attention every time auth touches a PR.
6. **Move first-load into `build()`** for `jobs`, `applications`, `messaging`, `profile`. Pattern from `ftue_gate_provider.dart:19` — `Future.microtask(_load)` inside `build()`, gated on `auth.isAuthenticated`. Removes the page-side `addPostFrameCallback` boilerplate.
7. **Add `.select(...)` at hot read sites.** Start with the bottom-nav badge (`messaging.totalUnread`) and the home banner (`profile.profileCompletenessPct`). One-line change per call site, measurable rebuild reduction.

### Bigger (1–2 days)

8. **Decide on the use-case layer**: either delete `domain/usecases/*` (29 files) or route controllers through them. Half-built layers rot.
9. **Write provider tests** with `ProviderContainer + overrides`. Start with `JobsController` (the most logic) and `AuthController` (highest blast radius). Use fakes injected via the now-public repo providers.
10. **Adopt `riverpod_annotation`** for new providers. Family parameters get compile-time checked, dependencies are declared explicitly, and code-gen handles `autoDispose` correctly.

---

## What I would NOT change

- Riverpod 3 vs. Bloc — Riverpod fits the codebase, the team's commit history (`feat(profile): Sprint P5`), and the realtime/stream patterns better than Bloc would.
- `Notifier<T>` over `AsyncNotifier<T>` for the active controllers — the controllers manage multi-field state (loading + data + error + paging), and `AsyncValue<T>` would force you to collapse that into one async slot. The right move is per-action AsyncValues *inside* a synchronous Notifier state, not switching the whole thing.
- Theme bootstrap (`loadSavedTheme` + `ProviderScope.overrides`) — exactly the right way to avoid first-paint flicker.
- Optimistic + rollback pattern in `jobs` / `messaging` — this is the gold standard for the swipe interactions the app relies on.
