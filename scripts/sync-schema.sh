#!/usr/bin/env bash
# scripts/sync-schema.sh
# Resyncs supabase/schema.sql from the linked remote project. Run this
# whenever scripts/schema-diff.sh (in CI) reports drift — typically after
# a new migration has been pushed and committed.
#
# Requires the supabase CLI to be authenticated against the linked project
# (i.e. `supabase login` has been run on this machine).

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

echo "Dumping linked-remote public schema → supabase/schema.sql ..."
supabase db dump --linked --schema public -f supabase/schema.sql

if git diff --quiet supabase/schema.sql; then
  echo "schema.sql already matches the remote. Nothing to do."
  exit 0
fi

echo
echo "schema.sql updated. Review the diff, then:"
echo "  git add supabase/schema.sql"
echo "  git commit -m 'chore(schema): sync supabase/schema.sql from remote'"
