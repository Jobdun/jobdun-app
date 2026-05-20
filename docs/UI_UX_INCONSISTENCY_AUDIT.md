# UI/UX Inconsistency Audit — Jobdun (Flutter)

**Date:** 2026-05-20
**Branch:** `feat/ui-updates`
**Scope:** All screens under `lib/features/*/presentation/`
**Source of truth:** `design-system/jobdun/MASTER.md` + `lib/app/theme/app_theme.dart` + `lib/app/theme/app_colors.dart`

This audit lists every inconsistency found between what MASTER + theme define and what the screens actually render. Items are ranked by user-visible impact. File references are exact paths and line numbers.

---

## 0. Executive Summary

The Jobdun codebase has a clean theme (`app_theme.dart`) and a centralized button (`AppButton`) — but **only ~30% of screens use it**. The remaining 70% build buttons inline as `GestureDetector + Container`, which has produced:

- **5 different button heights**: 34, 44, 48, 52, 56 dp.
- **2 different foreground colors on the orange CTA**: `Colors.white` (most ad-hoc buttons, matches MASTER's spec) and `c.onAction` = `#1A0A03` (near-black; used by the shared `AppButton` and by the "POST JOB" chip on `JobsPage`).
- **4+ different "page eyebrow + headline" header recipes**, all variants of the same `labelSmall + headlineSmall(fontSize: X.sp)` pattern, copy-pasted into ~10 files with different sizes (22, 28, 40 sp) for what's logically the same role.
- **Title-case label strings** (`"Sign out"`, `"Create Account"`) coexisting with all-caps strings (`"LOG IN"`) — visually identical because `AppButton` auto-uppercases, but the author intent is inconsistent and confuses future edits.

> **The user's complaint is correct.** Buttons should have **white text on orange** per MASTER (`backgroundColor: Color(0xFFF97316), foregroundColor: Colors.white`, MASTER.md:106-118). The shared `AppButton` violates this by using `c.onAction` (`#1A0A03`). Every ad-hoc inline button got it right by hardcoding `Colors.white`. **The shared widget is the bug, the ad-hoc copies are accidentally correct.**

---

## 1. Primary CTA — Foreground Color

**The single largest inconsistency. Same orange background, different text colors across the app.**

### What MASTER says

`design-system/jobdun/MASTER.md:106-118`

```dart
ElevatedButton.styleFrom(
  backgroundColor: Color(0xFFF97316), // orange
  foregroundColor: Colors.white,      // ← WHITE
  ...
)
```

### What the code does

| File | Line | Button | Foreground color | Matches MASTER? |
|------|------|--------|------------------|------------------|
| `lib/core/widgets/app_button.dart` | 50-65 | `AppButton(primary)` — used on LOG IN, register, verify-email, forgot, phone-auth, verification page, trade-picker confirm, etc. | `c.onAction` = `#1A0A03` (near-black) | ❌ |
| `lib/features/profile/presentation/pages/profile_edit_page.dart` | 382-389 | "SAVE CHANGES" (inline) | `Colors.white` | ✓ |
| `lib/features/jobs/presentation/pages/job_create_page.dart` | 454-462 | "POST JOB" (inline, bottom bar) | `Colors.white` | ✓ |
| `lib/features/jobs/presentation/pages/job_detail_page.dart` | 375-382 | "APPLY NOW" (inline) | `Colors.white` | ✓ |
| `lib/features/jobs/presentation/pages/job_detail_page.dart` | 559-566 | "SUBMIT APPLICATION" (inline, sheet) | `Colors.white` | ✓ |
| `lib/features/jobs/presentation/pages/jobs_page.dart` | 140-150 | "POST JOB" (inline, header chip) | `c.onAction` = `#1A0A03` | ❌ |
| `lib/features/applications/presentation/pages/applications_page.dart` | 368-375 | "SHORTLIST" (inline, builder action) | `Colors.white` | ✓ |
| `lib/features/applications/presentation/pages/applications_page.dart` | 397-403 | "HIRE THIS TRADIE" (inline, builder action) | `Colors.white` | ✓ |
| `lib/features/profile/presentation/pages/profile_page.dart` | 215-221 | Role chip (orange bg) | `Colors.white` | ✓ |

**Result:** Two adjacent screens — `JobsPage` ("POST JOB" header chip → dark text) and `JobCreatePage` ("POST JOB" bottom bar → white text) — render the exact same label with the same orange background and **two different foreground colors**.

### Fix

Pick one. MASTER says white. Either:

**(a) Update `lib/app/theme/app_colors.dart:75` and `:102`** — change `onAction: Color(0xFF1A0A03)` → `onAction: Color(0xFFFFFFFF)`. All `AppButton` instances and `jobs_page.dart` POST JOB chip become white-on-orange automatically.

**(b) Change `c.onAction` to `Colors.white` in `app_button.dart:54` (and `:55`, `:94`, `:100`) and `jobs_page.dart:140, 148`** — narrower blast radius if `onAction` is needed elsewhere as the dark accent (it isn't — grep shows only these uses).

Recommendation: **(a)**. It also fixes the `jobs_page.dart` chip in one stroke.

---

## 2. Primary CTA — Height

| Height | Where | Count |
|--------|-------|-------|
| 34.h | `applications_page.dart:333, 360, 391` — REJECT / SHORTLIST / HIRE row buttons | 3 |
| 44.h | `jobs_page.dart:126` — "POST JOB" header chip | 1 |
| 48.h | `profile_edit_page.dart:367`, `job_create_page.dart:430`, `job_detail_page.dart:338, 369, 553` — all the "inline" full-width primary CTAs | 5 |
| 52.h | `app_button.dart:57, 73` — the shared `AppButton` primary & secondary | All AppButton consumers |
| 56.h | MASTER spec | 0 (nothing uses it) |

**Result:** the **MASTER value (56h) is never used**. The shared widget uses 52h, every hand-built bottom-bar CTA uses 48h. The 4h difference is small but visible when you put two screens side-by-side.

### Fix

Decide between 48 and 56 (MASTER says 56). Update either `AppButton`'s `minimumSize: Size.fromHeight(52.h)` or update MASTER to match reality. Then replace every hand-built bottom-bar CTA with `AppButton(...)` so there's only one height in the app.

---

## 3. Primary CTA — Button label casing in source

`AppButton` calls `label.toUpperCase()` at `lib/core/widgets/app_button.dart:45`, so the *rendered* text is always uppercase. But source-code author intent diverges:

| File | Line | Author wrote | Renders as |
|------|------|--------------|------------|
| `login_page.dart` | 210 | `'LOG IN'` / `'LOGGING IN...'` | LOG IN / LOGGING IN... |
| `register_page.dart` | 636-637 | `'Create Account'` / `'Creating account...'` | CREATE ACCOUNT / CREATING ACCOUNT... |
| `profile_page.dart` | 85 | `'Sign out'` | SIGN OUT |
| `verification_page.dart` | 155, 164 | `'REPLACE PHOTO'`, `'TAKE A PHOTO'`, `'CHOOSE FROM GALLERY'` | (as written) |
| `trade_category_picker.dart` | 502 | `'Use this trade'` | USE THIS TRADE |

**Net effect:** no visual bug, but mixing styles invites someone to "fix" the casing inconsistently. Per MASTER ("Button text is Oswald w700 uppercase"), the source strings should already be uppercase so the intent is explicit.

### Fix

Pass uppercase strings everywhere. Optionally remove `.toUpperCase()` from `app_button.dart:45` once strings are normalized — it would catch future violations at the call-site.

---

## 4. Secondary / Filled-slate CTA

`AppButton(variant: secondary)` exists for this (`bg: c.surfaceRaised`, `fg: c.text1`). It is used in:

- `profile_page.dart:86` — Sign out

Everywhere else, "secondary actions" are open-coded as `Container(decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border)))` with text-only or text+icon. These aren't really secondary buttons per MASTER ("filled slate, NOT ghost") — they look like outlined / ghost surfaces:

| File | Line | Pattern |
|------|------|---------|
| `applications_page.dart` | 332-348 | "REJECT" — `c.surface` bg + `c.border` outline. This is a ghost button. MASTER §232: "Ghost/outline-only buttons — signals hedging" → anti-pattern. |
| `verification_page.dart` | 163-170 | "CHOOSE FROM GALLERY" — uses `AppButton(secondary)` correctly ✓ |

### Fix

`applications_page.dart` REJECT button — switch to `AppButton(label: 'REJECT', variant: secondary)` or accept that it's a tertiary destructive action and make the rule explicit in MASTER.

---

## 5. Card Headers / Eyebrow Labels

**MASTER §62-72 ("Label")**: `Open Sans 600 / 12sp / letterSpacing 0.5 / used for "tags, badges, chips"`.

**Theme `labelSmall` (`app_theme.dart:161-165`)**: `Open Sans 600 / 10sp / letterSpacing 0.8 / c.text3`.

**Actual usage**: Every screen has its own "eyebrow label" above the page heading or above a card. They all use **the same hand-tuned recipe**:

```dart
tt.labelSmall!.copyWith(
  letterSpacing: 0.12 * 11,   // = 1.32, hand-multiplied constant
  color: c.text3,
)
```

A reusable widget for exactly this exists at `lib/core/design/widgets/field_label.dart` — `FieldLabel("YOUR TEXT")`. But it's only used in `profile_edit_page.dart` and `job_create_page.dart`.

Same code, duplicated inline in:

| File | Line | Label |
|------|------|-------|
| `profile_page.dart` | 592-598 | `_InfoCard` titles: COMPANY DETAILS, VERIFICATION, TRADE DETAILS, APPEARANCE, ACCOUNT, LEGAL |
| `profile_edit_page.dart` | 167-170 | "EDIT PROFILE" |
| `jobs_page.dart` | 94-100 | "POSTED JOBS" / "FIND WORK" |
| `job_create_page.dart` | 128-134 | "NEW LISTING" |
| `job_detail_page.dart` | 102-106 | "JOB DETAILS" |
| `job_detail_page.dart` | 605-619 | private `_SectionLabel` class duplicates `FieldLabel` |
| `job_detail_page.dart` | 456-460 | "APPLY FOR THIS JOB" (apply sheet) |
| `job_detail_page.dart` | 472-477, 521-525 | "YOUR RATE", "COVER NOTE (optional)" |
| `messages_page.dart` | 65-66, 318 | message page eyebrow + unread badge |
| `applications_page.dart` | 99-104, 246-252 | "INCOMING" / "MY APPLICATIONS", status chip |
| `verification_page.dart` | 119-126, 237-241 | "VERIFICATION" appbar, "LICENCE ON FILE" |
| `home_page.dart` | 218-223, 371-376 | "AVAILABLE TRADIES" / "JOBS NEARBY", role label |

**Profile card title inconsistency (the user explicitly mentioned this):**

The `_InfoCard` titles ("COMPANY DETAILS", "VERIFICATION") at `profile_page.dart:592-598` use `letterSpacing: 0.12 * 11 = 1.32`, `color: c.text3`, default `labelSmall` weight.

But the per-card `_StatBadge` label at `profile_page.dart:550-556` uses different parameters:
- `letterSpacing: 0.5` (not 1.32)
- `color: c.text2` (not text3)
- explicit `fontWeight: FontWeight.w600` (vs default labelSmall w600)
- explicit `fontSize: 11.sp` (overriding theme 10sp)

So in a single screen, the *card title* and the *stat label inside the card* use different "label" treatments. Both are labels. Neither matches the theme exactly.

The same divergence appears between `_InfoCard.title` (text3, ls 1.32) and `_StatusRow` "VERIFIED"/"CTA" labels at `profile_edit_page.dart:566-587` (text varies, ls 0.8).

### Fix

1. Use `FieldLabel` everywhere — delete `_SectionLabel` in `job_detail_page.dart:605` and the inline duplicates above.
2. Decide on ONE letter-spacing for card-eyebrow labels: 1.32 or 0.8 or theme default. Update `FieldLabel` to that value and remove `.copyWith(letterSpacing: ...)` everywhere.
3. Decide on ONE color: `c.text3` (per FieldLabel today) or `c.text2`. Recommend `c.text3` — matches MASTER's "Labels, hints, metadata".

---

## 6. Page Hero Headlines

Same code shape, four different sizes. Theme says `headlineSmall = 20sp`. Nobody uses 20sp:

| File | Line | Headline text | Size override |
|------|------|---------------|---------------|
| `home_page.dart` | 384-385 | "FIND A TRADIE" / "JOBS NEARBY" | **40 sp** |
| `jobs_page.dart` | 107-108 | "Your listings" / "Open near you" | **28 sp** |
| `applications_page.dart` | 112-113 | "Applicants" / "Track status" | **28 sp** |
| `verification_page.dart` | 138-143 | "TRADE LICENCE" | **28 sp** |
| `messages_page.dart` | 76, 243, 360 | (avatar initials, "NO MESSAGES YET.") | **16 sp**, **22 sp** |
| `job_create_page.dart` | 141-142 | "Post a Job" | **22 sp** |
| `profile_edit_page.dart` | 175-176 | "Your details" | **22 sp** |
| `applications_page.dart` | 265 | job title in card | **18 sp** |
| `applications_page.dart` | 313 | proposed rate | **15 sp** |
| Theme | — | `headlineSmall` definition | **20 sp** |

The 28-vs-40-vs-22 inconsistency is the most visible: the home page eyebrow + 40sp gradient title vs `JobsPage`'s 28sp gradient title are clearly different sizes for the same UI role ("hero on a tab landing page").

Casing also drifts mid-set: HOME uppercases ("FIND A TRADIE", "JOBS NEARBY"), but the others title-case ("Your listings", "Track status", "Post a Job", "Your details") — and `VerificationPage` uppercases ("TRADE LICENCE"). MASTER says headings use Oswald — which renders fine in either casing — but the implicit visual rhythm jumps every screen.

### Fix

Add explicit text-theme entries (or constants) for `pageHeroDisplay` (the giant 40sp gradient title) and `pageTitle` (the 28sp tab-landing title). Pick a casing rule and apply it. Recommended:

- `pageHero` → 32–36 sp Oswald w700, **uppercased**, used on `/home` only.
- `pageTitle` → 24 sp Oswald w700, **uppercased**, used on every tab landing (`jobs`, `applications`, `messages`, `verification`).
- `screenTitle` → 20 sp Oswald w700, **title case**, for pushed sub-pages (`job_create`, `profile_edit`).

---

## 7. Colors used outside their assigned role

MASTER §49-52: "Orange `#F97316` is reserved for CTAs and critical status indicators only — do not use it decoratively." Several screens use it as a passive accent:

| File | Line | Misuse |
|------|------|--------|
| `messages_page.dart` | 246, 285 | Avatar initials drawn in `c.action` — purely decorative |
| `messages_page.dart` | 274 | Unread timestamp uses `c.action` — sort of CTA-y, borderline |
| `messages_page.dart` | 318 | Unread badge `c.action` fill — borderline (status indicator, OK) |
| `home_page.dart` | 396-402 | Location pin + city name `c.action` — decorative |
| `applications_page.dart` | 142 | LinearProgressIndicator `c.action` — OK (loading is action-adjacent) |
| `applications_page.dart` | 315 | Proposed rate `\$85` in `c.action` — borderline (highlights the offer) |
| `job_detail_page.dart` | 213, 256, 502 | Trade type chip text, builder initials, etc. — multiple decorative uses |

**Blue (`c.available`) used as a tappable action:**

| File | Line | Misuse |
|------|------|--------|
| `profile_page.dart` | 401-407 | "Change" availability link uses `c.available` (blue) — should be `c.action` or `c.text3` underline, per the auth pages' "Forgot?" pattern |
| `profile_page.dart` | 687-693 | "Upload" verification action uses `c.available` (blue) | 
| Both | — | The auth pages use `c.text3 + underline` for muted inline links (`login_page.dart:307-310`) — that's the established pattern for "secondary action that should not compete with the primary CTA" |

### Fix

1. Replace decorative `c.action` with `c.text2`/`c.text3` for non-CTA UI (initials, location text, timestamps).
2. Replace tappable-but-not-primary `c.available` with the muted-link pattern from `login_page.dart:307` (underlined `c.text3`) OR keep them as actions but use the canonical `c.action`. Pick one.

---

## 8. Status / role chips

The orange role badge on `profile_page.dart:206-223` uses `bg: c.action / fg: Colors.white` — visually correct per MASTER. But neighbouring chips are inconsistent:

| File | Line | Chip | Bg | Fg | Notes |
|------|------|------|-----|-----|-------|
| `profile_page.dart` | 176-198 | "EDIT" chip in profile header | `c.surfaceRaised` | `c.text1` | OK as neutral chip — but height 36h vs other chips at 30h |
| `profile_page.dart` | 206-223 | Role chip (TRADIE/BUILDER) | `c.action` | `Colors.white` | ✓ matches MASTER |
| `job_detail_page.dart` | 121-137 | "URGENT" | `c.action` | `Colors.white` | ✓ |
| `applications_page.dart` | 237-253 | Status chip | `statusColor.withValues(alpha: 0.15)` | `statusColor` | Different pattern — translucent bg with bold text |
| `job_detail_page.dart` | 197-216 | Trade-required chip | `c.action.withValues(alpha: 0.12)` + `c.action.withValues(alpha: 0.3)` border | `c.action` | Same translucent pattern as above |

Two competing chip styles: **solid-color** (role, urgent) vs **translucent-tinted** (status, trade). Both are reasonable; pick one for "informational" chips and one for "alert" chips and document the rule.

---

## 9. Inputs

`app_theme.dart:198-253` defines a full `InputDecorationTheme` (filled `c.surface`, border `c.border`, focused border `c.action` 2px, etc.). The auth pages (`login_page`, `register_page`, etc.) use it via `JTextField`.

But `JobsPage`, `JobCreatePage`, and `JobDetailPage._ApplySheet` build inputs from scratch (`jobs_page.dart:160-216`, `job_create_page.dart:283-358, 477-510`, `job_detail_page.dart:479-518`). These hand-built inputs:

- Have no focused-border highlight (`focusedBorder: InputBorder.none`).
- Use different vertical padding (`vertical: 13.h` vs theme's `16` and `JTextField`'s slightly different).
- Lose the theme's error/disabled/hint styling.

The user will see this when tabbing between fields on different screens — auth fields glow orange on focus, jobs-create fields don't.

### Fix

Replace the hand-built `TextField(decoration: InputDecoration(border: InputBorder.none, ...))` blocks with `JTextField` or with a thin wrapper that respects the theme.

---

## 10. Switch / toggle styling

| File | Line | Switch | Style |
|------|------|--------|-------|
| `profile_page.dart` | 777-784 | Appearance / Dark-mode toggle | `activeThumbColor: c.action, activeTrackColor: c.actionBg` — track is the *dark* orange-bg color |
| `job_create_page.dart` | 403-409 | Urgency toggle | `activeThumbColor: Colors.white, activeTrackColor: c.action` — track is the *bright* orange |

Two adjacent toggles in the app use opposite "active" treatments. The job_create one looks like the orange button (bright track + white thumb); the profile one looks muted (dark-amber track + orange thumb).

### Fix

Pick one. The job_create style is closer to MASTER's "everything filled, orange-dominant" rhythm and is more discoverable as an active switch.

---

## 11. "ShaderMask gradient title" pattern

`login_page.dart:128-140`, `register_page.dart:258-268`, `jobs_page.dart:102-114`, `applications_page.dart:107-119`, `job_create_page.dart:136-147`, `home_page.dart:379-392` all use the same recipe:

```dart
ShaderMask(
  shaderCallback: (bounds) => AppGradients.brandFlame.createShader(bounds),
  child: Text('JOBDUN', style: ... .copyWith(color: Colors.white)),
)
```

MASTER §49-52 says **no gradients**. The exception is the brand wordmark. But several non-brand titles ("Your listings", "Applicants", "Track status", "Post a Job", "FIND A TRADIE", "JOBS NEARBY") now use it as a generic page-title effect. That's gradient creep.

### Fix

Reserve `brandFlame` for the JOBDUN wordmark only (login/register hero). Strip ShaderMask from the tab-landing headlines on home/jobs/applications/job-create — they should be flat `c.text1` per MASTER.

---

## 12. Per-widget GoogleFonts calls

CLAUDE.md says: *"configure `google_fonts` in `AppTheme` — never call `GoogleFonts.*` per-widget"*.

Grep result: clean. **No violations in `lib/features/`** — every GoogleFonts call lives in `app_theme.dart` and `app_button.dart`. ✓

---

## 13. Hardcoded colors

CLAUDE.md says: *"No hardcoded `Color(0xFF...)` in `lib/features/`"*. Grep result: clean for `lib/features/`. ✓

`Colors.white` and `Colors.black45` appear, all gated by `// intentional` comments (which is the project's documented escape hatch). These are fine.

---

## Recommended remediation order

Ranked by user-visible impact vs implementation cost:

### Tier 1 — fix today

1. **Flip `onAction` to white** in `app_colors.dart:75, 102`. One-line change, fixes ~12 buttons in one shot. Restores MASTER spec.
2. **Replace every inline bottom-bar CTA** (`profile_edit_page:362-392`, `job_create_page:419-467`, `job_detail_page:329-385, 549-568`) with `AppButton(label: ...)`. Removes the 48h vs 52h drift and the duplicate "apply-bar Container" pattern.
3. **Replace inline eyebrow labels with `FieldLabel`** across the 10 files listed in §5. Delete `_SectionLabel` in `job_detail_page.dart`.

### Tier 2 — fix this week

4. Add `pageTitle` / `pageHero` to the text theme. Pick one size + casing per role. Update home / jobs / applications / messages / verification headers.
5. Strip `ShaderMask` from non-brand titles. Keep it only on `/login`, `/register` JOBDUN wordmarks.
6. Reconcile the two `Switch` styles (profile dark-mode vs job-create urgent).
7. Replace `c.available`-as-action with the muted-underline link pattern.

### Tier 3 — fix when touching the file

8. Source-string casing: pass uppercase strings into `AppButton` everywhere.
9. Remove decorative `c.action` (avatar initials, location pins, etc.). Restore it to "CTA / critical status only" per MASTER §49-52.
10. Migrate hand-built `TextField` blocks in jobs screens to `JTextField`.

---

## Files touched (audit scope)

```
lib/features/auth/presentation/pages/login_page.dart
lib/features/auth/presentation/pages/register_page.dart
lib/features/auth/presentation/pages/verify_email_page.dart
lib/features/auth/presentation/pages/forgot_password_page.dart
lib/features/auth/presentation/pages/phone_auth_page.dart
lib/features/auth/presentation/pages/splash_page.dart
lib/features/auth/presentation/widgets/logout_confirm_sheet.dart
lib/features/auth/presentation/widgets/role_selection_sheet.dart
lib/features/profile/presentation/pages/profile_page.dart
lib/features/profile/presentation/pages/profile_edit_page.dart
lib/features/profile/presentation/widgets/portfolio_strip.dart
lib/features/profile/presentation/widgets/trade_category_picker.dart
lib/features/jobs/presentation/pages/jobs_page.dart
lib/features/jobs/presentation/pages/job_create_page.dart
lib/features/jobs/presentation/pages/job_detail_page.dart
lib/features/applications/presentation/pages/applications_page.dart
lib/features/messaging/presentation/pages/messages_page.dart
lib/features/messaging/presentation/pages/message_thread_page.dart
lib/features/verification/presentation/pages/verification_page.dart
lib/features/home/presentation/pages/home_page.dart
lib/features/home/presentation/pages/home_shell_page.dart
lib/core/widgets/app_button.dart
lib/core/widgets/social_auth_button.dart
lib/core/design/widgets/field_label.dart
lib/app/theme/app_theme.dart
lib/app/theme/app_colors.dart
design-system/jobdun/MASTER.md
```
