# Jobdun — Auth Flow Unification Plan

> **Created:** 2026-05-27 on `chore/audit-followups-w1-w3`.
> **Status:** PLAN — no code yet. User approval required per phase before implementation.
> **Companion:** `docs/AUTH_ONBOARDING_AUDIT.md` (historical T1 audit). This plan supersedes that doc's "post-signup" section.

---

## TL;DR

Four auth paths exist today (email, Google, Apple, phone). Only one is fully wired (email). The other three drop users on `/home` with partial state and rely on `RoleSelectionSheet` to patch in the role — but **never patch in the name or avatar**, and the trigger that captures the name from auth-provider metadata uses a single key that doesn't match what Google/Apple actually send.

This plan fixes the data plumbing first (Phase 1), then replaces the role-only sheet with a 3-step unified completion sheet that handles role + name + optional avatar (Phase 2), then re-prioritises SSO on the login screen (Phase 3), then wires telemetry (Phase 4).

End state: a brand-new builder can sign up with Google → land on a friendly "Welcome to Jobdun" sheet pre-filled with their Google name and avatar → pick role → tap Finish → land on `/home` with `profiles.display_name`, `profiles.avatar_url`, `user_roles.role`, and `builder_profiles` stub all populated. ~3 taps end-to-end.

Total scope ≈ 2.5 days of work, broken into four independently-shippable PRs.

---

## 1. Audit summary (current state, by path)

### 1.1 Email + password — ✅ reference flow

| Step | What happens |
|---|---|
| `/register` step 1 | User picks role |
| `/register` step 2 | User enters name + email + password |
| Submit | `email_auth_service.signUp` sets `raw_user_meta_data.full_name` + `role` |
| DB | `handle_new_user` trigger reads both, creates `profiles` (with `display_name`), `user_roles`, and the role-specific stub in one transaction |
| Email verify screen | User confirms |
| `/home` | Everything ready, role sheet never appears |

No issues. This is the reference.

### 1.2 Google SSO — ⚠️ partial

| Step | What happens | Issue |
|---|---|---|
| Tap "Continue with Google" | `oauth_service.signInWithGoogle` → `signInWithIdToken(provider: google)` | — |
| DB trigger | Reads `raw_user_meta_data->>'full_name'`. **Google sends the name under `name`, not `full_name`** | display_name may end up NULL |
| Avatar | Google ID token contains a `picture` claim. Trigger doesn't read it. | Avatar not populated even though we have it |
| No role in metadata → no `user_roles` row, no stub | — | Same as Apple/phone |
| `/home` | `_maybeShowRoleSheet` detects null role → pops `RoleSelectionSheet` | Sheet asks for role only; name + avatar gap untouched |

### 1.3 Apple SSO — ⚠️ partial + first-signin lossy

| Step | What happens | Issue |
|---|---|---|
| Tap "Sign in with Apple" | `oauth_service.signInWithApple` with `[email, fullName]` scopes | — |
| Apple returns name **only on the first sign-in** | If we don't capture it then, it's gone forever from Apple | First-signin failure = permanent name loss |
| DB trigger | Looks for `full_name`. **Apple sends a nested object `name.firstName` + `name.lastName`** | display_name almost certainly NULL |
| Rest | Same as Google | Same gaps |

### 1.4 Phone OTP — ⚠️ worst path

| Step | What happens | Issue |
|---|---|---|
| `/phone-auth` → OTP verify | Supabase creates user with phone-only, no other metadata | — |
| DB trigger | Reads `full_name` → NULL; reads `role` → NULL | display_name = NULL, no user_roles row, no stub |
| `/home` | `_maybeShowRoleSheet` pops | Asks for role, never asks for name |
| Profile | `nameFromEmail(email)` fallback → email is NULL too → renders blank or default | Profile renders nameless |

### 1.5 Common root cause across the three "partial" paths

The `RoleSelectionSheet` was scoped to **role only**. It assumes name + avatar are already captured at signup. That assumption is only valid for the email path.

**The fix is a sheet that captures all the pieces the email path collects — but at post-auth time, not at signup time.**

---

## 2. Proposed unified onboarding completion sheet (UX contract)

Spec'd as a **3-step PageView bottom sheet**. Replaces `RoleSelectionSheet` entirely. Steps are skipped when the underlying field is already populated, so:

- Email user (everything already collected) → sheet never opens
- Google/Apple user with auto-captured name → sheet opens at step 1, pre-fills step 2, step 3 is optional
- Phone user (no metadata) → sheet opens at step 1, step 2 has an empty name field, step 3 is optional

### Step 1 — Role pick (always shown if role is null)

Lifted from the existing `RoleSelectionSheet` design. Two cards, tap-to-confirm with optimistic highlight. No "Continue" button — tap = commit.

### Step 2 — Confirm name (always shown if display_name is null OR auto-captured)

Single text field, pre-populated when we have a name from the auth provider. User can edit. Required (non-empty). Saves to both `profiles.display_name` AND the role-specific stub's name column (`builder_profiles.contact_name` or `trade_profiles.full_name`) for consistency with the email signup path.

### Step 3 — Optional avatar (always offered if avatar_url is null)

Camera / gallery picker via the existing `ImageUploadService.pickCropCompress(aspect: ImageAspect.square)`. Pre-loads a Google avatar URL when present (we'll fetch + re-upload it to our `avatars` bucket so the URL stays stable). `SKIP` is a first-class option.

### Sheet behaviour

- Non-dismissible until completed (matches today's `RoleSelectionSheet` lock)
- Step indicator at top: `● ○ ○` / `○ ● ○` / `○ ○ ●`
- Back button on steps 2-3 to revise an earlier choice
- "FINISH" on step 3 commits any partial state (e.g., role + name only if avatar skipped)
- All writes go through a single `AuthController.completeOnboarding({role, displayName, avatarFile})` method — atomic from the user's view

---

## 3. Phase-by-phase implementation plan

Each phase is **independently shippable as one PR**. Approve them à la carte if you want.

### Phase 1 — Data plumbing (foundational, ~half day)

**Goal:** make the DB trigger and Edge Functions handle the metadata shapes Google and Apple actually send, and surface what was sent so we can pre-fill the completion sheet.

#### 1.1 New migration: `20260527000006_handle_new_user_coalesce_metadata.sql`

Replace `handle_new_user()` to COALESCE multiple name keys + extract avatar:

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_display_name text;
  v_avatar_url   text;
  v_role         text;
  v_meta         jsonb := NEW.raw_user_meta_data;
BEGIN
  -- Try every key the four signup paths actually populate, in priority order.
  v_display_name := COALESCE(
    NULLIF(trim(v_meta->>'full_name'), ''),       -- email signup (our own)
    NULLIF(trim(v_meta->>'name'), ''),            -- Google OIDC standard
    NULLIF(trim(
      coalesce(v_meta->>'given_name', '') || ' ' ||
      coalesce(v_meta->>'family_name', '')
    ), ''),                                       -- Google split-name fallback
    -- Apple sends {"name":{"firstName":"...", "lastName":"..."}} on first signin
    NULLIF(trim(
      coalesce(v_meta->'name'->>'firstName', '') || ' ' ||
      coalesce(v_meta->'name'->>'lastName', '')
    ), ''),
    null
  );

  v_avatar_url := COALESCE(
    NULLIF(v_meta->>'avatar_url', ''),            -- our own naming
    NULLIF(v_meta->>'picture', ''),               -- Google OIDC standard
    null
  );

  v_role := v_meta->>'role';

  INSERT INTO public.profiles (id, display_name, avatar_url)
    VALUES (NEW.id, v_display_name, v_avatar_url)
    ON CONFLICT (id) DO NOTHING;

  -- admin role intentionally NOT accepted from client metadata (F-RLS-01)
  IF v_role IN ('builder', 'trade') THEN
    INSERT INTO public.user_roles (user_id, role)
      VALUES (NEW.id, v_role)
      ON CONFLICT (user_id) DO NOTHING;
    IF v_role = 'builder' THEN
      INSERT INTO public.builder_profiles (id) VALUES (NEW.id) ON CONFLICT (id) DO NOTHING;
    ELSIF v_role = 'trade' THEN
      INSERT INTO public.trade_profiles (id, full_name)
        VALUES (NEW.id, v_display_name) ON CONFLICT (id) DO NOTHING;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
```

Plus one-shot backfill for SSO/phone users whose `profiles.display_name` is NULL but `auth.users.raw_user_meta_data` has a name:

```sql
UPDATE public.profiles p
   SET display_name = sub.captured_name,
       updated_at   = now()
  FROM (
    SELECT u.id,
           COALESCE(
             NULLIF(trim(u.raw_user_meta_data->>'full_name'), ''),
             NULLIF(trim(u.raw_user_meta_data->>'name'), ''),
             NULLIF(trim(
               coalesce(u.raw_user_meta_data->>'given_name', '') || ' ' ||
               coalesce(u.raw_user_meta_data->>'family_name', '')
             ), ''),
             NULLIF(trim(
               coalesce(u.raw_user_meta_data->'name'->>'firstName', '') || ' ' ||
               coalesce(u.raw_user_meta_data->'name'->>'lastName', '')
             ), '')
           ) AS captured_name
    FROM auth.users u
  ) sub
 WHERE p.id = sub.id
   AND sub.captured_name IS NOT NULL
   AND (p.display_name IS NULL OR p.display_name = '');
```

#### 1.2 OAuthService surfaces the avatar URL

`OAuthService.signInWithGoogle()` already gets `idToken` from Google. The `account` object (`GoogleSignInAccount`) exposes `photoUrl` too — currently unused. After `signInWithIdToken` returns, call `_client.auth.updateUser(UserAttributes(data: { ... }))` to push `avatar_url` and `name` into raw_user_meta_data immediately, so the trigger backfill picks them up if anything changed.

For Apple: no avatar provided by Apple, so nothing to do there.

#### 1.3 Diagnostic: verify the metadata shapes once

Before relying on the COALESCE order, write a one-shot query against `auth.users` that prints raw_user_meta_data for the most recently created SSO users. Adjust key order if needed. (One-off, not committed.)

#### 1.4 Files

```
NEW:
  supabase/migrations/20260527000006_handle_new_user_coalesce_metadata.sql

MODIFIED:
  lib/features/auth/data/services/oauth_service.dart   (push photoUrl to user_metadata after Google signin)
```

#### 1.5 Test plan

- Sign up via email → display_name + role + stub all set (no regression)
- Sign in via Google with a brand-new account → display_name populated from Google `name`, avatar_url set from `picture`
- Sign in via Apple with a brand-new account → display_name populated from `name.firstName` + `name.lastName`
- Sign in via phone with a brand-new account → display_name = NULL (correct; sheet step 2 will fill it)
- Backfill query produces no surprises on existing rows (run it dry-mode first: `SELECT ... WHERE ...` returns the diff before the UPDATE)

#### 1.6 Risks

- Apple's nested `name` object shape changes between Apple SDK versions. Mitigation: defensive COALESCE, tolerate missing keys, never throw.
- Google sometimes returns null for `picture` (privacy settings). Avatar simply stays null — completion sheet step 3 lets the user upload one.
- The trigger now writes `avatar_url` on INSERT. If an SSO user previously set their own avatar via `/profile/edit` and then re-signed up (shouldn't happen but defensive), the `ON CONFLICT DO NOTHING` clause keeps the user's choice. ✅ correct.

---

### Phase 2 — Unified onboarding completion sheet (~1 day)

**Goal:** ship the 3-step sheet that replaces `RoleSelectionSheet`.

#### 2.1 New widget

`lib/features/auth/presentation/widgets/onboarding_completion_sheet.dart`

Structure:

```dart
class OnboardingCompletionSheet extends ConsumerStatefulWidget {
  static Future<void> show(BuildContext context) { ... }
}

class _State extends ConsumerState<...> {
  final _pageController = PageController();
  int _step = 0; // 0..2
  UserRole? _role;        // picked in step 1
  String? _name;          // pre-filled or empty in step 2
  File? _pickedAvatar;    // optional in step 3

  // Determines starting step based on what's already populated
  @override void initState() { ... }

  Future<void> _onFinish() async {
    await ref.read(authControllerProvider.notifier).completeOnboarding(
      role: _role!,
      displayName: _name!,
      avatarFile: _pickedAvatar,
    );
    if (mounted) Navigator.of(context).pop();
  }
}
```

Each step is its own private widget (`_StepRolePick`, `_StepConfirmName`, `_StepAvatar`). The sheet shell handles progress dots, swipe-disabled PageView, back/next routing, and the non-dismissible PopScope.

#### 2.2 New `AuthController.completeOnboarding` method

Wraps everything into one atomic-from-the-user-view operation:

```dart
Future<bool> completeOnboarding({
  required UserRole role,
  required String displayName,
  File? avatarFile,
}) async {
  // 1. setRoleAndStubProfile(role)   — existing
  // 2. update profiles.display_name (and trade_profiles.full_name / builder_profiles.contact_name)
  // 3. if avatarFile != null, uploadAvatar(avatarFile)
  // 4. Refresh auth state so UI reflects the new role/name/avatar
}
```

Errors at any step set `state.errorMessage` and the sheet shows the StatusBanner. We don't rollback role on a later step failure — the user can re-try name/avatar from `/profile/edit` if needed.

#### 2.3 Skip logic

In the sheet's `initState`, determine the starting step:

```dart
final auth = ref.read(authControllerProvider);
final profile = ref.read(profileControllerProvider).profile;

final needsRole   = auth.role == null;
final needsName   = (profile?.displayName ?? '').trim().isEmpty;
final hasAvatar   = (profile?.avatarUrl ?? '').isNotEmpty;

if (!needsRole && !needsName && hasAvatar) {
  Navigator.of(context).pop(); // sheet shouldn't have opened — defensive
  return;
}

_step = needsRole ? 0 : needsName ? 1 : 2;
```

#### 2.4 Home page rewire

In `lib/features/home/presentation/pages/home_page.dart`, replace the existing `RoleSelectionSheet.show(context)` call with `OnboardingCompletionSheet.show(context)`. Update the gate so it also fires when display_name is null (not just role):

```dart
if (!auth.isAuthenticated || !auth.isRoleLoaded) return;
final profile = ref.read(profileControllerProvider).profile;
final needsAnything = auth.role == null || (profile?.displayName ?? '').isEmpty;
if (!needsAnything) return;
OnboardingCompletionSheet.show(context);
```

#### 2.5 Delete `role_selection_sheet.dart`

Fully superseded. No external callers besides home_page.dart.

#### 2.6 Files

```
NEW:
  lib/features/auth/presentation/widgets/onboarding_completion_sheet.dart

MODIFIED:
  lib/features/auth/presentation/providers/auth_provider.dart  (add completeOnboarding)
  lib/features/home/presentation/pages/home_page.dart          (swap the sheet call)

DELETED:
  lib/features/auth/presentation/widgets/role_selection_sheet.dart
```

#### 2.7 Test plan

- **Email signup** → sheet never opens (skip rules all true)
- **Google signup, name auto-captured** → sheet opens at step 1, step 2 pre-filled with Google name, step 3 offered
- **Google signup, name capture failed** (edge case, key mismatch) → sheet opens at step 1, step 2 empty, user types name
- **Apple first signin** → same as Google
- **Apple subsequent signin (no name from Apple)** → if first signin failed name capture, sheet opens at step 2 only (role already set)
- **Phone signup** → sheet opens at step 1, step 2 empty, step 3 offered
- **User dismisses app mid-flow** → on next launch, sheet pops again at the appropriate starting step (state is read fresh from DB, not cached)
- **Skip avatar** → finish writes role + name only, avatar stays null, profile page shows initials avatar
- **Network failure on completeOnboarding** → StatusBanner shows error, user can retry

#### 2.8 Risks

- Multi-step bottom sheet UX on small screens — measure the keyboard interaction on step 2 carefully. Use `MediaQuery.viewInsetsOf(context).bottom` like the manual upload sheet does.
- Sheet state lost on `Navigator.didChangeAppLifecycleState` if user backgrounds the app mid-flow. Tolerate it — they re-open the sheet on next launch (skip logic re-derives starting step from DB).

---

### Phase 3 — Login screen visual hierarchy (~half day)

**Goal:** prioritise SSO, simplify the visual ladder, kill the FTUE→Login→Auth three-tap penalty for SSO-preferred users.

#### 3.1 Login screen restructure

Lift Google + Apple + Phone buttons above the email/password form. Add a clear "or use email" divider. Visual order:

```
[Jobdun logo + tagline]
[Continue with Google]
[Continue with Apple]   ← iOS only, hidden on Android
[Continue with phone]
──── or use email ────
[email field]
[password field]
[SIGN IN button]
[Forgot password?]  [Create account →]
[Terms · Privacy (small print)]
```

#### 3.2 FTUE final slide

Add a "Continue with Google" CTA on slide 4 (the existing "Get started" slide) so users entering through the FTUE can skip the login screen entirely.

```
Final FTUE slide:

  "Find work or hire someone today."

  [Continue with Google]     ← new shortcut
  [More sign-up options →]    ← falls back to existing /login route
```

The Google CTA fires the same `signInWithGoogle()` controller method. After success, the user lands on `/home`, the completion sheet opens at step 1, they're done in 3 taps from app launch.

#### 3.3 Files

```
MODIFIED:
  lib/features/auth/presentation/pages/login_page.dart   (re-layout)
  lib/features/ftue/presentation/pages/ftue_page.dart    (add Google shortcut on final slide)
```

#### 3.4 Risks

- Apple button on iOS only — make sure the layout doesn't leave dead space on Android. Use a platform conditional.
- Google ID token race on cold start — if `signInWithGoogle` fires before `GoogleSignIn.instance.initialize` settles, it throws. Already handled in `oauth_service.dart`'s `_googleInitialized` latch.

---

### Phase 4 — Telemetry + drop-off measurement (~half day)

**Goal:** measure how each path performs so future tweaks are data-driven.

#### 4.1 Events to add

Via the existing `AuthAnalytics` helper:

| Event | When | Properties |
|---|---|---|
| `signup_started` | First auth method tap from `/login` or FTUE | `{provider: 'email' \| 'google' \| 'apple' \| 'phone'}` |
| `signup_authed` | Auth succeeded (auth.users row exists) | `{provider, ms_since_started}` |
| `completion_sheet_opened` | Sheet shows on `/home` | `{starting_step: 0\|1\|2}` |
| `completion_step` | Each step finishes | `{step: 'role'\|'name'\|'avatar', skipped: bool, ms_on_step}` |
| `signup_completed` | `completeOnboarding` returns true | `{provider, total_ms}` |
| `signup_abandoned` | App backgrounded mid-sheet | `{last_step}` (fired via lifecycle observer) |

#### 4.2 Funnel question this answers

> What % of users who tap "Continue with Google" actually finish the completion sheet within their first session? What's the median time to complete onboarding by provider?

If Google → completion is < 70% completion, the sheet needs another design pass. If it's > 90%, ship and move on.

#### 4.3 Files

```
MODIFIED:
  lib/core/services/auth_analytics.dart  (add the new event helpers)
  lib/features/auth/presentation/pages/login_page.dart
  lib/features/auth/presentation/widgets/onboarding_completion_sheet.dart
  lib/features/auth/presentation/providers/auth_provider.dart
```

---

## 4. Cumulative impact

After all four phases:

| Path | Today (taps from app launch to fully-set-up `/home`) | After (taps) |
|---|---|---|
| Email | 8 (FTUE 4 + register 4) | 8 — no change, already optimal |
| Google | 4 (FTUE 4 + login + Google) then sudden role sheet on home | 3 from FTUE final slide → Google → completion sheet |
| Apple | 4 + sudden role sheet | 3 + completion sheet |
| Phone | 5 + role sheet + nameless profile | 4 + completion sheet with name capture |

Plus consistent data state — every signup path lands on `/home` with `display_name`, `role`, `stub_profile`, and (when available) `avatar_url` populated.

---

## 5. Sequence + approval gates

I will NOT implement until you say "approve Phase X" for each phase. Default order:

1. **Phase 1 first** — foundational, no UX risk, ships standalone with measurable benefit (the existing buggy Google/Apple/phone signups start capturing names correctly).
2. **Phase 2 next** — biggest UX leverage, but depends on Phase 1 being live so step 2 pre-fills correctly.
3. **Phase 3 third** — pure visual polish; can ship whenever after Phase 1.
4. **Phase 4 last** — instrumentation; pure-additive, no UX impact.

Approval format:

- *"approve all"* → I ship Phase 1, then 2, then 3, then 4, one PR each, pausing only if any phase analyzer or architecture check fails.
- *"approve 1+2"* → I ship those two and stop. You decide on 3+4 after seeing the result.
- *"phase 1 only first"* → most conservative; ship 1, you verify on device, then we move on.

---

## 6. Out of scope (explicit non-goals)

- **Magic-link email auth.** Three auth methods is enough.
- **A name-edit-on-its-own screen.** The completion sheet handles it.
- **OAuth account linking** (e.g., "you already signed up with email, want to link your Google?"). Phase 5+ if there's demand.
- **Touching the email signup flow.** It works. Don't rewrite it.
- **Renaming display_name to something else.** Stays as-is for v2.1.
- **Capturing phone number during SSO signup.** Phone verification has its own flow at `/profile/verify-phone`; bundling it into signup adds friction that's not worth it for v2.1.

---

## 7. Adjacent docs

- `docs/AUTH_ONBOARDING_AUDIT.md` — the T1 audit that this plan supersedes for post-signup behaviour.
- `docs/VERIFICATION_AUDIT.md` — the verification flow that sits downstream of signup.
- `lib/features/auth/data/services/role_resolver.dart` — the `setRoleAndStubProfile` method this plan extends.
- `lib/features/auth/presentation/widgets/role_selection_sheet.dart` — gets deleted in Phase 2.
