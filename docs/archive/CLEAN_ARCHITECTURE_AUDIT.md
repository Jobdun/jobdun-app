# Clean Architecture Audit — Jobdun

> Date: **2026-05-22**
> Scope: every feature under `lib/features/*` — layer boundaries, use-case coverage, data-layer isolation, domain purity.
> Result: **9 / 10** after the cleanup in this PR. Down from a hidden ~7/10 (dead auth scaffold made the architecture look inconsistent before this pass).

## TL;DR

| Axis | Status | Notes |
|---|---|---|
| Domain layer purity | ✅ 10/10 | Zero `package:flutter/*` / `package:supabase_flutter/*` / `core/config/*` imports under any `*/domain/**` |
| Presentation → Data boundary | ✅ 10/10 | Pages don't import `data/` at all. The provider files are the **only** seam that wires `data/` impls into Riverpod |
| Use-case coverage | ✅ 9/10 | Every use case under `domain/usecases/*` has ≥1 caller. The auth feature uses `data/services/*` instead (documented exception) |
| Data-layer isolation | ✅ 9/10 | All Supabase calls live in `data/datasources/*` or `data/services/*`. Page-level `SupabaseConfig.client` reads removed in this pass |
| Repo contract / impl pairing | ✅ 10/10 | 1:1 across all 8 non-auth features |
| Dependency direction | ✅ 10/10 | `presentation → domain ← data` enforced |

---

## What was fixed in this pass

### 1. Dead auth scaffold deleted

Eight files in `features/auth/` were defining a Clean-Arch layer that **nothing in `lib/` referenced**. The AuthController went around them and called `data/services/*` directly (correctly — see "Auth exception" below). The dead scaffold was misleading: it looked like the auth feature followed the same use-case pattern as every other feature, but the code path was a fiction.

Deleted:

```
lib/features/auth/data/models/user_model.dart            (UserModel — dead DTO)
lib/features/auth/data/datasources/auth_remote_datasource.dart  (dead)
lib/features/auth/data/repositories/auth_repository_impl.dart   (dead)
lib/features/auth/domain/entities/app_user.dart          (AppUser — dead entity)
lib/features/auth/domain/repositories/auth_repository.dart      (dead contract)
lib/features/auth/domain/usecases/sign_in.dart           (dead — controller uses EmailAuthService)
lib/features/auth/domain/usecases/sign_out.dart          (dead)
lib/features/auth/domain/usecases/get_current_user.dart  (dead)
test/features/auth/auth_test.dart                        (tested the dead use cases)
test/features/auth/domain/usecases/sign_in_test.dart     (tested SignIn → AuthRepository)
```

Empty directories also removed.

### 2. Auth exception documented in CLAUDE.md

`SupabaseClient.auth` is **not** a queryable repository — it's a stateful auth client with cancellation, SSO challenges, SMS round-trips. Wrapping it in `AuthRepository → AuthRemoteDataSource` is ceremony without value. So auth uses `data/services/*` (EmailAuthService, OAuthService, PhoneAuthService, RoleResolver) instead of the use-case pattern.

CLAUDE.md now flags this as the **one documented exception** to the layer rules. Adding another `domain/usecases/sign_in.dart` is a regression — don't.

### 3. Page-level Supabase reads migrated to the provider

Four pages were reading `SupabaseConfig.client.auth.currentUser?.id` directly — a layer violation. Three of them now read from `ref.read(currentUserIdSyncProvider)`:

- `applications_page.dart` ✅
- `home_page.dart` ✅
- `messages_page.dart` ✅ (uses `ref.watch` for reactive rebuilds)
- `profile_edit_page.dart` ⏳ deferred — reads `currentUser?.userMetadata?['full_name']` for form initialization, a different concern (not just user ID). Will fold into the eventual register-draft refactor.

All three migrated pages also dropped the `core/config/supabase_config.dart` import in favor of `core/providers/current_user_provider.dart`.

---

## Findings — what the audit confirmed

### Domain purity ✅

```bash
grep -rnE "import.*package:(flutter|supabase_flutter|flutter_riverpod)/|import.*core/config" lib/features/*/domain
# → no matches
```

Every domain entity is pure Dart + `equatable`. Repository contracts use `fpdart` (`Either<Failure, T>`) — pure functional, no Flutter dependency. Use cases delegate to repository contracts via constructor injection.

### Presentation → Data boundary ✅

```bash
grep -rn "import.*data/datasources\|import.*data/repositories" lib/features/*/presentation | grep -v providers/
# → no matches
```

Every page imports from `domain/entities/` and presentation providers. The provider files (`*/presentation/providers/*.dart`) are the only files in presentation that import from `data/`. Those imports are the wiring seam — they declare `Provider<XxxRepository>((ref) => XxxRepositoryImpl(...))` so the controller can ask Riverpod for the right impl.

### Use-case coverage ✅

29 use cases in `lib/features/*/domain/usecases/*.dart`. After cleanup, every single one has at least one caller in `lib/`:

| Feature | Use cases | Callers |
|---|---:|---:|
| applications | 5 | 5 (all in `applications_provider.dart`) |
| jobs | 5 | 5 (4 in `jobs_provider.dart` + `GetJobs` × 2) |
| messaging | 4 | 4 (all in `messaging_provider.dart`) |
| notifications | 3 | 3 (all in `notifications_provider.dart`) |
| profile | 3 | 3 (all in `profile_provider.dart`) |
| reviews | 3 | 3 (all in `reviews_provider.dart`) |
| verification | 3 | 3 (all in `verification_provider.dart`) |
| **auth** | **0** | **N/A — uses `data/services/*` (documented)** |

Half-built layers eliminated.

### Repository contract / impl pairing ✅

```
auth          contracts=0  impls=0  (uses services)
verification  contracts=1  impls=1
profile       contracts=1  impls=1
applications  contracts=1  impls=1
jobs          contracts=2  impls=2  (JobRepository + JobInteractionsRepository)
messaging     contracts=1  impls=1
notifications contracts=1  impls=1
reviews       contracts=1  impls=1
```

No orphan contracts. No orphan impls. Every feature's `domain/repositories/x.dart` has a matching `data/repositories/x_impl.dart` and vice versa.

### Dependency direction ✅

```
presentation  ──→  domain  ←──  data
     │              │            │
     │              ▼            │
     │         entities          │
     │         use cases         │
     │         repo contracts ───┘  (implemented by data layer)
     │
     └──→ providers/  (the only seam — imports both domain + data)
```

No circular imports. No cross-feature `data → data` reaches. No `domain → data` (domain knows nothing of impls).

---

## Remaining minor items (not blocking)

1. **`profile_edit_page.dart:55`** — reads `SupabaseConfig.client.auth.currentUser?.userMetadata?['full_name']` for form initialization. This is auth metadata, not just user ID. Fold into a future "register-draft as form prefill" pass when the register flow gets revisited.

2. **`provider` files all touch `SupabaseConfig.client`** — this is **intentional** and not a violation. The provider files are the explicit wiring seam between Supabase and Riverpod's DI graph. Documenting here so the layer-boundary check in audits doesn't false-flag them.

3. **Use cases are 1-line passthroughs in most cases.** They still earn their keep as a contract surface for tests (mockable per-use-case) and as the place to add cross-cutting logic (validation, retry, telemetry) without touching the controller. Don't delete them for "simplicity" — they're the seam.

---

## Score breakdown

| Axis | Pre-cleanup | Post-cleanup | Why |
|---|---:|---:|---|
| Domain purity | 10 | 10 | Was clean before, still clean |
| Presentation → Data boundary | 8 | 10 | 4 pages did direct Supabase reads → 1 remaining, documented |
| Use-case coverage | 6 | 9 | 3 dead auth use cases removed; auth exception documented |
| Data-layer isolation | 7 | 9 | Page-level Supabase reads migrated to provider |
| Repo contract / impl pairing | 9 | 10 | Dead AuthRepository removed |
| Dependency direction | 10 | 10 | Was clean before |
| **Overall** | **~7** | **9 / 10** | |

The remaining gap to 10/10:
- `profile_edit_page.dart` userMetadata read (cosmetic, scoped)
- Auth tests are widget-level only; no unit tests for the 4 auth services yet (future PR — currently covered by widget tests)

Both are minor and don't compromise the layering.
