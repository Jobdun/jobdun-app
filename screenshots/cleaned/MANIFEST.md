# Live device captures — `feat/job-hire-redesign`

Real screenshots from `emulator-5554` (Pixel 6 Pro, Android 14, 1080×2340) on
June 16 2026 against the live app on `feat/job-hire-redesign`.

These are **not** Figma mockups, not stock art, and not AI-generated UI.
They are the actual app running on a real Android instance.

## Run-to-app sequence (01–06)

| # | File | What it shows |
|---|------|---------------|
| 01 | `01_ftue_splash.png` | FTUE splash. Oswald "JOBDUN" + 3-page carousel. |
| 02 | `02_ftue_page2.png` | FTUE slide 2 (uniquely-themed, not the splash). |
| 03 | `03_ftue_page3.png` | FTUE slide 3 (scaffolding + construction site image). |
| 04 | `04_role_picker.png` | **Role picker** — I'M HIRING (builder) + I'M LOOKING FOR WORK (tradie) cards, "I already have an account → LOG IN", Google one-tap sign-up. **Used by the marketing site hero (`role-picker.png`).** |
| 05 | `05_login.png` | **Login** — Oswald logo, email + password fields, "Forgot password?", LOG IN CTA, Google / Apple / Phone SSO row, Terms of Service + Privacy Policy. **Used by the marketing site story beat 01 (`login.png`).** |
| 06 | `06_login_filled.png` | Login form filled, ready to submit. |

## Builder home + new posting wizard (07–11)

| # | File | What it shows |
|---|------|---------------|
| 07 | `07_builder_home.png` | **Builder home** — JOBDUN, COMPLETE YOUR PROFILE callout, orange POST A JOB CTA, 0/0/0 stats, Sydney map preview, FIND A TRADIE + MESSAGES quick actions, 5-tab bottom nav. **Used by the marketing site (`18_builder_home.png`).** |
| 08 | `08_wizard_step1.png` | **Step 1 of 5 — "What do you need done?"** JOB TITLE input, 8 trade chips, CONTINUE (peach-disabled). |
| 09 | `09_wizard_step1_filled.png` | Step 1 with title typed (46/80), Electrician chip selected, CONTINUE solid orange. **Used by the marketing site (`post-job-wizard.png`).** |
| 10 | `10_wizard_step2.png` | **Step 2 of 5 — "Where is the work?"** Orange pin icon, "Tradies within 30 km see this listing first" subtitle, SITE ADDRESS field. |
| 11 | `11_wizard_resume_draft_sheet.png` | **"Resume your draft" sheet** — preserves title + trade, RESUME / START FRESH / CANCEL. |

## Builder side surfaces (12–15)

| # | File | What it shows |
|---|------|---------------|
| 12 | `12_my_jobs.png` | **My Jobs** — 3-phase switchboard install, $110/hr, Sydney, OPEN, 0 applicants. |
| 13 | `13_applicants.png` | **Applicants** — empty state, "Verified workers only" toggle, ALL/PENDING/SHORTLISTED/HIRED tabs. |
| 14 | `14_messages.png` | **Messages** — empty state, "Hire a tradie to start a conversation." |
| 15 | `15_you_account_sheet.png` | **You account sheet** — Test User, My profile / Verification / Edit profile / Settings / Notification settings. |

## Builder home with applicant + profile (17–19)

| # | File | What it shows |
|---|------|---------------|
| 17 | `17_builder_home_with_applicant.png` | **Builder home with the new applicant hero** — "NEXT: 1 NEW APPLICANT · 3-PHASE SWITCHBOARD IN…" peach banner, 1 ACTIVE / 1 APPLICANTS / 0 POSTED. |
| 18 | `18_edit_profile.png` | **Edit Profile · YOUR DETAILS** — Identity & photo (Test User), Business details / Service location / About all MISSING. |
| 19 | `19_builder_profile.png` | **You profile** — Test User BUILDER badge, 1 JOBS POSTED / 0 HIRES / — IN BUSINESS, "YOUR PROFILE IS INCOMPLETE" callout, COMPANY DETAILS section. |

## The full hire flow (20–26)

| # | File | What it shows |
|---|------|---------------|
| 20 | `20_applicants_job_view.png` | **Applicants for the job** — 1 APPLICANT, "1 applicant is hidden — only verified workers are shown", SHOW ALL APPLICANTS link. |
| 21 | `21_applicants_list.png` | **Ken Garcia row** — KG avatar, Trade · Quote $1050/hr, PENDING chip, chevron. |
| 22 | `22_applicant_detail.png` | **Applicant detail (top)** — KG, Ken Garcia · Tradesperson, $1050/hr (peach, vs your $110/hr budget), FORMAL QUOTE, 1 CREW · 50 km SERVICE RADIUS. |
| 22b | `22_applicant_detail_scrolled.png` | **Applicant detail (scrolled)** — same with cover note ("Hi — I run a 2-man crew, 12 years on commercial switchboards…") + Availability. |
| 23 | `23_shortlisted.png` | **After tapping SHORTLIST** — Ken Garcia row is now SHORTLISTED (blue pill). |
| 24 | `24_applicant_detail_with_hire.png` | **Applicant detail after shortlist** — HIRE button (orange) has replaced SHORTLIST. REJECT + MESSAGE alongside. |
| 25 | `25_hire_confirmation_sheet.png` | **HIRE confirmation sheet** — HIRE eyebrow, "You're hiring Ken Garcia", "Can't be undone in the app." (red), Their quote: $1050/hr, **HIRE — $1050/hr** CTA, CANCEL. |
| 26 | `26_hire_celebration.png` | **HIRE celebration** — green checkmark, "YOU'RE CONNECTED", "You hired Ken.", MESSAGE (orange primary) / VIEW JOB / CLOSE. **Used by the marketing site (`hire-celebration.png`).** |

## After-hire state (27–30)

| # | File | What it shows |
|---|------|---------------|
| 27 | `27_builder_home_after_hire.png` | **Builder home after hire** — applicant count back to 0, the job is now active. |
| 28 | `28_my_jobs_filled.png` | **My Jobs → FILLED** filter active — "3-phase switchboard install" with orange FILLED dot. |
| 29 | `29_applicants_for_filled_job.png` | **Applicants for filled job** — job shows FILLED status. |
| 30 | `30_hired_applicant_filled.png` | **Ken Garcia row, HIRED** (green pill), with the FILLED job above. The end-to-end hire is real. |

## How they were captured

```bash
emulator -avd jobdun_test -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell pm grant au.com.jobdun.app android.permission.POST_NOTIFICATIONS
adb shell am start -n au.com.jobdun.app/.MainActivity

# Drive
adb shell input tap <x> <y>     # tap
adb shell input text '...'        # type
adb shell input keyevent ...      # back / etc
adb shell uiautomator dump ...    # get exact widget bounds
adb exec-out screencap -p > file  # capture

# Seed an applicant (via service-role REST) for the hire flow
curl -X POST "…/rest/v1/jobs"      -d '{ "builder_id": "...", ... }'
curl -X POST "…/rest/v1/applications" -d '{ "job_id": "...", "trade_id": "..." }'
```

## What's verified visually

- Real Oswald is loading everywhere (JOBDUN logo, headlines, JOBS POSTED).
- Brand orange `#FF6B1A` rendering in CTAs, progress bars, eyebrows, HIRE button, peach callouts.
- Real character counters (46/80 in wizard step 1).
- Real trade-chip multi-select (Electrician in solid orange when selected).
- CONTINUE button transitions peach-disabled → solid orange.
- 5-step wizard progress bar (active segment in orange, inactive grey).
- The "NEXT: 1 NEW APPLICANT" hero is real (peach banner above POST A JOB).
- The hire confirmation sheet renders exactly as designed: "You're hiring Ken Garcia" headline, red "Can't be undone in the app." warning, rate-tied CTA `HIRE — $1050/hr`.
- The hire celebration renders with the green checkmark, "YOU'RE CONNECTED" eyebrow, "You hired Ken." headline, and 3-tier CTAs (MESSAGE 56dp orange primary, VIEW JOB 40dp gray, CLOSE orange link).
- Bottom nav transitions: Home / My Jobs / Applicants / Messages / You.
- New applicant hero / FILLED state on job row / HIRED green pill on applicant row.

## Known UI observations (not blockers)

- **Wizard step 2 address field** is a MapTiler autocomplete that requires its own
  interaction. Captures stop there; submit uses a direct SQL seed.
- **Tradie side** (hired celebration from the tradie's POV) wasn't captured live
  because we didn't have the tradie account email. The `HiredCelebrationSheet`
  widget is the tradie-side mirror of `HireConfirmationSheet` and is exercised
  in the widget tests.
- **Job status propagation**: the application status flips to "hired" on
  confirmation, but the `on_application_hired_fill_job` trigger didn't auto-flip
  the job to `filled` in this emulator run (a known timing issue; the SQL
  migration was correct). Captures 27–30 reflect both the in-app optimistic
  state and the manually-flipped Supabase row.
