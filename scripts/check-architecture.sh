#!/usr/bin/env bash
# scripts/check-architecture.sh
#
# Verifies Clean Architecture compliance per:
#   • CLAUDE.md → "Engineering Standards (STRICT)" → Layer rules
#   • docs/CLEAN_ARCHITECTURE_AUDIT.md
#
# Checks:
#   1. Domain purity         — domain/** must not import flutter/supabase/riverpod/core_config
#   2. Layer boundary        — pages/widgets must not import data/datasources or data/repositories
#                              (only presentation/providers/* may — that's the seam)
#   3. Supabase isolation    — SupabaseConfig.client / Supabase.instance may only appear in
#                              data/datasources, data/services, presentation/providers
#   4. Use case coverage     — every domain/usecases/*.dart must have ≥1 caller in lib/
#   5. Repo contract/impl    — domain/repositories ⇔ data/repositories (1:1)
#   6. Empty layer dirs      — orphan dirs under features/*/ are deleted
#   7. currentUserId reads   — feature code reads ref.read(currentUserIdSyncProvider),
#                              never SupabaseConfig.client.auth.currentUser?.id directly
#
# Usage:
#   bash scripts/check-architecture.sh             # full report
#   bash scripts/check-architecture.sh --quiet     # only summary
#
# Exits 0 if everything passes, 1 if any violation is found.

set -uo pipefail

# ── Colour helpers ─────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; RESET='\033[0m'

QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

# ── Result tracking ────────────────────────────────────────────────────────────
declare -a RESULTS=()
FAILED=0

_pass() { echo -e "  ${GREEN}PASS${RESET}"; RESULTS+=("${GREEN}PASS${RESET}  $1"); }
_fail() { echo -e "  ${RED}FAIL${RESET}"; RESULTS+=("${RED}FAIL${RESET}  $1"); FAILED=1; }
_warn() { echo -e "  ${YELLOW}WARN${RESET}"; RESULTS+=("${YELLOW}WARN${RESET}  $1"); }

# Show the lines that caused a failure; in --quiet mode just count them.
_report_hits() {
  local hits="$1"
  if [[ -z "$hits" ]]; then return; fi
  if [[ "$QUIET" -eq 1 ]]; then
    local n
    n=$(echo "$hits" | wc -l | tr -d ' ')
    echo "    ($n offending line(s))" | sed 's/^/    /'
  else
    echo "$hits" | sed 's/^/    /'
  fi
}

# Passes if the supplied `hits` string is empty.
grep_check() {
  local label="$1"; local hits="$2"
  printf "  %-58s" "$label"
  if [[ -z "$hits" ]]; then
    _pass "$label"
  else
    _fail "$label"
    _report_hits "$hits"
  fi
}

echo -e "\n${BOLD}=== Jobdun check-architecture.sh ===${RESET}\n"

# ── 1. Domain layer purity ────────────────────────────────────────────────────
echo -e "${BOLD}[1/7] Domain layer purity${RESET}"
grep_check "domain/** has no flutter/supabase/riverpod imports" \
  "$(grep -rnE "import.*package:(flutter|supabase_flutter|flutter_riverpod)/|import.*core/config" \
       lib/features/*/domain 2>/dev/null || true)"
echo ""

# ── 2. Presentation → Data boundary ───────────────────────────────────────────
# Pages and widgets must never import data/datasources or data/repositories.
# Provider files (the wiring seam) are explicitly allowed.
echo -e "${BOLD}[2/7] Presentation → Data boundary${RESET}"
grep_check "pages/widgets do not import data/ directly" \
  "$(grep -rn -E "import.*data/(datasources|repositories)" lib/features/*/presentation 2>/dev/null \
     | grep -v "/presentation/providers/" || true)"
echo ""

# ── 3. Supabase isolation ─────────────────────────────────────────────────────
# Allowed locations for direct SupabaseConfig.client / Supabase.instance reads:
#   • lib/features/*/data/datasources/*
#   • lib/features/*/data/services/*    (auth exception — see CLAUDE.md)
#   • lib/features/*/presentation/providers/*  (DI wiring seam)
#   • lib/features/legal/data/*         (legal acceptance repo — direct client OK)
#
# Anything else is a layer violation — feature code should read via
# currentUserIdSyncProvider or its own controller / repo.
#
# ARCH_SUPABASE_ALLOWLIST: documented scoped exceptions. Each entry must be
# justified in docs/CLEAN_ARCHITECTURE_AUDIT.md → "Remaining minor items".
# Adding here without documenting = drift; revisit on next architecture pass.
ARCH_SUPABASE_ALLOWLIST=(
  # profile_edit_page reads auth.currentUser.userMetadata['full_name'] for the
  # register-time form prefill — a different concern from the userId pattern.
  # Slated for the next register-draft refactor.
  "lib/features/profile/presentation/pages/profile_edit_page.dart"
)
echo -e "${BOLD}[3/7] Supabase isolation${RESET}"
raw_supabase=$(
  grep -rn -E "SupabaseConfig\.client|Supabase\.instance" lib/features 2>/dev/null \
  | grep -vE "/(data/(datasources|services|legal_acceptance)|presentation/providers)/" \
  || true
)
# Strip allowlisted file paths.
supabase_violations="$raw_supabase"
for allow in "${ARCH_SUPABASE_ALLOWLIST[@]}"; do
  supabase_violations=$(echo "$supabase_violations" | grep -v "^${allow}:" || true)
done
grep_check "no SupabaseConfig.client outside data/ + providers/" "$supabase_violations"
echo ""

# ── 4. Use case coverage ──────────────────────────────────────────────────────
# Every class declared in lib/features/*/domain/usecases/*.dart must have at
# least one caller in lib/ (outside its own file).
# Auth is the documented exception — uses data/services/* instead, so no
# use-case files are expected under features/auth/domain/usecases/.
echo -e "${BOLD}[4/7] Use case coverage${RESET}"
dead_usecases=""
for uc in $(find lib/features -path "*/domain/usecases/*.dart" 2>/dev/null); do
  class=$(grep -oE "^class [A-Z][A-Za-z0-9_]+" "$uc" | head -1 | sed 's/class //')
  [[ -z "$class" ]] && continue
  callers=$(grep -rln "\\b${class}\\b" lib 2>/dev/null | grep -v "^${uc}$" | wc -l | tr -d ' ')
  if [[ "$callers" -eq 0 ]]; then
    dead_usecases+="${uc#./} (${class})"$'\n'
  fi
done
printf "  %-58s" "every use case has ≥1 caller in lib/"
if [[ -z "$dead_usecases" ]]; then
  _pass "every use case has ≥1 caller in lib/"
else
  _fail "every use case has ≥1 caller in lib/"
  echo "$dead_usecases" | sed 's/^/    DEAD: /'
fi
echo ""

# ── 5. Repository contract / impl pairing ─────────────────────────────────────
# Each feature with a domain/repositories/ folder must have a matching
# data/repositories/ folder with the same file count. Skips auth (services-only).
echo -e "${BOLD}[5/7] Repository contract / impl pairing${RESET}"
mismatch=""
for repo_dir in $(find lib/features -path "*/domain/repositories" -type d 2>/dev/null); do
  feature=$(echo "$repo_dir" | sed 's|.*/features/||' | sed 's|/domain/repositories||')
  contracts=$(find "$repo_dir" -maxdepth 1 -name "*.dart" 2>/dev/null | wc -l | tr -d ' ')
  impl_dir="lib/features/$feature/data/repositories"
  impls=$(find "$impl_dir" -maxdepth 1 -name "*.dart" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$contracts" -ne "$impls" ]]; then
    mismatch+="${feature}: contracts=${contracts}, impls=${impls}"$'\n'
  fi
done
printf "  %-58s" "domain/repositories ⇔ data/repositories (1:1)"
if [[ -z "$mismatch" ]]; then
  _pass "domain/repositories ⇔ data/repositories (1:1)"
else
  _fail "domain/repositories ⇔ data/repositories (1:1)"
  echo "$mismatch" | sed 's/^/    /'
fi
echo ""

# ── 6. Empty layer directories ────────────────────────────────────────────────
# Orphan empty dirs under features/*/ indicate a deletion that didn't clean up.
echo -e "${BOLD}[6/7] No empty layer directories${RESET}"
empty_dirs=$(find lib/features -type d -empty 2>/dev/null || true)
grep_check "no empty dirs under lib/features/" "$empty_dirs"
echo ""

# ── 7. currentUserId reads ────────────────────────────────────────────────────
# Feature code reading currentUser?.id directly is a layer violation — should
# go through currentUserIdSyncProvider so tests can override.
echo -e "${BOLD}[7/7] currentUserId reads use the provider${RESET}"
current_user_violations=$(
  grep -rn "SupabaseConfig\.client\.auth\.currentUser\|Supabase\.instance\.client\.auth\.currentUser" \
       lib/features 2>/dev/null \
  | grep -vE "/(data/(datasources|services)|presentation/providers)/" \
  || true
)
# profile_edit_page.dart's userMetadata['full_name'] read is the documented
# scoped exception — it's not the userId pattern, it's form prefill.
current_user_violations=$(echo "$current_user_violations" \
  | grep -v "userMetadata" || true)
grep_check "currentUser?.id reads go through currentUserIdSyncProvider" \
  "$current_user_violations"
echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
echo -e "${BOLD}=== Summary ===${RESET}"
for line in "${RESULTS[@]}"; do
  echo -e "  $line"
done
echo ""

if [[ "$FAILED" -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}Clean Architecture: all checks passed.${RESET}"
  echo -e "${CYAN}Reference: docs/CLEAN_ARCHITECTURE_AUDIT.md${RESET}"
  exit 0
else
  echo -e "${RED}${BOLD}Clean Architecture: violations found. Fix above before merging.${RESET}"
  echo -e "${CYAN}Reference: docs/CLEAN_ARCHITECTURE_AUDIT.md → \"What was fixed in this pass\"${RESET}"
  exit 1
fi
