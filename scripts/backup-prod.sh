#!/bin/bash
# Nightly logical backup of the Jobdun PRODUCTION Supabase project.
#
# Free-plan projects have no automatic backups — this is the safety net.
# Exports every table (public schema discovered dynamically, plus auth.users,
# auth.identities, storage.buckets, storage.objects) as JSON via the Management
# API, then downloads every storage file. auth.users includes password hashes,
# so a backup is enough to fully restore accounts.
#
# Runs standalone (launchd/cron) — credentials come from the macOS keychain
# item "Supabase CLI" (same token the CLI uses). Output:
#   ~/Documents/Jobdun-backups/auto/<YYYY-MM-DD>/
# Backups older than $KEEP_DAYS days are pruned.
set -euo pipefail

REF="zethpanvkfyijislxesn"
KEEP_DAYS=14
ROOT="$HOME/Documents/Jobdun-backups/auto"
DAY=$(date +%Y-%m-%d)
BK="$ROOT/$DAY"
mkdir -p "$BK/storage"

TOKEN=$(security find-generic-password -s "Supabase CLI" -w | sed 's/^go-keyring-base64://' | base64 -d)

q() {
  jq -n --arg q "$1" '{query:$q}' | curl -sS --fail-with-body -X POST \
    "https://api.supabase.com/v1/projects/${REF}/database/query" \
    -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -d @-
}

# Discover all public tables dynamically so new tables are auto-included
PUBLIC_TABLES=$(q "SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='r' ORDER BY 1" | jq -r '.[].relname')
TABLES=(auth.users auth.identities storage.buckets storage.objects)
while IFS= read -r T; do TABLES+=("public.$T"); done <<< "$PUBLIC_TABLES"

TOTAL=0
for T in "${TABLES[@]}"; do
  F="$BK/${T//./_}.json"
  q "SELECT * FROM $T" > "$F"
  N=$(jq 'if type=="array" then length else -1 end' "$F")
  if [ "$N" -lt 0 ]; then echo "ERROR exporting $T"; cat "$F"; exit 1; fi
  TOTAL=$((TOTAL + N))
  echo "$T -> $N rows"
done

# Storage files
SR=$(curl -sS "https://api.supabase.com/v1/projects/${REF}/api-keys?reveal=true" \
  -H "Authorization: Bearer ${TOKEN}" | jq -r '.[] | select(.name=="service_role") | .api_key')
jq -r '.[] | "\(.bucket_id)/\(.name)"' "$BK/storage_objects.json" | while IFS= read -r P; do
  mkdir -p "$BK/storage/$(dirname "$P")"
  CODE=$(curl -sS -w "%{http_code}" -o "$BK/storage/$P" \
    "https://${REF}.supabase.co/storage/v1/object/$P" -H "Authorization: Bearer ${SR}")
  [ "$CODE" = "200" ] || echo "WARN storage $CODE $P"
done

# Prune old backups
find "$ROOT" -maxdepth 1 -type d -name '20*' -mtime +"$KEEP_DAYS" -exec rm -rf {} +

echo "OK $DAY: $TOTAL rows, $(du -sh "$BK" | cut -f1) -> $BK"
