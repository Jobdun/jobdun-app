# Auth + Onboarding Flow Audit

> **Goal:** reduce friction in the account-creation journey so users land on the home screen as fast as possible, then complete their profile on demand. This audit catalogues every screen, every field, every CTA, every redirect — and flags every duplication, dead-weight UI element, and friction point.

**Branch audited:** `fix/qol-audit-improvements`
**Files in scope:**
- `lib/app/router/app_router.dart`
- `lib/features/auth/presentation/pages/splash_page.dart`
- `lib/features/auth/presentation/pages/login_page.dart`
- `lib/features/auth/presentation/pages/register_page.dart`
- `lib/features/auth/presentation/pages/verify_email_page.dart`
- `lib/features/auth/presentation/pages/onboarding_page.dart`
- `lib/features/auth/presentation/pages/forgot_password_page.dart`
- `lib/features/auth/presentation/pages/phone_auth_page.dart`
- `lib/features/auth/presentation/widgets/social_auth_buttons.dart`
- `lib/features/auth/presentation/providers/auth_provider.dart`

---

## TL;DR — friction verdict

| Severity | Issue | Where |
|---|---|---|
| 🔴 **CRITICAL** | **Role is asked TWICE** — once in register step 1, again in onboarding page 1 | `register_page.dart:147` + `onboarding_page.dart:88` |
| 🔴 **CRITICAL** | Register form (step 2) bundles 6 inputs + 2 checkboxes on one screen | `register_page.dart:496-744` |
| 🟠 HIGH | Phone field appears in register **and** there's a dedicated phone-auth route — purpose unclear | `register_page.dart:567` + `/phone-auth` |
| 🟠 HIGH | Onboarding has 4 pages but only **page 3 (profile setup)** captures real data — pages 0 (welcome) and 3 (all set) are pure marketing screens after the user already committed | `onboarding_page.dart:147,623` |
| 🟠 HIGH | Brand lockup (mark + JOBDUN wordmark) renders on **6 separate screens** the user is already past — splash, login, register-step-1, register-step-2 (subtle), verify-email, forgot-password, onboarding-welcome, onboarding-all-set | every page |
| 🟡 MEDIUM | Confirm-password field on register — show/hide eye toggle already exists, doubling input is friction | `register_page.dart:657` |
| 🟡 MEDIUM | Trade category chip group has **19 options** in a single Wrap — overwhelming on first interaction | `onboarding_page.dart:519` |
| 🟡 MEDIUM | `_FieldLabel` widget duplicated in `login_page.dart` and `register_page.dart` | both files |
| 🟡 MEDIUM | Marketing opt-in inline with required terms — adds visual noise to the most important step | `register_page.dart:735` |
| 🟢 LOW | Step counter says "1 / 3", "2 / 3" but step 3 (verify-email) is reachable only by router redirect — the user never sees the counter on it | `register_page.dart:21,117` |
| 🟢 LOW | Splash page hardcodes `context.go('/home')` after 900 ms — router redirect handles the rest, but this is fragile | `splash_page.dart:39` |
| 🟢 LOW | Forgot-password page repeats the full brand lockup (logo + 44sp gradient wordmark) above a one-field form | `forgot_password_page.dart:64-90` |

---

## Flow map (current state)

```
/splash (900 ms timer)
   │
   ▼ context.go('/home')  ──▶ router redirect kicks in
   │
   ├─[unauth]─▶ /login
   │             │
   │             ├─▶ CREATE ACCOUNT ─▶ /register
   │             │                       │
   │                                     ├── Step 1: Role select (Builder | Trades)
   │             │                       ├── Step 2: Full name + Email + Phone (AU) + Password + Confirm + Terms + Marketing
   │             │                       └── on success ─▶ /verify-email  (Step 3 in counter)
   │             │                                          │
   │             │                                          ▼ user taps email link
   │             │                                          back to app → router routes to /onboarding
   │             │
   │             ├─▶ FORGOT PASSWORD ─▶ /forgot-password
   │             ├─▶ Phone link (Google/Apple SSO) ─▶ /phone-auth (phone + OTP)
   │             └─▶ SSO (Google · Apple) → straight to onboarding redirect
   │
   └─[auth, !onboarded]─▶ /onboarding
                            │
                            ├── Page 0: Welcome ("GET WORK. POST JOBS.")
                            ├── Page 1: Role select (Builder | Trades)   ◀── DUPLICATE OF /register STEP 1
                            ├── Page 2: Profile setup (builder OR trade fork)
                            └── Page 3: All set ("PROFILE LIVE.")
                            │
                            ▼ context.go('/home')
```

---

## Screen-by-screen audit

### 1. `/splash` — `SplashPage`

**Purpose:** brand cold-open while auth state hydrates.

| Element | Detail |
|---|---|
| Background | `c.background` (Slate 950) |
| Logo | `lib/core/assets/logo.png`, 64×64 — `Image.asset` (PNG) |
| Wordmark | `'JOBDUN'`, displaySmall, 48sp, 4.0 letter-spacing, gradient via `ShaderMask` + `brandFlame` |
| Tagline | `AppConstants.appTagline`, bodyMedium, `c.text3` |
| Env warning chip | Renders if `!AppEnv.isSupabaseConfigured` — Iconsax.info_circle + missing keys |
| Loading bar | 2 h × 100 % w, Tween 0→1 over 800 ms, `c.action` fill |
| Timer | 900 ms then `context.go('/home')` |
| SafeArea | yes |
| Back | none |

**Findings:**
- 🟢 Splash relies on the router redirect to actually send the user to `/login` / `/onboarding` / `/home`. The hardcoded `/home` target is misleading — should be `/` and let the redirect resolve.
- 🟡 Uses **PNG logo** while every other page uses **SVG mark**. Inconsistent asset format.
- 🟡 Renders only 900 ms. The loading bar animates 800 ms. If Supabase auth init is slower than 900 ms, the user blinks past splash and lands on a flicker.

---

### 2. `/login` — `LoginPage`

**Purpose:** existing-user sign-in.

| Element | Detail |
|---|---|
| Background | `c.background` |
| Brand mark | `mark-jobdun.svg`, 64×64 |
| Wordmark | `'JOBDUN'`, 60sp, brandFlame gradient via ShaderMask |
| Form | `FormBuilder`, `_formKey` |
| Field 1 | **EMAIL** — `FormBuilderTextField`, `Iconsax.sms` prefix, hint `your@email.com`, validators: required + email |
| Field 2 | **PASSWORD** — obscured, `Iconsax.lock` prefix, hint `Enter your password`, eye-toggle suffix, validator: required (no min-length on sign-in) |
| Remember me | `Checkbox` + `REMEMBER ME` label (visual only — **state never read or persisted**) |
| Forgot password | text link `FORGOT PASSWORD`, orange, → `/forgot-password` |
| Status banner | error + info from `authState` |
| CTA primary | `AppButton` `LOG IN` / `LOGGING IN...` |
| CTA secondary | `AppButton` `CREATE ACCOUNT` (slate, not ghost) → `/register` |
| SSO | `SocialAuthButtons` — demoted text row "Or continue with Google · Apple" |
| Animation | AnimatedOpacity 0→1, 150 ms on first frame |

**Findings:**
- 🟡 **`_rememberMe` is wired to a `setState` but never persisted** anywhere (no SharedPreferences, no Supabase persistSession flag). Pure visual decoy.
- 🟡 `_FieldLabel` private class is **duplicated** in `register_page.dart:888` — extract to a shared widget under `core/design/widgets/`.
- 🟢 No password-strength bar here, correct (sign-in does not validate strength).
- 🟢 No phone-sign-in entrypoint on this page — only on register / SSO. **If phone-auth is a supported sign-in path, it should appear here** as a third option, not buried.

---

### 3. `/register` — `RegisterPage`

**Purpose:** new-user signup. Internal 2-step state machine.

#### Step 1 — Role selection (`_RoleStep`)

| Element | Detail |
|---|---|
| Top bar | empty left, right shows `1 / 3` step counter |
| Progress bar | 3-segment, segment 1 filled (`c.action`) |
| Brand lockup | mark 32×32 + JOBDUN 32sp gradient — compact horizontal |
| Heading | `WHO ARE YOU?` headlineMedium |
| Subhead | `Select your role to get started.` bodyMedium |
| Role card 1 | **BUILDER** — `Iconsax.buildings`, "Post jobs, hire crews" |
| Role card 2 | **TRADES** — `Iconsax.cpu_charge`, "Find work, get paid" |
| Error | `Select a role to continue.` (red) if no selection on Continue |
| CTA | `AppButton` `Continue` |
| SSO | `SocialAuthButtons` (same text row as login) |
| Footer | `Already have an account? LOG IN` → `/login` |

#### Step 2 — Account form (`_FormStep`)

| Element | Detail |
|---|---|
| Top bar | back arrow (→ step 1), step counter `2 / 3` |
| Progress bar | segments 1 & 2 filled |
| Heading | `CREATE ACCOUNT` headlineMedium |
| Subhead | `Your details — we keep it tight.` |
| Field 1 | **FULL NAME** — required, min length 2, `Iconsax.user`, words capitalisation |
| Field 2 | **EMAIL** — required + email validator, `Iconsax.sms` |
| Field 3 | **MOBILE (AU)** — **optional**, prefix `+61`, formatter `_AuPhoneFormatter` (digit-only, max 9, auto-spaces at 3 and 6), validator: format if non-empty |
| Field 4 | **PASSWORD** — required, min 8, must contain `\d`, eye-toggle, hint `Min. 8 chars` |
| Strength meter | 3-segment bar — weak (red) / medium (gold) / strong (green); label adjacent |
| Field 5 | **CONFIRM PASSWORD** — required, must equal password, separate eye-toggle |
| Field 6 | **TERMS** — `FormBuilderCheckbox`, **required**, ToS + Privacy links (cosmetic, no URL handlers) |
| Field 7 | **MARKETING OPT-IN** — `CheckboxListTile`, **optional**, unchecked default |
| Status banner | error + info |
| CTA | `AppButton` `Create Account` / `Creating account...` |
| Footer | `Already have an account? LOG IN` → `/login` |
| Autovalidate | `AutovalidateMode.onUserInteraction` |

**Findings:**
- 🔴 **Step 1 of register asks role, then onboarding page 1 asks role again.** Both pages have `UserRole? _selectedRole` initialised to `null`. The role chosen in register is sent to `register()` and stored in `user_metadata['role']`, then `completeOnboarding()` writes the role again. **Onboarding should pre-select the role from auth metadata (or `state.role`) and skip the role page entirely if already known.**
- 🔴 **Step 2 has 7 controlled inputs on one screen.** Even with progressive disclosure, 7 controls is a lot for mobile signup. Industry baseline is 3-4 (email + password + name).
- 🟠 **Phone is optional but visually present.** If it's optional, defer it to `/profile/edit` after the user is in the app. Currently it just adds vertical real-estate and another keyboard switch.
- 🟠 **Confirm-password field is redundant** — the eye toggle (`Iconsax.eye_slash`) on the password field already lets the user verify their entry. Major signups (Apple, Stripe Atlas, current Google) have dropped confirm-password.
- 🟠 **Marketing opt-in mid-flow** — under Australian Spam Act 2003 you do need explicit consent if you intend to email marketing, but this can be solicited inside the app after the first session. Removing it from sign-up shortens the form by one row.
- 🟡 **Terms link is not tappable** — `Terms of Service` and `Privacy Policy` are styled as links but no `recognizer: TapGestureRecognizer()`. Compliance risk.
- 🟡 Step counter says `n / 3` and refers to verify-email as step 3, but verify-email is a **separate route** with no counter visible — the counter is dishonest.
- 🟡 Password validator allows `1234567a` (8 chars + digit). Consider an additional rule for symbols once strength = medium, or rely entirely on the meter and drop the digit-required rule.
- 🟢 AU phone formatter is clean.

---

### 4. `/verify-email` — `VerifyEmailPage`

**Purpose:** wait state while user clicks the magic link in their inbox.

| Element | Detail |
|---|---|
| Background | `c.background` |
| Brand mark | `mark-jobdun.svg`, 48×48 |
| Wordmark | `JOBDUN`, 40sp gradient |
| Email icon | 80×80 raised surface card, `Iconsax.sms_notification`, orange |
| Heading | `CHECK YOUR\nEMAIL.` displaySmall, 40sp |
| Body | `Verification link sent to <email>. Tap it to activate your account.` — email rendered orange |
| Tip card | `Iconsax.info_circle` + `"Can't find it? Check your spam or junk folder."` — surface with border |
| Status banner | error + info |
| CTA primary | `AppButton` `Resend verification email` / `Sending...` / `Resend in {n}s` — 60 s cooldown timer |
| CTA secondary | `AppButton` `Back to sign in` — calls `clearPendingVerification()` which clears `pendingVerificationEmail` from state, allowing router to send the user back to `/login` |

**Findings:**
- 🟡 **No "I've verified, take me in" button.** The flow relies on Supabase deep link → app open → router refresh. If the email client opens the link in an in-app browser, the user has to manually return. A "I've verified" button that re-queries `auth.currentUser.emailConfirmedAt` would close the loop.
- 🟡 **No way to edit the email.** If the user typoed `gnail.com`, they have to "Back to sign in" → context loss → re-fill the whole form on register.
- 🟡 Brand wordmark at 40sp again — heavy for a wait-state screen.
- 🟢 60 s cooldown on resend is the right call (Supabase rate-limits anyway).

---

### 5. `/onboarding` — `OnboardingPage`

**Purpose:** post-signup profile completion.

**Pages:** 4 — Welcome → Role → Profile setup → All set.
**Navigation:** `PageView` with `NeverScrollableScrollPhysics` (CTA-driven).

#### Page 0 — `_WelcomePage`

| Element | Detail |
|---|---|
| Logo | PNG `logo.png` 72×72 |
| Wordmark | `JOBDUN` 52sp gradient |
| Hero | `GET WORK.\nPOST JOBS.` 44sp gradient |
| Tagline | `Verified jobs. Real builders. Get hired fast.` |
| Skip | top-right `SKIP` label (only renders on page 0) |
| CTA | `Next` |

#### Page 1 — `_RolePage`

| Element | Detail |
|---|---|
| Eyebrow | `YOUR ROLE` bodySmall, letter-spacing 1.2 |
| Heading | `What describes you best?` 28sp |
| Subhead | `Choose your role to personalise your experience.` |
| Role card 1 | **Builder** — `Iconsax.briefcase`, role.description |
| Role card 2 | **Trade** — `Iconsax.personalcard` |
| CTA | `Next` (disabled until role selected; falls back to secondary variant) |

#### Page 2 — `_ProfileSetupPage` (forks on role)

**Builder branch:**
| Element | Detail |
|---|---|
| Eyebrow | `COMPANY SETUP` |
| Heading | `Tell us about your business.` |
| Subhead | `You can update this anytime from your profile.` |
| Field 1 | **COMPANY NAME** — raw `TextField`, `Iconsax.building`, no validation |
| Field 2 | **BUSINESS TYPE** — `_ChipGroup`: Sole trader / Company / Partnership |
| Field 3 | **CITY OR SUBURB** — raw `TextField`, `Iconsax.location`, no validation |

**Trade branch:**
| Element | Detail |
|---|---|
| Field 1 | **TRADE** — `_ChipGroup` with **19 options**: Electrician, Plumber, Carpenter, Plasterer, Painter, Concreter, Welder, Bricklayer, Tiler, Steel Fixer, Form Worker, Rigger, Scaffolder, Crane Operator, Boilermaker, Roof Plumber, Cabinet Maker, Demolition, Other |
| Field 2 | **EXPERIENCE** — `_ChipGroup`: `<1 yr`, `1–3 yrs`, `3–5 yrs`, `5+ yrs` |
| Field 3 | **CITY OR SUBURB** — raw `TextField`, no validation |

#### Page 3 — `_AllSetPage`

| Element | Detail |
|---|---|
| Logo | PNG 72×72 |
| Wordmark | `JOBDUN` 52sp gradient |
| Hero | `PROFILE\nLIVE.` 44sp gradient |
| Tagline | `Your profile is active. Start getting work.` |
| CTA | `Get to work` / `Setting up...` → `completeOnboarding()` → router pushes to `/home` |

**Bottom bar (all pages):**
- `SmoothPageIndicator` 4-dot ExpandingDotsEffect
- `AppButton` `Next` / `Continue` / `Get to work`

**Findings:**
- 🔴 **Page 1 (role) is a duplicate** of register step 1. If you came via email signup, role is already in `user_metadata`. If you came via SSO, you skipped register entirely and only this page asks — so it has to stay **for SSO** but should be **skipped for password signup**.
- 🟠 **Pages 0 and 3 are marketing screens** dressed as onboarding steps. The user has already committed (account is created). Drop them or fold the message into the home screen first-load state.
- 🟠 **None of the profile setup fields are validated** — `TextField`, not `FormBuilderTextField`. Submitting an empty `Tell us about your business` page completes onboarding with empty strings stripped to `null` in `_finish()`. **This means a user can skip every field.** If that's the intent, the heading should say "Optional — add later" so the user understands.
- 🟠 **19 trade chips** is overwhelming. Group into 3-4 categories (electrical, structural, finishing, heavy-equipment) with progressive reveal, or use a search-filtered list.
- 🟡 **`TextField` in profile setup** (not `FormBuilderTextField`) — inconsistent with the rest of the form layer.
- 🟡 **Skip button** only appears on page 0 — once the user is on the role page, no way to skip. The router won't let them get to `/home` until `onboardingComplete` is true.
- 🟢 4-page `PageView` with disabled scroll is correct (forces CTA flow).

---

### 6. `/forgot-password` — `ForgotPasswordPage`

**Purpose:** request a password-reset email.

| Element | Detail |
|---|---|
| App bar | back arrow → `/login` |
| Logo | PNG 52×52 |
| Wordmark | `JOBDUN` 44sp gradient |
| Heading | `RESET YOUR\nPASSWORD.` 40sp |
| Subhead | `Enter your email and we'll send a reset link.` |
| Field | **EMAIL** — required + email validator |
| Status banner | error + info |
| CTA primary | `AppButton` `Send reset link` / `Sending...` |
| Divider | `OR` row with `c.border` |
| CTA secondary | `AppButton` `Back to log in` → `/login` |

**Findings:**
- 🟡 **Brand lockup at 52 px logo + 44sp wordmark** for a one-field screen — heavy. A simple back-button + heading is enough.
- 🟡 No success state — `infoMessage` shows the banner but the user remains on the form. Could swap to a "Check your inbox" view (like verify-email) with cooldown timer.
- 🟢 Validators are correct.

---

### 7. `/phone-auth` — `PhoneAuthPage`

**Purpose:** sign-in (or sign-up) by phone + SMS OTP. Not currently linked from `/login`.

#### Step 0 — phone entry

| Element | Detail |
|---|---|
| App bar | back arrow (`context.pop()` or `/login`) |
| Logo | PNG 56×56 |
| Heading | `PHONE SIGN IN` 26sp, letter-spacing 2 |
| Subhead | `Enter your mobile number to receive a verification code.` |
| Field | **MOBILE NUMBER** — raw `TextField`, hint `+61 4xx xxx xxx`, regex `^\+?[0-9]{8,15}$` |
| Error | `_phoneError` local state if regex fails |
| Status banner | error + info from `authState` |
| CTA | `SEND CODE` / `Sending code...` |

#### Step 1 — OTP entry

| Element | Detail |
|---|---|
| App bar | back arrow → `_backToPhone()` (clears OTP + pending phone) |
| Icon | 64×64 `actionBg` card with `Iconsax.message` |
| Heading | `ENTER CODE` 26sp |
| Subhead | `We sent a 6-digit code to\n{phone}` |
| OTP input | `Pinput` 6-digit, autofocus, focused border 2 px action |
| Status banner | error + info |
| CTA | `VERIFY` / `Verifying...` — disabled until 6 digits entered |
| Resend | text link, 60 s cooldown, opacity 0.4 when disabled |

**Findings:**
- 🟠 **Not reachable from any UI surface.** The route exists but `LoginPage` and `RegisterPage` don't link to it. Either remove the route or surface a "Use phone instead" link on `/login`.
- 🟡 Phone field is a raw `TextField`, not `FormBuilderTextField` — diverges from the form pattern used elsewhere.
- 🟡 If `signInWithPhone()` succeeds but the user closes the app before entering OTP, `pendingPhoneNumber` is wiped on rebuild (`build()` resets state to `AuthState()` when no session). On reopen the user has no way to re-enter OTP without re-requesting.
- 🟢 `Pinput` integration is clean and matches the design system.

---

### 8. SSO row — `SocialAuthButtons`

Used in `LoginPage` and `RegisterPage` step 1.

| Element | Detail |
|---|---|
| Layout | one-line row, centered |
| Label | `Or continue with ` bodySmall 12sp `c.text3` |
| Google link | SVG icon 13×13 + `Google` label, taps `signInWithGoogle()` |
| Separator | ` · ` |
| Apple link | SVG icon 13×13 + `Apple` label, taps `signInWithApple()` |
| Loading | row opacity 0.4 when `state.isLoading` |

**Findings:**
- 🟢 Demoted SSO row matches the Aggressive-Flat brand brief (no giant brand buttons).
- 🟡 Tap targets are ~50 px wide each — borderline for accessibility (Apple HIG: 44 pt minimum). Add invisible padding to extend the hit area.

---

## Duplications (verbatim)

### Duplicated user actions
1. **Role selection** — `register_page.dart:147 _RoleStep` AND `onboarding_page.dart:208 _RolePage`.
2. **Brand lockup (mark + JOBDUN wordmark)** — splash, login, register-step-1, verify-email, forgot-password, onboarding page 0, onboarding page 3. Seven copies of essentially the same hero.
3. **"Already have an account? LOG IN" footer** — appears in register step 1 (`:346`) AND step 2 (`:771`). Identical RichText.

### Duplicated code
4. **`_FieldLabel` private widget** — defined in `login_page.dart:257` and `register_page.dart:888`. Identical implementation.
5. **AU phone validation** — regex/format logic in `register_page.dart:597` AND `phone_auth_page.dart:34`. Different rules, same input.
6. **Resend cooldown logic** — `Timer.periodic(1 s)` + `_cooldownSeconds--` pattern in `verify_email_page.dart:42` AND `phone_auth_page.dart:48`.
7. **`AnimatedOpacity 0→1 over 150 ms with `_ready` flag** — login, register, forgot-password. Cargo-culted across pages.

### Duplicated data writes
8. **Role is written twice** — once into `user_metadata['role']` during `signUp()` (`auth_provider.dart:226`), again to `user_roles` table during `completeOnboarding()` (`auth_provider.dart:486`). The metadata copy is never read after sign-in.
9. **Phone is collected twice** — register form (`+61` stripped, written to `user_metadata['phone']`) AND the `/phone-auth` route. Neither write goes to `profiles.phone`.

---

## Friction reduction plan (recommended)

### Tier 1 — ship this week

1. **Remove `_RolePage` from onboarding.** Read `state.role` (or `user.userMetadata?['role']` for SSO users where it's null). Only render the role page if role is still unknown.
2. **Strip register step 2 down to 3 fields:** Full name, Email, Password. Drop confirm-password, drop phone (move to profile), drop marketing checkbox (ask after first session). Keep terms (required for legal).
3. **Make "Welcome" and "All set" onboarding pages skippable** OR drop them entirely. Replace with a first-load home-screen toast.
4. **Wire `Remember me` to `Supabase persistSession` or remove the checkbox.**

### Tier 2 — next sprint

5. **Extract `_FieldLabel` to `core/design/widgets/field_label.dart`** and consume in both pages.
6. **Add "I've verified" button to verify-email** that calls `auth.refreshSession()` + checks `emailConfirmedAt`.
7. **Add "Use phone instead" link to `/login`** OR remove `/phone-auth` from the router.
8. **Group the 19 trade chips** into 4-5 categories with expand-on-tap. Add a search field for fast pickers.
9. **Validate onboarding TextFields** (or rename to `_FieldOptional` so the empty case is honest).
10. **Make Terms / Privacy links tappable** (`url_launcher` to ToS/Privacy URLs).

### Tier 3 — polish

11. **Replace PNG `logo.png` with SVG `mark-jobdun.svg`** on splash and onboarding pages 0 and 3 (consistency with the rest of the auth surface).
12. **Drop the brand lockup from forgot-password and verify-email** — the user is mid-flow, they know what app they're in.
13. **Splash: go to `/` (or a no-op) and let the router redirect resolve.** Don't hardcode `/home`.
14. **Honest step counter** — remove "3 / 3" from register since step 3 (verify-email) doesn't display it.

### Tier 4 — architectural

15. **Move profile-completion off the onboarding wall.** Let users land on `/home` immediately after email verification, with a persistent banner "Complete your profile" that links to `/profile/edit`. This is the **biggest friction reduction available** — converts a blocking flow into a deferred one.
16. **Unify phone + email + SSO into a single "Continue with…" screen** instead of separate `/login` and `/phone-auth` routes.

---

## Field-count comparison

| Step | Current fields | Recommended fields | Savings |
|---|---|---|---|
| Splash | 0 | 0 | 0 |
| Login | 2 + remember-me | 2 | drop dead control |
| Register step 1 (role) | 1 (role) | 0 (defer to onboarding if SSO) | — |
| Register step 2 (form) | **7** controls | **3** (name, email, password) | **−4** |
| Verify email | 0 + 2 CTAs | 0 + 3 CTAs (add "verified") | 0 |
| Onboarding welcome | 0 | **drop page** | −1 page |
| Onboarding role | 1 (role) | 1 (conditional on SSO) | rare-render |
| Onboarding profile | 3 (builder) or 3 (trade) | **defer to /profile/edit** | **−1 page** |
| Onboarding all-set | 0 | **drop page** | −1 page |
| **Total taps to home from email signup** | **~14 taps + 6 fields** | **~5 taps + 3 fields** | **~60 % faster** |

---

## Open questions for the team

1. **Is `/phone-auth` a supported sign-in path** or scaffolding? Decide before next release; either link it from `/login` or delete it.
2. **Does Supabase email confirmation stay enabled in prod?** If yes, `/verify-email` is unavoidable. If no, register can skip straight to onboarding (and the "3 / 3" counter becomes "2 / 2").
3. **Marketing opt-in placement** — legal sign-off needed if we defer it post-signup.
4. **Trade categories** — is the 19-item list the canonical set, or a placeholder? Consider sourcing from `trade_categories` table so it's editable.

---

_Audit produced 2026-05-12 on branch `fix/qol-audit-improvements`._
