#!/usr/bin/env bash
# Fails if the live remote schema no longer matches supabase/schema.sql.
# Catches schema<->Dart drift regressions (root cause of Sprint 1).
#
# Uses `--linked` against the project configured in supabase/config.toml,
# so it works without Docker / local Supabase. Requires SUPABASE_ACCESS_TOKEN
# (and SUPABASE_DB_PASSWORD if running non-interactively).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
supabase db dump --linked --schema public -f "$TMP" >/dev/null
if ! diff -u supabase/schema.sql "$TMP"; then
  echo "ERROR: schema drift — remote schema no longer matches supabase/schema.sql." >&2
  echo "Fix with: bash scripts/sync-schema.sh" >&2
  exit 1
fi
echo "schema-diff: OK (remote schema matches committed schema.sql)"
