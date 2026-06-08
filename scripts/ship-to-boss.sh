#!/usr/bin/env bash
#
# ship-to-boss.sh — build a release APK and send it to testers via
# Firebase App Distribution. Run this whenever you want your boss to
# get a fresh build. He installs once, then gets a notification each
# time you ship.
#
#   Usage:
#     bash scripts/ship-to-boss.sh "Fixed the login screen + new job filters"
#
#   First-time setup: copy scripts/.ship-env.example -> scripts/.ship-env
#   and fill in the values (that file is gitignored — never committed).
#
set -euo pipefail

cd "$(dirname "$0")/.."

# --- Load local config (untracked secrets) ---
ENV_FILE="scripts/.ship-env"
if [[ -f "$ENV_FILE" ]]; then
  set -a; source "$ENV_FILE"; set +a
else
  echo "✗ Missing $ENV_FILE — copy scripts/.ship-env.example to it and fill it in." >&2
  exit 1
fi

: "${FIREBASE_APP_ID:?Set FIREBASE_APP_ID in scripts/.ship-env}"
TESTER_GROUP="${TESTER_GROUP:-boss}"
RELEASE_NOTES="${1:-New test build}"

# All app keys (Supabase, MapTiler, Sentry, Google sign-in...) come from .env —
# the same file `flutter run --dart-define-from-file=.env` uses. Single source
# of truth, so the test build matches the real app and no secrets get duplicated.
[[ -f .env ]] || { echo "✗ Missing .env at repo root — the app's keys live there." >&2; exit 1; }

echo "▶ Building release APK (this takes a couple of minutes)..."
flutter build apk --release --dart-define-from-file=.env

APK="build/app/outputs/flutter-apk/app-release.apk"
[[ -f "$APK" ]] || { echo "✗ Build did not produce $APK" >&2; exit 1; }

echo "▶ Uploading to Firebase App Distribution → group '$TESTER_GROUP'..."
firebase appdistribution:distribute "$APK" \
  --app "$FIREBASE_APP_ID" \
  --groups "$TESTER_GROUP" \
  --release-notes "$RELEASE_NOTES"

echo "✅ Done. '$TESTER_GROUP' will get a notification for this build."
