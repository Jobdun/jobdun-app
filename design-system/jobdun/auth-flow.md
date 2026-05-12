# Auth Flow

This doc describes the auth / onboarding flow as it stands after the friction-reduction sprint (Tiers 1 + 2 + 3). For style and component rules, see `MASTER.md` and `pages/auth-onboarding.md` — this file is about the **flow shape**, not the visual treatment.

---

## Guiding principle

> Collect the minimum at signup. Collect the rest just-in-time, when the user has motivation to give it.

The marketplace needs role, identity, and (eventually) phone + location + trade. We collect *role and identity* at signup, then surface every other field at the moment the user wants something that requires it.

---

## The flow today

### Email signup

```
Login → Create account → /register
                            │
                            ├─ Step 1 (1/2)  ROLE
                            │     Builder or Trades — required.
                            │
                            └─ Step 2 (2/2)  ACCOUNT
                                  full_name, email, password, Terms ✓
                                  3 inputs + 1 required check + 1 primary CTA.
                                  No confirm-password (eye-toggle covers it).
                                  No phone (deferred to first job-apply/post).
                                  No marketing opt-in (deferred to day-3 prompt).
                                                │
                                                ▼
                                       /verify-email
                                  • Primary: "I've verified — continue"
                                  • Secondary: "Resend verification email"
                                  • Tertiary: "Wrong email? Change it" → /register
                                    (form pre-filled via RegisterDraft on AuthState)
                                                │
                                                ▼
                                           /home
                                  • Welcome SnackBar (4s auto-dismiss, once per session)
                                  • ProfileCompletenessBanner if < 100%
                                  • RoleSelectionSheet does NOT fire
                                    (role is already in the JWT)
```

**Tap count, new user, happy path:** 9 taps + 3 field entries to land on `/home`.
**Old flow:** 19 taps + 6 field entries — a 53% / 50% reduction.

### SSO signup (Google / Apple)

```
Login → Continue with Google/Apple
            │
            ▼ (Supabase issues JWT — user_role claim is ABSENT for new users)
        /home
            │
            ▼
    RoleSelectionSheet (non-dismissible modal)
            │
            ├─ Builder ──┐
            ├─ Trades ───┤
                         ▼
                user_roles row written → JWT refreshed →
                home unblocks → banner / toast fire
```

The DB trigger (`handle_new_user`) writes a `user_roles` row **only when** `user_metadata.role` is supplied — i.e. the email path. The JWT hook (`custom_access_token`) omits the `user_role` claim entirely when no row exists. The Flutter client reads no claim → `state.role` is null → `RoleSelectionSheet` fires.

This avoids the previous bug where SSO users silently became Tradies via a `COALESCE(role, 'trade')` default.

### Phone signup

```
Login → "Use phone number" (muted link below SSO row)
            │
            ▼
        /phone-auth
            │
            ├─ Step 0  COUNTRY + NUMBER
            │     8-country picker (AU default + NZ / GB / IE / IN / PH / US / CA).
            │     Per-country regex validation. E.164 built on submit.
            │     On send: pendingPhone saved to SharedPreferences (10-min TTL).
            │
            └─ Step 1  OTP
                  6-digit Pinput. Verify → home.
                  On verify success: SharedPreferences cleared.
                  On back: cleared.

If user kills app mid-OTP → next launch shows
"Continue verification?" dialog with last number.
```

### Returning user (login)

`/login` → email + password → `/home`. Forgot-password lives as a muted link **below** the CREATE ACCOUNT button (orange `c.action` is reserved for LOG IN only).

---

## What's deferred and where it gets collected

| Field | Where it gets collected | Why deferred |
|---|---|---|
| Phone (Trade) | First time they apply to a job | They give a phone because a builder needs to reach them about *this* job |
| Phone (Builder) | First time they post a job | Tradies need to call about *this* job |
| Marketing opt-in | Day-3 in-app prompt | AU Spam Act 2003: consent must be *informed*; user can't meaningfully consent before seeing the product |
| Location (suburb / state) | `/profile/edit` (Profile Completeness Banner pushes them there) | Not gating any flow today; helps match quality once filled |
| Trade category (Trades) | `/profile/edit` via search-first picker | Not gating; quality-of-match improves once set |
| Verification documents | `/verification` (separate flow, gated by job requirements) | Tradies upload when a builder requires it — pull instead of push |

Every deferred field has a code comment marking the deferral point.

---

## Architectural invariants

These are load-bearing. Don't change without reading the rationale:

1. **Role is asked exactly once.** Email picks at register; SSO picks at the home sheet. If you find yourself adding a third "what role are you?" prompt, you have a bug. The race fix in `AuthController.build()` (calling `_loadProfileForCurrentUser` on every `onAuthStateChange`) plus the `isRoleLoaded` flag prevents the sheet from firing during the JWT load window.

2. **The trigger and the JWT hook agree.** `handle_new_user` writes no role row for SSO; `custom_access_token` omits the claim when no row exists. Changing one without the other reintroduces the silent-default bug.

3. **`onboardingComplete` doesn't gate navigation.** The router used to redirect `/home` → `/onboarding` when `onboarding_completed_at` was null. That's gone — the field still exists on `profiles` for analytics, but the wall doesn't.

4. **`pendingVerificationEmail` blocks the router** — and only that. While it's set, the user is held on `/verify-email`. `checkEmailVerified()` clears it on success, "Wrong email? Change it" clears it manually.

5. **Storage buckets follow the user-id-folder convention.** All user uploads go to `<bucket>/<user_id>/...`. RLS uses `(storage.foldername(name))[1] = auth.uid()::text`.

---

## Deferred — Tier 4 architectural plan: unified "Continue with…" entry

Today login and register are two separate destinations with different content. The eventual end state is a single first-screen-after-splash:

```
┌─────────────────────────────────────┐
│             JOBDUN                  │
│                                     │
│   Continue with email     →         │
│   Continue with phone     →         │
│   Continue with Google    →         │
│   Continue with Apple     →         │
│                                     │
│   By continuing, you agree to       │
│   our Terms and Privacy Policy.     │
└─────────────────────────────────────┘
```

**Why defer:** redesigning the entry point touches every auth route's mental model. Worth doing once the friction-reduction sprint's effects are measured in real user data.

**Why eventually do it:** the current model still asks "are you signing in or signing up?" as the very first question. Mobile users don't always know the answer (e.g. SSO can be either flow). A "Continue with X" model lets the backend decide existing-vs-new and routes accordingly. Drops the create-vs-login binary that's especially fuzzy with SSO.

**Constraints when you build it:**
- Must preserve the per-method tap budget: ≤ 5 taps + 3 field entries from app open to `/home` for email.
- Must keep `RoleSelectionSheet` as the SSO role-pick surface (don't reintroduce a registration-time role step for SSO).
- Must keep the legal-acceptance pattern via the existing shared widget.
- New entry screen should NOT re-introduce a brand wordmark per CTA — once at top is enough.

**Don't merge with phone-auth.** Phone needs a country picker step before OTP; collapsing it into a one-line "Continue with phone" hides that complexity. Keep the dedicated `/phone-auth` route, just enter it from the unified screen.

---

## Vocabulary (canonical strings)

See `lib/core/strings/j_strings.dart`. Don't drift — touch the constants, not the screens.

| Constant | Renders as (button) | Renders as (text) |
|---|---|---|
| `JStrings.logIn` | LOG IN | Log in |
| `JStrings.createAccount` | CREATE ACCOUNT | Create account |
| `JStrings.useEmail` | USE EMAIL | Use email |
| `JStrings.usePhone` | — | Use phone number |
| `JStrings.continueWithGoogle` | CONTINUE WITH GOOGLE | — |
| `JStrings.continueWithApple` | CONTINUE WITH APPLE | — |
| `JStrings.forgotPassword` | — | Forgot password? |
| `JStrings.iveVerified` | I'VE VERIFIED — CONTINUE | — |
| `JStrings.wrongEmail` + `changeIt` | — | Wrong email? Change it |
