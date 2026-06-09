#!/usr/bin/env bash
# deploy-admin.sh — build the Jobdun admin web app and deploy it to Cloudflare Pages.
#
#   First-time setup:
#     1. cp scripts/.cloudflare-env.example scripts/.cloudflare-env
#     2. Paste your Cloudflare API token into scripts/.cloudflare-env
#        (account ID is already filled in). Token needs: Account -> Cloudflare Pages -> Edit.
#
#   Then every deploy is just:  bash scripts/deploy-admin.sh
#
# Uses an API token (env vars), so it never opens a browser — no OAuth/CSRF dance.
set -euo pipefail

ENV_FILE="scripts/.cloudflare-env"
if [[ -f "$ENV_FILE" ]]; then
  set -a; source "$ENV_FILE"; set +a
else
  echo "✗ Missing $ENV_FILE — copy scripts/.cloudflare-env.example to it and paste your API token." >&2
  exit 1
fi

: "${CLOUDFLARE_ACCOUNT_ID:?Set CLOUDFLARE_ACCOUNT_ID in scripts/.cloudflare-env}"
: "${CLOUDFLARE_API_TOKEN:?Set CLOUDFLARE_API_TOKEN in scripts/.cloudflare-env}"
PROJECT="${CLOUDFLARE_PAGES_PROJECT:-jobdun-admin}"

# App keys (Supabase etc.) come from the same .env the normal app build uses —
# single source of truth, so the admin web matches the real app.
[[ -f .env ]] || { echo "✗ Missing .env at repo root — the app's keys live there." >&2; exit 1; }

echo "▶ Building admin web bundle (release)..."
flutter build web --release \
  -t lib/admin/main_admin.dart \
  --dart-define-from-file=.env \
  --base-href=/

echo "▶ Ensuring Pages project '$PROJECT' exists..."
npx wrangler@latest pages project create "$PROJECT" --production-branch main || true

echo "▶ Deploying build/web to Cloudflare Pages project '$PROJECT'..."
npx wrangler@latest pages deploy build/web \
  --project-name="$PROJECT" \
  --branch=main

echo "✅ Done. Admin is live (URL printed above)."
