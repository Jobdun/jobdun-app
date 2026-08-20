#!/usr/bin/env bash
# verify-web-deploy.sh — assert the things the 2026-08-19 parity audit fixed are
# actually true of a served build. Run against localhost before deploying and
# against the live host after.
#
#   bash scripts/verify-web-deploy.sh                          # live
#   bash scripts/verify-web-deploy.sh http://127.0.0.1:8777    # local build
#
# Note: a plain `python3 -m http.server` does not apply vercel.json, so the
# header assertions are expected to FAIL locally. They only carry meaning
# against a Vercel deployment (preview or production).
set -uo pipefail

BASE="${1:-https://app.jobdun.com.au}"
FAIL=0

pass() { printf '  \033[0;32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[0;31mFAIL\033[0m  %s\n' "$1"; FAIL=1; }

echo "=== Verifying $BASE ==="

HDRS="$(curl -sS -D - -o /dev/null --max-time 30 "$BASE/")"
BODY="$(curl -sS --max-time 30 "$BASE/")"
VERSION="$(curl -sS --max-time 30 "$BASE/version.json")"

# 1. The release actually shipped.
echo "$VERSION" | grep -q '"build_number":"7"' \
  && pass "version.json is build 7  ($VERSION)" \
  || fail "version.json is NOT build 7 — got: $VERSION"

# 2. Camera + geolocation are usable. Empty () blocks every origin including
#    self, which is what shipped and what broke uploads and 'jobs near me'.
POLICY="$(echo "$HDRS" | tr -d '\r' | grep -i '^permissions-policy:' || true)"
echo "$POLICY" | grep -q 'camera=(self)' \
  && pass "camera allowed for self" \
  || fail "camera NOT allowed — ${POLICY:-<no permissions-policy header>}"
echo "$POLICY" | grep -q 'geolocation=(self)' \
  && pass "geolocation allowed for self" \
  || fail "geolocation NOT allowed — ${POLICY:-<no permissions-policy header>}"

# 3. Security headers still present (they were, before — don't regress them).
for h in "x-frame-options: deny" "x-content-type-options: nosniff" \
         "strict-transport-security" "referrer-policy" "x-robots-tag"; do
  echo "$HDRS" | tr -d '\r' | tr 'A-Z' 'a-z' | grep -q "$h" \
    && pass "header present: $h" \
    || fail "header MISSING: $h"
done

# 4. The shell is the app's, not the marketing site's.
echo "$BODY" | grep -q 'og:url" content="https://app.jobdun.com.au"' \
  && pass "og:url points at the app" \
  || fail "og:url does not point at the app"
echo "$BODY" | grep -q 'main_website.dart' \
  && fail "shell still claims it is built from lib/website/main_website.dart" \
  || pass "shell does not reference the marketing entrypoint"

# 5. The entry document must never be cached hard, or a release ships to nobody.
echo "$HDRS" | tr -d '\r' | tr 'A-Z' 'a-z' | grep -qE 'cache-control:.*(no-cache|max-age=0)' \
  && pass "entry document is revalidated" \
  || fail "entry document is cached — $(echo "$HDRS" | tr -d '\r' | grep -i '^cache-control:')"

echo
[[ "$FAIL" -eq 0 ]] && echo "✅ All web checks passed for $BASE" \
                    || { echo "❌ Web checks FAILED for $BASE"; exit 1; }
