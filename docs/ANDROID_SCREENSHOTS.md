# Android screenshots — capturing the live app

This is the canonical UI-verification pipeline for the Jobdun repo.
Any change that affects the mobile app's UI (new screens, redesigns,
copy, form fields, navigation, theming, asset swaps) must produce fresh
screenshots before being marked done.

**One command does it all:**

```bash
bash scripts/capture_app_screenshots.sh
```

The script is idempotent and safe to re-run. Outputs land in two
places:

| Destination | Purpose |
|---|---|
| `docs/verification/<date>-emulator-NN-<screen>.png` | Committed to git. The canonical visual record. Reviewers look at these in PRs. |
| `assets/website/screenshots/<key>.png` | Consumed by the marketing site at `jobdun.com.au` — the website displays the same screenshots as product visuals. |

## What the script does

1. **Sanity checks**: `flutter` on PATH, Android SDK present, `adb` reachable.
2. **Builds the debug APK** if `build/app/outputs/flutter-apk/app-debug.apk` is missing (passes the same env vars as `flutter run --dart-define=…`).
3. **Installs the Android emulator + a 64-bit API 34 system image** if missing (`emulator` and `system-images;android-34;google_apis;x86_64`).
4. **Creates the `jobdun_test` AVD** if missing — Pixel profile, 2 GB RAM, headless.
5. **Boots the AVD** in the background (KVM-accelerated on this host) and waits up to 5 min for `sys.boot_completed=1`.
6. **Installs the APK** + pre-grants `POST_NOTIFICATIONS` so the runtime dialog doesn't sit on top of FTUE.
7. **Launches MainActivity** and captures the launch screen.
8. **Drives the flow** with `adb input tap` + `uiautomator dump`:
   - Taps `SKIP` on FTUE page 1.
   - Locates the "Create account" link by accessibility bounds, taps the centre.
9. **Copies the create-account capture** to the website asset path so the marketing site picks it up on the next build.

## What it does NOT do

- **Re-shoot every screen**. The script captures launch + login + create-account. If you change other surfaces (jobs feed, applications, profile, messaging, settings), extend the `shoot()` block in the script with the corresponding `adb input tap` sequence. Each capture is one line.
- **Reset the AVD between runs**. If the app ends up in a weird state from a previous run, do it manually: `adb shell pm clear au.com.jobdun.app` then re-run the script.
- **Re-deploy to Cloudflare**. After the script copies `create-account.png` into `assets/website/screenshots/`, you still need to rebuild the website (`flutter build web …`) and re-deploy (`wrangler pages deploy build/web`).

## When to run it

| Change | Run the script? |
|---|---|
| New screen, redesigned screen, new copy, new form field, new navigation pattern, new asset (SVG / image), new theming colour, new typography scale | **Yes — mandatory** |
| Backend / data layer / Supabase migration / RLS / Edge Function | No — visual unchanged |
| Tooling (CI, build, scripts) | No |
| Documentation | No |
| Marketing site only (`lib/website/`, `web/`) | No — that's `flutter run -d chrome -t lib/website/main_website.dart` territory, with the LAN server for live preview |

The matrix lives in the PR template's checklist. Update it if the rule changes.

## The flow that the script drives today

```
┌─────────────────────────┐
│ MainActivity launches   │
│ → FTUE page 1 (slide 1) │  (3-page swipeable carousel)
│   "Only verified.        │
│    No timewasters."      │
└──────────┬──────────────┘
           │ tap "SKIP" (top-right, ~1000,130)
           ▼
┌─────────────────────────┐
│ Login screen            │
│   email + password       │
│   Apple / Google / Phone │
│   LOG IN                │
│   "Create account" link │
└──────────┬──────────────┘
           │ tap "Create account" (uiautomator-anchored, ~540,1040)
           ▼
┌─────────────────────────┐
│ Create Account screen   │  ← saved to assets/website/screenshots/create-account.png
│   "LOOKING FOR WORK"    │
│   "CREATE ACCOUNT"      │
│   "Let's get you on      │
│    the tools."          │
│   Form fields + CTA     │
└─────────────────────────┘
```

To capture more screens (e.g. jobs feed, applications), find the
matching UI element with `adb shell uiautomator dump /sdcard/ui.xml`
and `cat /sdcard/ui.xml | tr '>' '\n' | grep -i <text>`, capture the
bounds, and add a `tap → sleep → shoot` block to the script. Each
screen is two lines.

## Host requirements

- **Flutter SDK** (3.41.7+; matches `.github/workflows/ci.yml`).
- **Android SDK** at `$ANDROID_HOME` (defaults to `$HOME/android-sdk`).
  The script installs the emulator and a system image if missing.
- **KVM acceleration** — the user account must be in the `kvm` group.
  Without KVM, the emulator falls back to TCG (CPU-only) and the boot
  takes 5–10 min instead of 30s.
- **Disk**: ~2 GB for the system image + 1 GB for the AVD.
- **RAM**: 4 GB available (the AVD is configured for 2 GB).

## Customising

```bash
# Different AVD name
AVD_NAME=my_other_avd bash scripts/capture_app_screenshots.sh

# Use a pre-built APK (skip the build step)
APK_PATH=/path/to/app-debug.apk bash scripts/capture_app_screenshots.sh
```

## Why this is its own script and not a `flutter test` integration test

Integration tests (`integration_test/`) work, but they:
- Need a separate test entrypoint and re-build of the app
- Don't capture real device pixels — they capture the Flutter view tree
- Don't help with the marketing site, which needs raw PNGs

The screenshot pipeline is for **visual verification by humans**, not
automated testing. PRs are reviewed against the new screenshots by
a human reviewer; CI does not run this script (it'd be slow and
require an emulator in CI, which is a separate decision).

## Related docs

- `docs/DEPLOYMENT.md` — Cloudflare Pages deploy workflow.
- `docs/ARCHITECTURE.md` — current state of the repo, branch info.
- `AGENTS.md` and `CLAUDE.md` — the "always screenshot the app" rule
  that this runbook implements.
