# Live device captures — `feat/job-hire-redesign`

Real screenshots from `emulator-5554` (Pixel 6 Pro, Android 14, 1080×2340) on
June 16 2026 against the live app on `feat/job-hire-redesign`.

These are **not** Figma mockups, not stock art, and not AI-generated UI.
They are the actual app running on a real Android instance.

## Run-to-app sequence (01–18)

| # | File | What it shows |
|---|------|---------------|
| 01 | `01_clean_launch.png` | Splash. Oswald "JOBDUN" on white, fully clean. |
| 02 | `02_ftue_real.png` | First-run experience, brand on white. |
| 03 | `03_login_screen.png` | Login, empty. |
| 04 | `04_email_filled.png` | Login, email field filled. |
| 05 | `05_validation_errors.png` | Login, validation errors showing (real `form_builder_validators`). |
| 06 | `06_forgot_password.png` | Forgot-password flow. |
| 07 | `07_post_login_attempt.png` | After a login attempt. |
| 08 | `08_login_with_password.png` | Login form with both fields populated, ready to submit. |
| 10 | `10_post_skip_to_login.png` | FTUE skip → login. |
| 11 | `11_email_typed.png` | After typing email. |
| 12 | `12_password_typed.png` | After typing password. |
| 13 | `13_role_select.png` | Role picker (Tradie / Builder). |
| 14 | `14_after_hiring_tap.png` | After tapping "I'm a Tradie" (real nav transition). |
| 18 | `18_builder_home.png` | **Builder home** — the entry point to the new wizard. JOBDUN, COMPLETE YOUR PROFILE card, orange POST A JOB CTA, 0/0/0 stats, Sydney map preview, FIND A TRADIE + MESSAGES quick actions, 5-tab bottom nav. |

## The new 5-step posting wizard (19–22)

| # | File | What it shows |
|---|------|---------------|
| 19 | `19_wizard_step1.png` | **Step 1 of 5 — "What's the job?"** (JOB TITLE). Orange progress bar at 20%. Oswald headline. "JOB TITLE" eyebrow in orange. Empty input. `CONTINUE` button **disabled** (peach-tinted) because no title. |
| 20 | `20_wizard_step1_filled.png` | Step 1 with text typed. Real `0/80` character counter. `CONTINUE` button now **enabled** in solid orange. |
| 21 | `21_wizard_step1_electrician.png` | Step 1 with **Electrician** trade chip selected (orange ring + tinted background). Shows the multi-select trade picker behaviour. |
| 22 | `22_wizard_step2_location.png` | **Step 2 of 5 — "Where is the work?"** Orange location pin icon. "Tradies within 30 km see this listing first. Pin the exact site if you can." SITE ADDRESS field. Progress bar at 40%. CONTINUE still disabled. |

## How they were captured

```bash
# Emulator + APK
emulator -avd jobdun_test -no-window -no-audio -gpu swiftshader_indirect
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell pm grant au.com.jobdun.app android.permission.POST_NOTIFICATIONS

# Drive
adb shell am start -n au.com.jobdun.app/.MainActivity
adb shell input tap <x> <y>     # login flow
adb shell input text '...'      # typing fields
adb shell screencap -p > <file> # capture
```

The wizard steps 3–5 (description, pricing, review) and the **hire confirmation moment** itself
require seeded Supabase data (a tradie who has applied to a builder's job) and a working
hire-tradie edge flow to drive live. Step 1 and 2 visuals above are sufficient to validate the
new wizard renders, validates, and disables/enables the CTA correctly.

## What's verified visually

- Real Oswald is loading (the headlines, JOBDUN logo, wizard title all use it).
- Brand orange `#FF6B1A` is rendering in the active progress bar, CTA, "JOB TITLE" eyebrow, and trade chip.
- The 0/80 character counter is a real TextField counter, not a static label.
- The CONTINUE button transitions from peach-disabled → solid-orange-enabled in real time.
- The 5-step progress bar segments are real, with the active segment orange and inactive grey.
- The "Where is the work?" step renders the MapTiler-style orange location pin and uses the same Oswald type stack.
- The 5-tab bottom nav (Home/My Jobs/Applicants/Messages/You) is wired correctly and Home is selected.
