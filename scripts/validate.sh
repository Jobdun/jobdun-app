#!/usr/bin/env bash
# scripts/validate.sh
# Single source of truth for all local and CI quality checks.
#
# Usage:
#   bash scripts/validate.sh            # fast checks (design system + format + lint + test)
#   FULL=1 bash scripts/validate.sh     # also builds debug APK (~5 min)

set -euo pipefail

# ── Colour helpers ─────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; RESET='\033[0m'

# ── Result tracking ────────────────────────────────────────────────────────────
declare -a RESULTS=()
FAILED=0

_pass() { echo -e "  ${GREEN}PASS${RESET}"; RESULTS+=("${GREEN}PASS${RESET}  $1"); }
_fail() { echo -e "  ${RED}FAIL${RESET}"; RESULTS+=("${RED}FAIL${RESET}  $1"); FAILED=1; }
_skip() { echo -e "  ${YELLOW}SKIP${RESET}  $1"; RESULTS+=("${YELLOW}SKIP${RESET}  $1"); }

# Runs a command; captures stderr+stdout on failure.
run_check() {
  local label="$1"; shift
  printf "  %-54s" "$label"
  local out
  if out=$("$@" 2>&1); then
    _pass "$label"
  else
    _fail "$label"
    echo "$out" | sed 's/^/    /'
  fi
}

# Passes if the grep produces zero matches.
grep_check() {
  local label="$1"; local hits="$2"
  printf "  %-54s" "$label"
  if [[ -z "$hits" ]]; then
    _pass "$label"
  else
    _fail "$label"
    echo "$hits" | sed 's/^/    /'
  fi
}

echo -e "\n${BOLD}=== Jobdun validate.sh ===${RESET}\n"

# ── Section 1: Design system checks ───────────────────────────────────────────
echo -e "${BOLD}[1/3] Design system${RESET}"

# No GoogleFonts.* outside app_theme.dart
grep_check "No GoogleFonts.* outside app_theme.dart" \
  "$(grep -rn --include="*.dart" "GoogleFonts\." lib/ \
     | grep -v "lib/app/theme/app_theme.dart" || true)"

# No Colors.white without // intentional in lib/features/
grep_check "No Colors.white (use AppColors / tokens)" \
  "$(grep -rn --include="*.dart" "Colors\.white" lib/features/ \
     | grep -v "// intentional" || true)"

# No raw SizedBox(width: or SizedBox(height: for spacing in lib/features/
grep_check "No raw SizedBox spacing (use Gap)" \
  "$(grep -rn --include="*.dart" -E "SizedBox\(width: |SizedBox\(height: " \
     lib/features/ || true)"

# No hardcoded Color(0xFF... in lib/features/
grep_check "No hardcoded Color(0xFF in lib/features/" \
  "$(grep -rn --include="*.dart" "Color(0xFF" lib/features/ || true)"

# No inline gradient in lib/features/
grep_check "No inline gradient in lib/features/" \
  "$(grep -rn --include="*.dart" -E "colors: \[Color|colors: \[Colors" \
     lib/features/ || true)"

# No AppColors.* static references in lib/features/
grep_check "No AppColors.* in lib/features/" \
  "$(grep -rn --include="*.dart" "AppColors\." lib/features/ || true)"

echo ""

# ── File-size budget ──────────────────────────────────────────────────────────
# Enforces CLAUDE.md → "Engineering Standards (STRICT)".
# Target: 400 LOC. Hard ceiling: 500 LOC.
# Files in OVERSIZE_ALLOWLIST are grandfathered debt — they must be split
# before more lines are added. Do NOT grow this list without an entry in
# docs/STATE_MANAGEMENT_AUDIT.md justifying the exception.
echo -e "${BOLD}[1.5/3] File-size budget${RESET}"

OVERSIZE_ALLOWLIST=(
  "lib/features/home/presentation/pages/home_page.dart"
  "lib/features/profile/presentation/pages/profile_edit_page.dart"
  # auth_provider.dart split out via data/services/ — back under 500 LOC.
  "lib/features/auth/presentation/pages/register_page.dart"
  "lib/features/profile/presentation/pages/profile_page.dart"
  "lib/features/jobs/presentation/pages/jobs_page.dart"
  "lib/features/applications/presentation/pages/applications_page.dart"
  "lib/features/auth/presentation/pages/phone_auth_page.dart"
  "lib/features/profile/presentation/widgets/trade_category_picker.dart"
  "lib/features/jobs/presentation/pages/job_detail_page.dart"
)

printf "  %-54s" "No new .dart file > 500 LOC (excl. allowlist)"
violations=""
warnings=""
while IFS= read -r -d '' file; do
  rel="${file#./}"
  case "$rel" in
    *.g.dart|*.freezed.dart|lib/generated/*) continue ;;
  esac
  lines=$(wc -l < "$file" | tr -d ' ')
  in_allow=0
  for allow in "${OVERSIZE_ALLOWLIST[@]}"; do
    if [[ "$rel" == "$allow" ]]; then in_allow=1; break; fi
  done
  if [[ "$lines" -gt 500 && "$in_allow" -eq 0 ]]; then
    violations+="$rel ($lines LOC)\n"
  elif [[ "$lines" -gt 400 && "$in_allow" -eq 0 ]]; then
    warnings+="$rel ($lines LOC — over 400 target)\n"
  fi
done < <(find lib -type f -name "*.dart" -print0)
if [[ -z "$violations" ]]; then
  _pass "No new oversize files"
else
  _fail "Files exceed 500 LOC hard ceiling"
  echo -e "$violations" | sed 's/^/    /'
fi
if [[ -n "$warnings" ]]; then
  echo -e "  ${YELLOW}WARN${RESET}  Files over 400 LOC target (split before adding more):"
  echo -e "$warnings" | sed 's/^/    /'
fi

echo ""

# ── Clean Architecture compliance ─────────────────────────────────────────────
# Runs the dedicated check-architecture.sh script (domain purity, layer
# boundary, Supabase isolation, use-case coverage, repo pairing, no orphan
# dirs, currentUserId provider usage). See docs/CLEAN_ARCHITECTURE_AUDIT.md.
echo -e "${BOLD}[1.6/3] Clean Architecture${RESET}"
printf "  %-54s" "check-architecture.sh"
if arch_out=$(bash scripts/check-architecture.sh --quiet 2>&1); then
  _pass "check-architecture.sh"
else
  _fail "check-architecture.sh"
  echo "$arch_out" | sed 's/^/    /'
fi

echo ""

# Schema-diff runs in CI only (see .github/workflows/ci.yml). It needs network
# + linked-project auth and isn't worth dragging onto every developer push.
# If you suspect drift locally, run `bash scripts/sync-schema.sh`.

# ── Section 2: Flutter checks ──────────────────────────────────────────────────
echo -e "${BOLD}[2/3] Flutter${RESET}"

run_check "dart format (no changes)" \
  dart format --output=none --set-exit-if-changed .

run_check "flutter analyze (no fatal infos)" \
  flutter analyze --no-fatal-infos

run_check "flutter test test/features/" \
  flutter test test/features/

echo ""

# ── Section 3: Optional slow build ────────────────────────────────────────────
echo -e "${BOLD}[3/3] Build${RESET}"
if [[ "${FULL:-0}" == "1" ]]; then
  run_check "flutter build apk --debug --no-pub" \
    flutter build apk --debug --no-pub
else
  _skip "flutter build apk  (set FULL=1 to enable, ~5 min)"
fi

echo ""

# ── Summary ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}=== Summary ===${RESET}"
for line in "${RESULTS[@]}"; do
  echo -e "  $line"
done

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}All checks passed.${RESET}"
  exit 0
else
  echo -e "${RED}${BOLD}One or more checks failed. Fix issues above before pushing.${RESET}"
  exit 1
fi
