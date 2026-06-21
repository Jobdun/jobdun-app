# Auth / Onboarding Page Overrides

> **PROJECT:** Jobdun
> **Updated:** 2026-05-07
> **Page Type:** Authentication + Onboarding

> ⚠️ **IMPORTANT:** Rules in this file **override** the Master file (`design-system/MASTER.md`).

---

## Design Intent

The auth screen is the first impression. It should feel like stepping onto a job site — not opening a startup app. Dark, heavy, confident. The user isn't being welcomed with a hug. They're being told: this is where you work.

---

## Layout

**Login Screen:**
1. Full-screen dark background (`#0F172A`)
2. Top 40% — Logo + bold identity statement
3. Middle — Input fields (email + password), stacked
4. Bottom — Primary CTA button, then account creation link below it
5. No hero image. No device mockup. No illustration.

**Register Screen:**
1. Same dark background
2. Role selection first (Builder vs Trades) — two large filled cards, pick one
3. Then fields for that role
4. Single "CREATE ACCOUNT" CTA at the bottom

**Onboarding (post-register):**
1. 3–4 screens max, swipeable
2. No unskippable linear tour — Skip always visible top-right
3. Each screen: one bold statement (Display weight) + one sentence body + page dots
4. Final screen: single "GET TO WORK" CTA (orange, full-width)

---

## Color Overrides

No color overrides — the dark palette from MASTER applies exactly here.
Background `#0F172A`, surface `#1E293B` for input fills.

---

## Typography Overrides

**Logo/Brand treatment:**
- "JOBDUN" in Archivo ExtraBold (800), letter-spacing 0.5, all caps, white `#F1F5F9`
- Tagline (if used): Inter Medium (500), `#94A3B8`, smaller — secondary, not competing

**Auth screen headline:**
- Do NOT use soft welcome copy like "Welcome back" or "Sign in."
- Use declarative statements: "YOUR NEXT JOB IS HERE." or no headline at all.
- If a subhead is needed, keep it under 6 words. No explanation needed.

---

## Component Overrides

### Logo Block
- Heavy wordmark treatment — thick, all-caps, no thin strokes
- Optional: construction icon (hard hat, beam, wrench via `AppIcons`) in `c.action` before the word
- No thin-line logo, no illustrated mascot

### Primary CTA Button
- Full-width, 56dp height, 6dp border radius
- Background: `#F97316` (orange)
- Text: "LOG IN" — all caps, Inter Bold (700), letter-spacing 1.0
- No icon in the button — text only

### Secondary Action (create account)
- Full-width, 56dp height, 6dp border radius
- Background: `#334155` (slate surface raised)
- Text: "CREATE ACCOUNT" — all caps, Inter Bold (700)
- Placed below primary CTA with Gap(12) between them
- NOT a ghost button. NOT a text link.

### SSO (Google / Apple)
- Demoted to tertiary — small text links only, below both main buttons
- Format: "Or continue with  Google  ·  Apple" — `#94A3B8` text, 12sp
- No large SSO brand buttons. They import another brand's visual language.
- No divider with "or" between — just small text below.

### Input Fields
- Follow Master input spec exactly (dark fill, orange focus border)
- Labels: uppercase, Inter SemiBold (600), 11sp, `#94A3B8`, letter-spacing 0.5
- Placeholder: all lowercase, `#64748B`
- No floating labels — fixed labels above the field
- Password field: show/hide toggle with `AppIcons.eyeOpen`/`AppIcons.eyeClosed` in `c.text2` (handled inside `JTextField` when `obscureText: true`).

### Error States
- Inline below the field — red `#EF4444`, 12sp, no icon
- Border turns red on error
- No modal/snackbar for validation errors — inline only

### Role Selection Cards (Register)
- Two cards side by side, full available width, equal size
- Background: `#1E293B`, border `#334155`
- Selected: border `#F97316` (2dp), background `#1E293B`
- Icon (`AppIcons.*`): 32dp, `c.action` when selected, `c.text3` unselected
- Label: "BUILDER" / "TRADES" — Inter Bold (700), 14sp, all caps
- Sub-label: one-line role description — `#94A3B8`, 12sp

---

## Copy Guidelines

| Element | Do | Don't |
|---------|-----|-------|
| Primary CTA | "LOG IN" | "Sign in" / "Continue" |
| Create account | "CREATE ACCOUNT" | "Sign up" / "Join Jobdun" |
| Onboarding final | "GET TO WORK" | "Let's go!" / "Get started" |
| Forgot password link | "FORGOT PASSWORD" | "Forgot your password?" |
| Error message | "Invalid email or password." | "Oops! Something went wrong." |
| Empty email | "Email is required." | "Please enter your email address to continue." |

---

## Onboarding Screens

3 screens only. No animations between cards except a horizontal swipe (150ms ease).

| Screen | Headline (Display, 900) | Body (14sp, Medium) |
|--------|------------------------|---------------------|
| 1 | "FIND JOBS. GET PAID." | Browse verified construction jobs near you. |
| 2 | "YOUR CREW, YOUR TERMS." | Set your availability. Work when you want. |
| 3 | "VERIFIED. TRUSTED." | Upload your certs. Builders hire who they trust. |

Page dots: `smooth_page_indicator`, `ExpandingDotsEffect`, active `#F97316`, inactive `#334155`.
Skip button: top-right, `#94A3B8`, Inter SemiBold, "SKIP" — not a ghost button, just text.

---

## What to Avoid

- ❌ Friendly welcome copy ("Welcome to Jobdun!", "We're glad you're here")
- ❌ Large Google/Apple SSO buttons as primary auth option
- ❌ Light or white background on any auth screen
- ❌ Illustrated characters or mascots
- ❌ "Forgot your password?" as a long question — use "FORGOT PASSWORD" as a link
- ❌ Progress steps (Step 1 of 3) on login — that's for long multi-step flows only
- ❌ Auto-advancing onboarding slides
- ❌ Unskippable onboarding
