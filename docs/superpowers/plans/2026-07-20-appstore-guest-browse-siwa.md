# App Store Rejection Fixes — Guest Job Browsing (5.1.1(v)) + Sign in with Apple (Guideline 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve both findings from Apple's 2026-07-15 rejection of build 1.0 (4): (1) let unauthenticated users browse posted jobs (list, search, filter, detail) without an account, and (2) never ask a Sign-in-with-Apple user for their name or email after authentication.

**Architecture:** Guest browsing rides the existing jobs feed pipeline: a new anon-granted Postgres view (`jobs_public_browse`, mirroring the `trade_profiles_public` owner-semantics pattern — curated columns, coords rounded to 2 dp, no exact address/place_id) is selected by the existing datasource when there is no session; the router gains a public `/browse` route (standalone `JobsPage` reuse) plus guest-allowed `/jobs/:id`, and account-only actions (Apply, save/hide, builder profile) open a `GuestGateSheet` that routes to sign-in/register and returns the user to the job afterwards. The SIWA fix makes the onboarding completion sheet provider-aware: Apple/Google users never see the name step; the name captured from the Apple credential (already written to `user_metadata` by `OAuthService`) is persisted to `profiles` when the role step completes.

**Tech Stack:** Flutter + Riverpod 3 (Notifier), GoRouter, Supabase (RLS + view grants, `supabase db push` to project `zethpanvkfyijislxesn`), fpdart, existing design system (`showJSheet`, `JButton`, tokens from `design-system/jobdun/MASTER.md`).

**Root causes (verified 2026-07-20):**
- `lib/app/router/app_router.dart:104-117` — unauthenticated users redirect to `/login` for everything outside a small `publicRoutes` set; `/jobs*` is not in it.
- `supabase/migrations/20260511000006_rls.sql:139` — `jobs_select_open` requires `auth.role() = 'authenticated'`; `supabase/functions/jobs-feed/index.ts` 401s without a user JWT.
- Native Apple sign-in: the ID token carries no name → `handle_new_user` (INSERT-only trigger, `20260527000006`) creates a nameless profile → `OAuthService.signInWithApple` writes the credential name to `user_metadata` *after* the insert, nothing syncs it to `profiles` → `OnboardingGate.needsCompletion` (`!hasRole || needsName`) opens the non-dismissible `OnboardingCompletionSheet`, whose `_onFinish` hard-requires a name ("Tell us your name to finish.").

**Explicit scope decisions:**
- Guest surface = `/browse` (list + search + trade filters) and `/jobs/:id` detail. The jobs map stays authenticated: its only entry point is the authenticated Home tile, and Apple's finding names "accessing/browsing posted jobs" only.
- `jobs-feed` Edge Function stays authenticated-only; guests skip the server cache and read the view directly (bounded first-page traffic; Upstash cache remains an authenticated optimisation).
- The name step remains for phone-OTP signups (no name source; not covered by Apple's SIWA rule). Email signups collect the name at registration, unchanged.
- Apple user whose credential carried no name (user manually cleared the fields): role-only completion, profile stays nameless, the existing ProfileCompletenessBanner nudges later. No forced entry.

---

### Task 1: Branch + failing tests for the provider-aware onboarding gate

**Files:**
- Modify: `test/features/auth/onboarding_gate_test.dart` (extend; if the actual path differs, `grep -rl OnboardingGate test/`)
- Modify: `lib/features/auth/presentation/widgets/onboarding_gate.dart`

- [ ] **Step 1: Create the working branch off develop**

```bash
git checkout -b fix/appstore-guest-browse-siwa develop
```

- [ ] **Step 2: Write failing tests for the new gate contract**

New contract: name is only required from providers that don't supply one (email/phone). For `apple`/`google` identities, a missing display name never forces completion; a missing role still does. `metadataName` (from `user_metadata.full_name`) counts as having a name.

```dart
// Append to the existing group in the OnboardingGate test file:
test('apple user with role and no name anywhere does not need completion', () {
  expect(
    OnboardingGate.needsCompletion(
      hasProfile: true,
      hasRole: true,
      displayName: null,
      metadataName: null,
      ssoNameProvider: true,
    ),
    isFalse,
  );
});

test('apple user without role still needs completion (role step only)', () {
  expect(
    OnboardingGate.needsCompletion(
      hasProfile: true,
      hasRole: false,
      displayName: null,
      metadataName: null,
      ssoNameProvider: true,
    ),
    isTrue,
  );
});

test('metadata name satisfies the name requirement for email/phone users', () {
  expect(
    OnboardingGate.needsCompletion(
      hasProfile: true,
      hasRole: true,
      displayName: null,
      metadataName: 'Kel Tradie',
      ssoNameProvider: false,
    ),
    isFalse,
  );
});

test('phone user with role but no name still needs completion', () {
  expect(
    OnboardingGate.needsCompletion(
      hasProfile: true,
      hasRole: true,
      displayName: ' ',
      metadataName: null,
      ssoNameProvider: false,
    ),
    isTrue,
  );
});
```

- [ ] **Step 3: Run to verify failure** — `flutter test <gate test file>` → compile error (named params don't exist).

- [ ] **Step 4: Implement the gate change**

```dart
static bool needsCompletion({
  required bool hasProfile,
  required bool hasRole,
  required String? displayName,
  String? metadataName,
  bool ssoNameProvider = false,
}) {
  if (!hasProfile) return false;
  final hasAnyName = (displayName ?? '').trim().isNotEmpty ||
      (metadataName ?? '').trim().isNotEmpty;
  // Apple/Google supplied identity at auth time — never re-ask for a name
  // (App Review Guideline 4 / SIWA HIG). Phone/email may still be prompted.
  final needsName = !hasAnyName && !ssoNameProvider;
  return !hasRole || needsName;
}
```

- [ ] **Step 5: Run tests (old + new) → PASS. Commit** — `fix(auth): gate never demands a name from SSO-name providers`

### Task 2: AuthState carries `signInProvider` + `metadataDisplayName`

**Files:**
- Modify: `lib/features/auth/presentation/providers/auth_state.dart` (add two fields + copyWith)
- Modify: `lib/features/auth/presentation/providers/auth_provider.dart` (populate in `build()` cold-start and in the `onAuthStateChange` listener from `session.user`)
- Test: extend the existing auth controller/state test file

- [ ] **Step 1: Failing test** — seed a fake `User` map isn't feasible without Supabase; instead unit-test the pure mapper.

Create `lib/features/auth/data/services/sso_identity.dart`:

```dart
/// Pure helpers reading SSO identity facts off a Supabase [User].
/// Kept free of Flutter imports so they unit-test without a client.
class SsoIdentity {
  const SsoIdentity._();

  /// True when any linked identity provider supplies the user's name at
  /// auth time (Apple/Google) — those users must never be re-asked (G4).
  static bool hasNameProvider(Map<String, dynamic> appMetadata) {
    final providers = (appMetadata['providers'] as List?)?.cast<String>() ??
        [if (appMetadata['provider'] is String) appMetadata['provider'] as String];
    return providers.any((p) => p == 'apple' || p == 'google');
  }

  /// Best-effort display name from user_metadata (all key shapes the
  /// handle_new_user trigger recognises — see 20260527000006).
  static String? metadataDisplayName(Map<String, dynamic>? userMetadata) {
    final m = userMetadata ?? const {};
    String? clean(Object? v) {
      final s = (v is String) ? v.trim() : null;
      return (s == null || s.isEmpty) ? null : s;
    }
    final composedGiven = [m['given_name'], m['family_name']]
        .map(clean).whereType<String>().join(' ');
    final nested = m['name'];
    final composedNested = nested is Map
        ? [nested['firstName'], nested['lastName']]
            .map(clean).whereType<String>().join(' ')
        : '';
    return clean(m['full_name']) ??
        (nested is String ? clean(nested) : null) ??
        clean(composedGiven) ??
        clean(composedNested);
  }
}
```

Test (`test/features/auth/sso_identity_test.dart`): providers list containing `apple` → true; `["email"]` → false; metadata shapes `full_name`, `name` string, `given_name`+`family_name`, Apple nested `{"name":{"firstName":"A","lastName":"B"}}` → expected strings; empty → null.

- [ ] **Step 2: Run → fails (file missing). Implement (code above). Run → PASS.**

- [ ] **Step 3: Thread into AuthState + controller**

`auth_state.dart`: add `final bool ssoNameProvider;` and `final String? metadataDisplayName;` (default `false`/`null`) to the constructor and `copyWith` following the file's existing pattern.

`auth_provider.dart` — in the `onAuthStateChange` listener and the cold-start session branch of `build()`, add to the `copyWith`/constructor:

```dart
ssoNameProvider: SsoIdentity.hasNameProvider(session.user.appMetadata),
metadataDisplayName: SsoIdentity.metadataDisplayName(session.user.userMetadata),
```

(cold start uses `user!.appMetadata` / `user.userMetadata`).

- [ ] **Step 4: `flutter analyze` clean. Commit** — `feat(auth): expose SSO identity facts on AuthState`

### Task 3: Provider-aware completion sheet (role-only for Apple/Google) + home gate wiring

**Files:**
- Create: `lib/features/auth/presentation/widgets/onboarding_step_plan.dart`
- Test: `test/features/auth/onboarding_step_plan_test.dart`
- Modify: `lib/features/auth/presentation/widgets/onboarding_completion_sheet.dart`
- Modify: `lib/features/auth/presentation/widgets/onboarding_progress_row.dart` (dot count from step total)
- Modify: `lib/features/auth/presentation/providers/auth_provider.dart` (`completeOnboarding` displayName → `String?`)
- Modify: `lib/features/home/presentation/pages/home_page.dart:156-161` (pass new gate params)

- [ ] **Step 1: Failing tests for the pure step plan**

```dart
enum OnboardingStep { role, name, avatar }

/// Which steps the completion sheet shows. Pure so it unit-tests.
/// Name only appears when we truly have no name AND the provider doesn't
/// supply one (G4: Apple/Google users are never re-asked).
class OnboardingStepPlan {
  const OnboardingStepPlan._();

  static List<OnboardingStep> compute({
    required bool hasRole,
    required String? effectiveName,
    required bool ssoNameProvider,
  }) {
    final needsName =
        (effectiveName ?? '').trim().isEmpty && !ssoNameProvider;
    return [
      if (!hasRole) OnboardingStep.role,
      if (needsName) OnboardingStep.name,
      OnboardingStep.avatar,
    ];
  }
}
```

Tests: apple/no-role/no-name → `[role, avatar]`; phone/no-role/no-name → `[role, name, avatar]`; email/hasRole/no-name → `[name, avatar]`; any/hasRole/hasName → `[avatar]`.

- [ ] **Step 2: Run → fail. Implement. Run → PASS. Commit** — `feat(auth): pure onboarding step plan`

- [ ] **Step 3: Rework the sheet around the plan**

In `onboarding_completion_sheet.dart`:
- `initState`: `effectiveName = profile?.displayName ?? auth.metadataDisplayName`; prefill `_nameController` with it; compute `_steps = OnboardingStepPlan.compute(...)`; `_step` indexes into `_steps` (start 0).
- `PageView` children built from `_steps` (`role` → `OnboardingRoleStep`, `name` → `OnboardingNameStep`, `avatar` → `OnboardingAvatarStep`); `OnboardingProgressRow(step: _step, total: _steps.length)`.
- `_onPickRole` advances to the next step in `_steps` (not hardcoded index 1).
- `_onFinish`: role required as before; name required **only if `_steps.contains(OnboardingStep.name)`**; otherwise `displayName: effectiveName` (nullable). Call `completeOnboarding(role: role, displayName: name.isEmpty ? null : name)`.
- `completeOnboarding` signature: `String? displayName`; pass through (RoleResolver already skips null/empty).
- `onboarding_progress_row.dart`: add `total` param (default 3), render `total` dots.

- [ ] **Step 4: Home gate call site** (`home_page.dart` ~157):

```dart
final shouldShow = OnboardingGate.needsCompletion(
  hasProfile: profile != null,
  hasRole: refreshed.role != null,
  displayName: profile?.displayName,
  metadataName: refreshed.metadataDisplayName,
  ssoNameProvider: refreshed.ssoNameProvider,
);
```

and the `needsName` local mirrors the gate (`hasAnyName || ssoNameProvider`).

- [ ] **Step 5: Controller test** — override `roleResolverProvider` with a mocktail mock; `completeOnboarding(role: trade, displayName: null)` → verifies `setRoleAndStubProfile` called with `displayName: null` and returns true. Run full auth test dir → PASS.

- [ ] **Step 6: Commit** — `fix(auth): Apple/Google onboarding is role-only — never re-asks name (G4)`

### Task 4: DB — `jobs_public_browse` view, granted to anon (+ rollback, push, live verify)

**Files:**
- Create: `supabase/migrations/20260720000001_jobs_public_browse.sql`
- Create: `supabase/rollbacks/20260720000001_jobs_public_browse_down.sql`

- [ ] **Step 1: Confirm the jobs column list** — `grep -n "CREATE TABLE.*jobs" -A 60 supabase/migrations/*create*jobs*.sql` (or schema.sql) and adjust the column list below if any name differs.

- [ ] **Step 2: Write the migration**

```sql
-- App Review 5.1.1(v): guests must be able to browse posted jobs without an
-- account. Same owner-semantics curated-view pattern as trade_profiles_public
-- (20260611000004): explicit safe columns only, coordinates rounded to 2 dp
-- (~1.1 km) so map pins stay approximate, exact address + place_id withheld.
-- deleted_at is projected as constant NULL so the app's shared query shape
-- (`deleted_at=is.null`) works unchanged against table and view.
BEGIN;

CREATE OR REPLACE VIEW public.jobs_public_browse AS
SELECT
  j.id, j.builder_id, j.title, j.description,
  j.suburb, j.state, j.postcode,
  j.trade_type_required, j.budget_amount, j.pricing_unit, j.pricing_type,
  j.urgency, j.requires_verified, j.requires_white_card,
  j.requires_public_liability, j.required_certifications,
  j.start_date, j.estimated_duration_days, j.duration_text,
  j.application_count, j.view_count,
  j.status, j.published_at, j.created_at, j.updated_at,
  round(j.latitude::numeric, 2)::double precision  AS latitude,
  round(j.longitude::numeric, 2)::double precision AS longitude,
  NULLIF(concat_ws(', ', j.suburb, j.state), '')   AS formatted_address,
  NULL::text        AS place_id,
  NULL::timestamptz AS deleted_at,
  j.search_vector
FROM public.jobs j
WHERE j.status IN ('open', 'filled') AND j.deleted_at IS NULL;

GRANT SELECT ON public.jobs_public_browse TO anon, authenticated;

COMMIT;
```

Rollback: `DROP VIEW IF EXISTS public.jobs_public_browse;`

- [ ] **Step 3: Confirm linked project ref is `zethpanvkfyijislxesn`** (`supabase migration list` header / `supabase link` state) — two projects are linked on this machine; never push to the other.

- [ ] **Step 4: `supabase db push`**, then live-verify with the anon key from `.env`:
  - `curl "$SUPABASE_URL/rest/v1/jobs_public_browse?select=id,title,latitude&limit=3" -H "apikey: $ANON"` → 200 + rows, coords 2 dp.
  - `curl "$SUPABASE_URL/rest/v1/jobs?select=id&limit=1" -H "apikey: $ANON"` → `[]` (RLS still blocks the base table for anon).

- [ ] **Step 5: Commit** — `feat(db): anon-readable jobs_public_browse view (App Review 5.1.1v)`

### Task 5: Data layer — guest read path

**Files:**
- Modify: `lib/features/jobs/data/datasources/job_remote_datasource.dart` (`getJobs` + `getJobById` read from `_readTable`)
- Modify: `lib/features/jobs/data/datasources/job_feed_cache_datasource.dart` (fast-fail when no session)
- Test: `test/features/jobs/guest_read_path_test.dart` (+ extend the JobModel/feed-columns regression test with a view-shaped row)

- [ ] **Step 1: Failing tests**

```dart
// A real SupabaseClient with no session — never touches the network in these tests.
final client = SupabaseClient('http://localhost:54321', 'anon-key');

test('feed cache datasource fast-fails without a session', () async {
  final ds = JobFeedCacheDataSourceImpl(client);
  await expectLater(ds.getFirstPage(limit: 20), throwsA(isA<ServerException>()));
});

test('JobModel parses a jobs_public_browse row (null place_id, composite address)', () {
  final row = { /* id, builder_id, title, description, created_at, updated_at + view fields, place_id: null, formatted_address: 'Parramatta, NSW' */ };
  final m = JobModel.fromJson(row);
  expect(m.placeId, isNull);
  expect(m.formattedAddress, 'Parramatta, NSW');
});
```

- [ ] **Step 2: Implement**

`job_remote_datasource.dart`:

```dart
// Guests read the anon-granted curated view; signed-in users read the base
// table under RLS. The view projects deleted_at as NULL so the shared
// `deleted_at=is.null` filter below works against both.
String get _readTable =>
    _client.auth.currentSession == null ? 'jobs_public_browse' : 'jobs';
```

`getJobs`: `.from(_readTable)`; `getJobById`: `.from(_readTable)`. Builder/write paths unchanged (`'jobs'`).

`job_feed_cache_datasource.dart` — first line of `getFirstPage`:

```dart
// The jobs-feed Edge Function requires a user JWT; guests skip the shared
// cache entirely and fall through to the direct view read in the repo.
if (_client.auth.currentSession == null) {
  throw const ServerException('feed cache requires an authenticated session');
}
```

(match the file's existing ServerException constructor shape).

- [ ] **Step 3: Tests PASS; `flutter analyze`; commit** — `feat(jobs): guest read path via jobs_public_browse`

### Task 6: Router — public `/browse` + guest `/jobs/:id` + pending-return

**Files:**
- Create: `lib/core/providers/pending_return_provider.dart`
- Create: `lib/features/jobs/presentation/pages/job_detail_loader_page.dart`
- Modify: `lib/app/router/app_router.dart`
- Modify: `lib/features/jobs/presentation/providers/jobs_provider.dart` (add `jobByIdProvider`)
- Test: `test/app/guest_routing_test.dart`

- [ ] **Step 1: pending-return provider (with test)**

```dart
/// Where to send the user after they authenticate from a guest gate —
/// e.g. the job they were reading when they tapped APPLY. Consumed once
/// by the router's auth-page redirect; cleared on sign-out.
final pendingReturnProvider =
    NotifierProvider<PendingReturnNotifier, String?>(PendingReturnNotifier.new);

class PendingReturnNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String location) => state = location;
  void clear() => state = null;
  String? consume() {
    final v = state;
    state = null;
    return v;
  }
}
```

- [ ] **Step 2: Router changes**

```dart
// Guest-browsable locations (App Review 5.1.1(v)): the public job browser
// and single job details. Everything account-based stays login-gated.
bool _isGuestBrowsable(String location) {
  if (location == '/browse') return true;
  if (location.startsWith('/jobs/')) {
    final rest = location.substring('/jobs/'.length);
    return rest.isNotEmpty &&
        !rest.contains('/') &&
        rest != 'create' &&
        rest != 'map';
  }
  return false;
}
```

- Unauthenticated branch: `return publicRoutes.contains(location) || _isGuestBrowsable(location) ? null : '/login';`
- Auth-pages branch:

```dart
if (authPages.contains(location)) {
  final pending = ref.read(pendingReturnProvider.notifier).consume();
  return pending ?? '/home';
}
```

- In the existing `ref.listen<AuthState>` at the top: when `!next.isAuthenticated`, `ref.read(pendingReturnProvider.notifier).clear();`
- New route before the shell: `GoRoute(path: '/browse', builder: (_, _) => const JobsPage()),`
- `/jobs/:id` builder falls back to fetch-by-id instead of JobsPage:

```dart
builder: (context, state) {
  final args = state.extra as JobDetailArgs?;
  if (args != null) return JobDetailPage(args: args);
  return JobDetailLoaderPage(jobId: state.pathParameters['id']!);
},
```

- [ ] **Step 3: `jobByIdProvider` + loader page**

```dart
// jobs_provider.dart — deep links / post-auth returns land on /jobs/:id with
// no extra; fetch the job then render the same detail UI.
final jobByIdProvider = FutureProvider.autoDispose.family<Job, String>((ref, id) async {
  final result = await ref.read(getJobByIdUseCaseProvider).call(id);
  return result.fold((f) => throw Exception(f.message), (job) => job);
});
```

`job_detail_loader_page.dart`: ConsumerWidget watching `jobByIdProvider(jobId)` → `JSkeletonList` page-body while loading, error state with RETRY (re-`ref.invalidate`), data → `JobDetailPage(args: JobDetailArgs.fromJob(job))`. Scaffold + back button consistent with detail page chrome.

- [ ] **Step 4: Routing widget test** (`test/app/guest_routing_test.dart`) — follow the harness pattern of the existing router/auth-flow tests (ProviderScope overriding auth to unauthenticated + FTUE loaded/completed, plus jobs repo overrides so `/browse` builds): assert `/browse` stays, `/jobs/abc` stays (stub fetch), `/applications` → `/login`, `/jobs/create` → `/login`, and authenticated `/login` with pendingReturn set → redirects to the pending location.

- [ ] **Step 5: Tests PASS; commit** — `feat(router): public guest browse routes + post-auth return`

### Task 7: Guest UI — JobsPage chrome, gated actions, GuestGateSheet, detail APPLY gate

**Files:**
- Create: `lib/features/auth/presentation/widgets/guest_gate_sheet.dart`
- Modify: `lib/features/jobs/presentation/pages/jobs_page.dart` (+`jobs_page_widgets.dart` if a helper widget is added)
- Modify: `lib/features/jobs/presentation/pages/job_detail_page.dart`

Read first (mandatory): `design-system/jobdun/MASTER.md`, `design-system/jobdun/pages/jobs-feed.md`, `design-system/jobdun/pages/auth-onboarding.md`.

- [ ] **Step 1: GuestGateSheet**

`showJSheet`-based; content: headline "CREATE A FREE ACCOUNT" (Archivo, all-caps per MASTER), one-line body naming the gated verb ("to apply for jobs" / "to save jobs" / "to see builder profiles"), primary `JButton` CREATE ACCOUNT → set `pendingReturnProvider` to the return location, `context.go('/register')`; secondary (surface-raised variant) SIGN IN → same pending + `/login`. Static helper `GuestGateSheet.show(context, ref, {required String verbLine, required String returnTo})`.

- [ ] **Step 2: JobsPage guest mode** (auth-derived, no new constructor params):

```dart
final isAuthed = ref.watch(authControllerProvider.select((s) => s.isAuthenticated));
```

- Guest header row above `PageHeader` when `!isAuthed`: "JOBDUN" wordmark left, compact `JButton` "SIGN IN" right → `/login` (no pending — generic entry).
- Hide the SAVED chip and `VerificationNudgeBanner` when `!isAuthed`.
- Card slidable: only wrap in `Slidable` when `isAuthed`; guests get the plain card (tap → detail unchanged — the route is public now).

- [ ] **Step 3: JobDetailPage guest mode**

- `initState` already no-ops without a user id.
- Bottom bar: when `!isAuthed` (watch as above), render `BottomActionBar` with `JButton('SIGN IN TO APPLY')` → `GuestGateSheet.show(..., verbLine: 'to apply for jobs', returnTo: '/jobs/${args.id}')`.
- "Posted by" card `onTap`: when guest → the same sheet with "to see builder profiles"; keep `/builders/:id` login-gated.

- [ ] **Step 4: FTUE + login entry points**

- `ftue_page.dart` final slide: secondary action "BROWSE JOBS FIRST" under the primary CTA → `ref.read(ftueGateProvider.notifier).markCompleted(); context.go('/browse');`
- `login_page.dart` footer (near the Create-account span): text link "Browse jobs without an account" → `context.go('/browse')`.

- [ ] **Step 5: `bash scripts/validate.sh` green (format, analyze, tests, design greps). Commit** — `feat(jobs): guest browse UI with sign-in gates (App Review 5.1.1v)`

### Task 8: Live verification on iOS simulator + screenshots

- [ ] Build and run on the iOS simulator (`flutter run -d <booted sim>` — `.env` is bundled), walk: FTUE → BROWSE JOBS FIRST → feed shows real open jobs (anon read against prod view) → search/filter → job detail → APPLY shows the guest gate → SIGN IN → log in with the QA fixture account → returns to the job → APPLY sheet opens. Then: sign out, Sign in with Apple on a fresh Apple ID (or verify via unit path + a fresh email SSO where SIWA can't be re-tested) → completion sheet shows ROLE ONLY.
- [ ] `xcrun simctl io booted screenshot docs/verification/2026-07-20-ios-guest-<nn>-<screen>.png` for: ftue-browse-cta, guest-feed, guest-detail-gate, gate-sheet, siwa-role-only (as capturable). Commit the PNGs.

### Task 9: Resubmission pack

- [ ] Bump build number: `pubspec.yaml` `version: 1.0.0+4` → `1.0.0+5` (confirm pbxproj uses `$(FLUTTER_BUILD_NUMBER)`; if `CURRENT_PROJECT_VERSION` is hardcoded, bump it too).
- [ ] Run the `app-store-review-check` skill audit; fix anything it flags.
- [ ] Write `docs/APP_REVIEW_REPLY_1.0-5.md`: reviewer-facing notes — where the guest entry points are, exact steps to browse without an account, what changed in the SIWA flow, demo account creds pointer.
- [ ] `bash scripts/validate.sh` full green; push branch; PR to develop with screenshots + migration note.
- [ ] Hand back to Ken: Console-side steps (upload build 5 via Xcode/Transporter, reply in Resolution Center with the notes, App Privacy answers unchanged, screenshots refresh optional).

---

**Self-review:** Spec coverage — 5.1.1(v): Tasks 4–7 (data, routes, UI, entry points); Guideline 4: Tasks 1–3; verification: Task 8; resubmission: Task 9. Types consistent: `ssoNameProvider`/`metadataDisplayName` names match across gate/state/sheet tasks; `jobs_public_browse` name matches datasource + migration. No placeholders: all code shown except file-local mechanical wiring (copyWith fields, PageView list build) which follows the shown signatures.
