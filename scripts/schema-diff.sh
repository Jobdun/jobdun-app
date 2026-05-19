#!/usr/bin/env bash
# Fails if the live migration set no longer matches supabase/schema.sql.
# Catches schema<->Dart drift regressions (root cause of Sprint 1).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
supabase db reset >/dev/null
supabase db dump --local --schema public -f "$TMP" >/dev/null
if ! diff -u supabase/schema.sql "$TMP"; then
  echo "ERROR: schema drift — migrations no longer match supabase/schema.sql." >&2
  echo "If intentional: supabase db dump --local --schema public -f supabase/schema.sql" >&2
  exit 1
fi
echo "schema-diff: OK (migrations match committed schema.sql)"
