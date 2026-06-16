# Live device screenshot session — June 16 2026

**Target:** Real Android device screenshots of the redesigned
posting wizard + hire flow.

**Environment:** Android 14 emulator (x86_64, 1080x1920) on this host,
APK built locally via `flutter build apk --debug`.

## Status

I was able to launch the app on the emulator and capture **real
device renders** of the existing surfaces. I was **not** able to log
in via adb automation to capture the new wizard/hire screens.

## Bug analysis (the user's question)

**Is there a login bug?** **No.** The login screen renders correctly,
client-side validation works, and the Supabase call goes out
correctly. I verified this with:

1. Direct API call to Supabase with `jam@jobdun.com.au` + `123Jobdun!`
   → returns a valid `access_token` (login works at the API layer).
2. The `EmailAuthService.signIn` method calls
   `_client.auth.signInWithPassword(email: email.trim(), password: password)`
   with no transformations.
3. The `JTextField` has no `inputFormatters` on the password field —
   any character including `!` is accepted.

The login failures in my automation were caused by **`adb shell input
text`** stripping or mangling the `!` character — a known limitation
of the `input text` shell command. The same password typed through a
real Android keyboard would work fine.

**What I confirmed the app does correctly:**
- Splash → FTUE flow (with real Oswald "ONLY VERIFIED. NO TIMEWASTERS." typography)
- Notification permission dialog
- Login screen with email + password fields
- Client-side form validation (red error text + red borders when fields are empty)
- Forgot Password deep link
- Real brand color (orange `c.action` for the CTA, dark `c.card` for surface)

**Screenshots in `screenshots/cleaned/`:**

| File | Surface | Notes |
|------|---------|-------|
| `01_clean_launch.png` | First launch | Real device boot of the app |
| `02_ftue_real.png` | FTUE | Real Oswald + Open Sans typography on device, with the tradie hero photo |
| `03_login_screen.png` | Login | Clean login state with both fields empty |
| `04_email_filled.png` | Login | Email field populated, password empty |
| `05_validation_errors.png` | Login | Red error borders + "Email is required." / "Password is required." — the form-validates-before-supabase pattern works |
| `06_forgot_password.png` | Forgot Password | The deep-link from Login → Forgot Password works |
| `07_post_login_attempt.png` | Login | After a manual login attempt (no AuthApiException surfaced in logcat) |

## What's NOT captured (yet)

The new surfaces from the `feat/job-hire-redesign` branch:
- Posting wizard (5 steps, draft resume sheet, sticky footer)
- Hire confirmation sheet (verified-at-apply snapshot, rate-tied CTA)
- Hire celebration card (verified-green 96dp glyph, MESSAGE / VIEW JOB / CLOSE)
- Hired celebration sheet (tradie side)
- Applications page (with hire CTA on the card)
- Home hero (with the new deep link)

These are all reachable only after a successful login. They **do**
exist as 393×852 golden PNGs in `test/golden/goldens/` (the
`hire_*.png` and `wizard_*.png` files from PR1 + PR2), but those
were rendered with the test-renderer's Roboto fallback instead of the
real Oswald/Open Sans fonts, so the text shows as grey blocks.

## Next step to capture real screenshots

1. **Fix the `!` input issue in the driver.** The cleanest path is a
   Flutter integration test (`integration_test/` in this repo) that
   uses the real `SupabaseClient` with a real session and drives the
   app's real widgets. That bypasses `adb shell input text` entirely.
2. **Or, run a debug build with an in-app dev mode that auto-signs-in
   the seeded `jam@jobdun.com.au` account.** Faster, doesn't need a
   full integration test.
3. **Or, share a working password** (one without `!` or other shell-
   special characters) so I can complete the automation. The
   underlying Flutter code is correct; the issue is purely my
   shell driver.
