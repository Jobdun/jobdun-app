#!/usr/bin/env bash
# Capture screenshots of the live Jobdun app in the Android emulator.
#
# This is the canonical UI-verification pipeline for the repo. Run it
# any time the app's UI changes. It produces two outputs:
#
#   docs/verification/<date>-emulator-NN-<screen>.png   (committed; the
#                                                     canonical visual record)
#   assets/website/screenshots/<key>.png               (consumed by the
#                                                     marketing site at
#                                                     jobdun.com.au)
#
# Requirements on the host:
#   - Flutter SDK on PATH
#   - Android SDK at $ANDROID_HOME or $HOME/android-sdk
#   - User in the kvm group (KVM hardware acceleration)
#   - A connected physical Android device, OR
#     the `jobdun_test` AVD (the script creates it if missing)
#
# The script is idempotent: it reuses an already-running emulator,
# re-installs the APK over the top of the previous one, and overwrites
# previous PNGs. Safe to re-run any time.
#
# Quick run:
#   bash scripts/capture_app_screenshots.sh
#
# Custom AVD name or APK path:
#   AVD_NAME=my_avd APK_PATH=/path/to/app-debug.apk bash scripts/capture_app_screenshots.sh

set -euo pipefail

# --- Config ----------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

AVD_NAME="${AVD_NAME:-jobdun_test}"
APK_PATH="${APK_PATH:-$REPO_ROOT/build/app/outputs/flutter-apk/app-debug.apk}"
SCREENSHOT_DIR="$REPO_ROOT/docs/verification"
WEBSITE_SCREENSHOT_DIR="$REPO_ROOT/assets/website/screenshots"
PACKAGE_ID="au.com.jobdun.app"
MAIN_ACTIVITY="au.com.jobdun.app/.MainActivity"

ANDROID_SDK="${ANDROID_SDK:-$HOME/android-sdk}"
if [ -z "${ANDROID_HOME:-}" ]; then
  export ANDROID_HOME="$ANDROID_SDK"
fi
if [ -z "${ANDROID_SDK_ROOT:-}" ]; then
  export ANDROID_SDK_ROOT="$ANDROID_SDK"
fi
export ANDROID_AVD_HOME="${ANDROID_AVD_HOME:-$HOME/.android/avd}"
export PATH="$ANDROID_SDK/platform-tools:$ANDROID_SDK/cmdline-tools/latest/bin:$ANDROID_SDK/emulator:$PATH"

DATE_TAG="$(date +%Y-%m-%d)"
mkdir -p "$SCREENSHOT_DIR" "$WEBSITE_SCREENSHOT_DIR"

# --- Step 0: sanity checks --------------------------------------------------

if ! command -v flutter >/dev/null 2>&1; then
  echo "::error::flutter not on PATH" >&2
  exit 1
fi
if [ ! -d "$ANDROID_SDK" ]; then
  echo "::error::Android SDK not found at $ANDROID_SDK (set ANDROID_SDK)" >&2
  exit 1
fi
if ! command -v adb >/dev/null 2>&1; then
  echo "::error::adb not on PATH (expected at $ANDROID_SDK/platform-tools/adb)" >&2
  exit 1
fi

# --- Step 1: ensure debug APK exists ----------------------------------------

if [ ! -f "$APK_PATH" ]; then
  echo "::info::APK not found at $APK_PATH; building debug APK"
  flutter build apk --debug \
    --dart-define=SUPABASE_URL=https://zethpanvkfyijislxesn.supabase.co/ \
    --dart-define=SUPABASE_ANON_KEY="$(grep SUPABASE_ANON_KEY .env | cut -d= -f2-)" \
    --dart-define=GOOGLE_WEB_CLIENT_ID="$(grep GOOGLE_WEB_CLIENT_ID .env | cut -d= -f2-)" \
    --dart-define=GOOGLE_IOS_CLIENT_ID="$(grep GOOGLE_IOS_CLIENT_ID .env | cut -d= -f2-)" \
    --dart-define=MAPTILER_API_KEY="$(grep MAPTILER_API_KEY .env | cut -d= -f2-)"
fi

# --- Step 2: ensure emulator + system image installed ------------------------

if ! command -v emulator >/dev/null 2>&1; then
  echo "::info::Installing Android emulator via sdkmanager"
  yes | sdkmanager --licenses >/dev/null 2>&1 || true
  sdkmanager "emulator" "system-images;android-34;google_apis;x86_64" >/dev/null
fi

# --- Step 3: ensure AVD exists ----------------------------------------------

if [ ! -d "$ANDROID_AVD_HOME/${AVD_NAME}.avd" ]; then
  echo "::info::Creating AVD $AVD_NAME"
  echo "no" | avdmanager create avd \
    -n "$AVD_NAME" \
    -k "system-images;android-34;google_apis;x86_64" \
    --device "pixel" \
    --force >/dev/null
fi

# --- Step 4: ensure adb server is up ----------------------------------------

adb start-server >/dev/null 2>&1 || true

# --- Step 5: start emulator if not already running ---------------------------

if ! adb devices | grep -q "emulator-"; then
  echo "::info::Booting emulator $AVD_NAME (headless)"
  setsid emulator -avd "$AVD_NAME" \
    -no-window -no-audio -no-boot-anim -no-snapshot \
    -gpu swiftshader_indirect -accel auto \
    -netdelay none -netspeed full -no-metrics \
    -memory 2048 \
    > /tmp/jobdun-emu.log 2>&1 < /dev/null &
  disown || true
else
  echo "::info::Reusing running emulator"
fi

# Wait for boot_completed.
echo "::info::Waiting for emulator to boot"
for i in $(seq 1 60); do
  BOOT="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
  if [ "$BOOT" = "1" ]; then
    echo "::info::Booted after ${i}x5s"
    break
  fi
  sleep 5
done
if [ "$BOOT" != "1" ]; then
  echo "::error::Emulator failed to boot in 5 minutes" >&2
  exit 1
fi

# --- Step 6: install + launch the app ---------------------------------------

echo "::info::Installing $APK_PATH"
adb install -r "$APK_PATH" >/dev/null

# Pre-grant runtime permissions so dialogs don't sit on top of FTUE.
adb shell "pm grant $PACKAGE_ID android.permission.POST_NOTIFICATIONS" 2>/dev/null || true

# Capture #1: app launched to whatever surface is current.
shoot() {
  local name="$1"
  local path="$SCREENSHOT_DIR/${DATE_TAG}-emulator-${name}.png"
  adb exec-out screencap -p > "$path"
  echo "::info::$path"
}

echo "::info::Launching $MAIN_ACTIVITY"
adb shell "am start -n $MAIN_ACTIVITY" >/dev/null
sleep 20
shoot 01-launch

# Skip FTUE and capture the login screen.
# SKIP button on FTUE page 1 sits at top-right, ~y=130 on a 1080x1920 device.
adb shell "input tap 1000 130" >/dev/null
sleep 4
shoot 02-login

# Tap "Create account" — coords from uiautomator dump.
adb shell "uiautomator dump /sdcard/ui.xml" >/dev/null
CREATE_ACCOUNT_BOUNDS="$(adb shell cat /sdcard/ui.xml | tr '>' '\n' | grep -i "Create account" | grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | head -1 | grep -oE '[0-9]+' | tr '\n' ' ')"
if [ -n "$CREATE_ACCOUNT_BOUNDS" ]; then
  set -- $CREATE_ACCOUNT_BOUNDS
  CX=$(( ($1 + $3) / 2 ))
  CY=$(( ($2 + $4) / 2 ))
  echo "::info::Tapping Create account at $CX,$CY"
  adb shell "input tap $CX $CY" >/dev/null
  sleep 4
  shoot 03-create-account
fi

# --- Step 7: copy to website asset dir --------------------------------------

# Keep the website asset filenames stable: only overwrite if a name is
# explicitly mapped. The marketing site references these by name.
declare -A WEBSITE_MAP=(
  ["$DATE_TAG-emulator-03-create-account.png"]="create-account.png"
)
for src in "${!WEBSITE_MAP[@]}"; do
  if [ -f "$SCREENSHOT_DIR/$src" ]; then
    cp "$SCREENSHOT_DIR/$src" "$WEBSITE_SCREENSHOT_DIR/${WEBSITE_MAP[$src]}"
    echo "::info::website asset: $WEBSITE_SCREENSHOT_DIR/${WEBSITE_MAP[$src]}"
  fi
done

echo "::info::Done. Captured: $(ls -1 "$SCREENSHOT_DIR" | wc -l) files in $SCREENSHOT_DIR"
