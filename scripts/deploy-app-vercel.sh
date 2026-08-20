#!/usr/bin/env bash
# deploy-app-vercel.sh — build the Jobdun consumer app (Flutter Web) and deploy
# it to Vercel as a static site, served at app.jobdun.com.au.
#
#   Usage:
#     bash scripts/deploy-app-vercel.sh              # build + deploy to production
#     bash scripts/deploy-app-vercel.sh --preview    # build + deploy a preview URL
#     bash scripts/deploy-app-vercel.sh --build-only # build, don't deploy
#
#   First-time setup on a fresh machine:
#     1. npm i -g vercel
#     2. vercel login          (account: loki123)
#     3. DNS at GoDaddy:  A  app  ->  76.76.21.21
#
#   Verify a deploy with: bash scripts/verify-web-deploy.sh [url]
#
#   History (2026-08-19 parity audit): this script used to live untracked in
#   .claude/worktrees/feature+web-app-flutter/ and could not run on any current
#   branch — it built `-t lib/main_web.dart`, an entrypoint folded back into
#   lib/main.dart, and it staged a separate `web-app/` template over `web/`,
#   which silently discarded anything edited in web/. Both are gone: the
#   consumer app is the only web target this repo still builds (marketing and
#   admin moved to their own Next.js repos), so web/ is the one shell.
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="${VERCEL_PROJECT:-jobdun-app}"
TARGET="--prod"
DEPLOY=1

case "${1:-}" in
  --preview)    TARGET="" ;;
  --build-only) DEPLOY=0 ;;
  "")           ;;
  *) echo "✗ Unknown flag: ${1} (supported: --preview, --build-only)" >&2; exit 1 ;;
esac

[[ -f .env ]] || { echo "✗ Missing .env at repo root — the app's keys live there." >&2; exit 1; }

echo "▶ Building app web bundle (release)..."
flutter build web --release \
  -t lib/main.dart \
  --dart-define-from-file=.env \
  --base-href=/

# vercel.json rides along from web/ into build/web — Flutter copies the whole
# web/ directory. Without it the deploy silently loses every header, including
# the Permissions-Policy that lets the camera and geolocation work at all.
[[ -f build/web/vercel.json ]] || {
  echo "✗ build/web/vercel.json missing — web/vercel.json did not get copied." >&2
  exit 1
}

if [[ "$DEPLOY" -eq 0 ]]; then
  echo "✅ Build only. Output: build/web (version: $(cat build/web/version.json))"
  exit 0
fi

command -v vercel >/dev/null || { echo "✗ vercel CLI not found — npm i -g vercel" >&2; exit 1; }

echo "▶ Linking Vercel project '$PROJECT'..."
# Idempotent: flutter build wipes build/web, taking .vercel/project.json with it.
(cd build/web && vercel link --yes --project "$PROJECT" >/dev/null)

echo "▶ Deploying build/web to Vercel..."
(cd build/web && vercel deploy $TARGET --yes)

echo "✅ Done. Verify with: bash scripts/verify-web-deploy.sh"
