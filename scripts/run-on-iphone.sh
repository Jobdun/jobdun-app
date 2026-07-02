#!/usr/bin/env bash
#
# run-on-iphone.sh — build Jobdun in release mode and run it on a
# connected physical iPhone. Use this whenever you change code and
# want the new version on your own phone.
#
#   Usage:
#     bash scripts/run-on-iphone.sh
#
#   Requirements (one-time, already done on Ken's Mac):
#     - Xcode + iOS platform installed
#     - Apple Developer account added in Xcode (signing cert minted)
#     - JOBDUN PTY LTD team selected on the Runner target (auto-signing)
#     - iPhone plugged in + trusted + Developer Mode on
#
# Why not just `flutter run`? On iOS 26.5+, Flutter's launch step trails
# the OS and errors with "Could not run … try Xcode" — even though the
# build, signing, and install all succeed. So we build with Flutter and
# install/launch with Apple's own `devicectl`, which handles new iOS fine.
#
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="au.com.jobdun.app"
APP="build/ios/iphoneos/Runner.app"

# --- 1. Auto-detect the connected iPhone (UDID) ---
echo "▶ Looking for a connected iPhone..."
INFO=$(flutter devices --machine 2>/dev/null | python3 -c "
import sys, json
data = sys.stdin.read()
s, e = data.find('['), data.rfind(']')
devs = json.loads(data[s:e+1]) if s >= 0 else []
ios = [d for d in devs
       if str(d.get('targetPlatform', '')).startswith('ios')
       and not d.get('emulator', False)]
if ios:
    print(ios[0]['id'] + '\t' + str(ios[0].get('name', 'iPhone')))
" || true)

UDID="${INFO%%$'\t'*}"
NAME="${INFO#*$'\t'}"

if [[ -z "$UDID" ]]; then
  echo "✗ No physical iPhone detected." >&2
  echo "  Plug it in via USB, tap 'Trust', keep it unlocked, then re-run." >&2
  exit 1
fi
echo "  Found: $NAME ($UDID)"

# --- 2. Build (release) ---
# .env is bundled as a Flutter asset (dotenv.load in main), so no
# --dart-define flags are needed — Supabase/Google/MapTiler load at runtime.
# (First build of a session takes a few minutes; later ones are incremental.)
# If macOS asks to use the "Loki" signing key, click "Always Allow".
echo "▶ Building release..."
flutter build ios --release

[[ -d "$APP" ]] || { echo "✗ Build did not produce $APP" >&2; exit 1; }

# --- 3. Install onto the phone ---
echo "▶ Installing onto $NAME..."
xcrun devicectl device install app --device "$UDID" "$APP" >/dev/null

# --- 4. Launch it (best-effort — a locked phone can't auto-launch) ---
echo "▶ Launching..."
if xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" >/dev/null 2>&1; then
  echo "✅ Jobdun is running on $NAME — check your phone!"
else
  echo "⚠️  Installed OK, but couldn't auto-launch (is $NAME locked?)."
  echo "    Unlock the phone and tap the Jobdun icon to open the new build."
fi
