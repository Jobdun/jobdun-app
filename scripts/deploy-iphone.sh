#!/usr/bin/env bash
#
# deploy-iphone.sh — build the iOS app and put it on the plugged-in iPhone,
# ready to tap. This is the proven path on iOS 26.5: `flutter run --release`
# builds+signs+installs fine but its LAUNCH step fails on-device, so we build
# with Flutter and install/launch through `xcrun devicectl` instead.
#
#   Usage:
#     bash scripts/deploy-iphone.sh            # release build, install over the top (keeps login/data)
#     bash scripts/deploy-iphone.sh --fresh    # uninstall first — wipes app data + login, re-arms the
#                                              #   notification-permission popup (first-run testing)
#     bash scripts/deploy-iphone.sh --profile  # profile build for faster iteration (debug builds
#                                              #   misbehave on this device — deliberately not offered)
#
#   Requirements: iPhone plugged in (or paired over wifi), Developer Mode on,
#   trusted once. Signing is automatic (team 3Q4P2CVMJK, cert "Loki"). All app
#   keys come from the bundled .env asset — no --dart-define needed.
#   Override device auto-detection with JOBDUN_IPHONE_ID=<devicectl identifier>.
#
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="au.com.jobdun.app"
MODE="release"
FRESH=0

for arg in "$@"; do
  case "$arg" in
    --fresh)   FRESH=1 ;;
    --profile) MODE="profile" ;;
    --release) MODE="release" ;;
    *) echo "✗ Unknown flag: $arg (supported: --fresh, --profile)" >&2; exit 1 ;;
  esac
done

[[ -f .env ]] || { echo "✗ Missing .env at repo root — the app's keys live there." >&2; exit 1; }

# --- Find the phone ---
if [[ -n "${JOBDUN_IPHONE_ID:-}" ]]; then
  DEVICE="$JOBDUN_IPHONE_ID"
  echo "▶ Using device from JOBDUN_IPHONE_ID: $DEVICE"
else
  DEVICES_JSON="$(mktemp)"
  trap 'rm -f "$DEVICES_JSON"' EXIT
  xcrun devicectl list devices --json-output "$DEVICES_JSON" >/dev/null
  # identifier \t reachability \t name — reachability: connected | maybe | unreachable
  DEVICE_LINE="$(python3 - "$DEVICES_JSON" <<'PY'
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
def klass(d):
    cp = d.get("connectionProperties", {})
    if cp.get("tunnelState") == "connected":
        return "connected"
    if cp.get("transportType"):          # plugged/on-network but tunnel idle — worth trying
        return "maybe"
    return "unreachable"                  # paired only; no transport right now
def line(d):
    return d["identifier"] + "\t" + klass(d) + "\t" + d.get("deviceProperties", {}).get("name", "unknown")
ranked = sorted(devices, key=lambda d: ["connected", "maybe", "unreachable"].index(klass(d)))
if ranked:
    print(line(ranked[0]))
PY
)"
  [[ -n "$DEVICE_LINE" ]] || { echo "✗ No paired iPhone found — plug it in, unlock it, and trust this Mac." >&2; exit 1; }
  IFS=$'\t' read -r DEVICE REACH DEVNAME <<<"$DEVICE_LINE"
  case "$REACH" in
    connected) echo "▶ Target device: $DEVNAME ($DEVICE)" ;;
    maybe)     echo "▶ Target device: $DEVNAME ($DEVICE) — tunnel idle, will try anyway" ;;
    *) echo "✗ $DEVNAME is paired but NOT reachable right now — plug it in (or put it on this wifi), unlock it, then re-run." >&2
       exit 1 ;;
  esac
fi

# --- Build ---
echo "▶ Building iOS $MODE (signing is automatic)..."
flutter build ios "--$MODE"

APP="build/ios/iphoneos/Runner.app"
[[ -d "$APP" ]] || { echo "✗ Build did not produce $APP" >&2; exit 1; }

# --- Install (optionally fresh) ---
if [[ "$FRESH" == "1" ]]; then
  echo "▶ Uninstalling $BUNDLE_ID (wipes app data — permission popups re-arm)..."
  xcrun devicectl device uninstall app --device "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1 \
    || echo "  (was not installed — continuing)"
fi

echo "▶ Installing $APP..."
xcrun devicectl device install app --device "$DEVICE" "$APP" >/dev/null

# --- Launch (fails politely if the phone is locked) ---
if xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1; then
  echo "✓ Installed and launched — check the phone."
else
  echo "✓ Installed. Couldn't auto-launch (phone likely locked) — unlock it and tap the Jobdun icon."
fi
