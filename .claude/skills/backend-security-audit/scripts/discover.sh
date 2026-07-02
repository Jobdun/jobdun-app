#!/usr/bin/env bash
# discover.sh — enumerate the CURRENT Supabase backend from schema.sql (drift-proof; no hardcoded names).
# Usage: bash discover.sh [--tables --rls --policies --definers --fks --buckets]   (default: all)
#        SCHEMA=path/to/schema.sql bash discover.sh    (override source)
# Feeds the Assess step of the backend-security-audit skill.
set -uo pipefail

SCHEMA="${SCHEMA:-supabase/schema.sql}"
if [ ! -f "$SCHEMA" ]; then
  echo "ERR: $SCHEMA not found. Regenerate with: supabase db dump -f supabase/schema.sql" >&2
  exit 2
fi

ARGS="$*"; [ -z "$ARGS" ] && ARGS="--tables --rls --policies --definers --fks --buckets"
has()     { printf '%s' "$ARGS" | grep -q -- "$1"; }
section() { printf '\n== %s ==\n' "$1"; }

if has '--tables'; then
  section "TABLES"
  grep -oE 'CREATE TABLE (IF NOT EXISTS )?[^( ]+' "$SCHEMA" \
    | sed -E 's/CREATE TABLE (IF NOT EXISTS )?//' | tr -d '"' | sort -u
fi

if has '--rls'; then
  section "RLS ENABLED"
  grep -oE 'ALTER TABLE [^ ]+ ENABLE ROW LEVEL SECURITY' "$SCHEMA" | awk '{print $3}' | tr -d '"' | sort -u
  section "RLS FORCED"
  grep -oE 'ALTER TABLE [^ ]+ FORCE ROW LEVEL SECURITY' "$SCHEMA" | awk '{print $3}' | tr -d '"' | sort -u
  echo "  (tables in TABLES but not in RLS ENABLED = RLS MISSING → API1 BLOCKER candidate)"
fi

if has '--policies'; then
  section "POLICIES (grep CREATE POLICY — inspect USING / WITH CHECK by hand)"
  grep -nE 'CREATE POLICY' "$SCHEMA"
fi

if has '--definers'; then
  section "SECURITY DEFINER FUNCTIONS"
  grep -nE 'SECURITY DEFINER' "$SCHEMA"
  section "DEFINER WITHOUT NEARBY 'search_path' (SUSPECT — API5 escalation risk)"
  grep -nE 'SECURITY DEFINER' "$SCHEMA" | cut -d: -f1 | while read -r ln; do
    lo=$(( ln > 25 ? ln - 25 : 1 ))
    if ! sed -n "${lo},$((ln + 25))p" "$SCHEMA" | grep -q 'search_path'; then
      echo "  SUSPECT: SECURITY DEFINER @ line $ln — no 'search_path' within ±25 lines"
    fi
  done
fi

if has '--fks'; then
  section "FOREIGN KEYS (each SHOULD have a covering index — else API1/scalability)"
  grep -nE 'REFERENCES ' "$SCHEMA"
  section "INDEXES"
  grep -nE 'CREATE (UNIQUE )?INDEX' "$SCHEMA"
fi

if has '--buckets'; then
  section "STORAGE BUCKETS (verification-documents + job-attachments MUST be private)"
  grep -nE 'storage\.buckets' "$SCHEMA" || echo "  (none in schema.sql — also grep supabase/migrations for storage.buckets)"
fi

printf '\n-- discover.sh done. Cross-check TABLES vs RLS ENABLED for gaps. --\n'
