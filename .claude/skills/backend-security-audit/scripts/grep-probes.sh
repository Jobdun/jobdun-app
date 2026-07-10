#!/usr/bin/env bash
# grep-probes.sh — static security probes over the repo. Findings FEED the Assess step; not a gate itself.
# Run from repo root: bash .claude/skills/backend-security-audit/scripts/grep-probes.sh
set -uo pipefail
fail=0
hit() { printf '  🔴 %s\n' "$1"; fail=1; }
ok()  { printf '  🟢 %s\n' "$1"; }

printf '== API8/A02 · service-role key reachable from client (lib/) ==\n'
# Exclude generated files AND comment-only lines (doc comments mentioning service_role are not usage).
if grep -rInE 'service_role|SERVICE_ROLE' lib/ 2>/dev/null \
     | grep -vE '\.g\.dart' \
     | grep -vE ':[0-9]+:[[:space:]]*(//|///|\*|/\*)' ; then
  hit "service_role referenced in non-comment client code — the client must only ever use the anon key"
else ok "no service_role usage under lib/ (comments ignored)"; fi

printf '\n== API8/A02 · .env bundled as a Flutter asset (ships secrets in the app) ==\n'
if grep -nE '^[[:space:]]*-[[:space:]]+\.env[[:space:]]*$' pubspec.yaml 2>/dev/null; then
  hit ".env is listed as a bundled asset in pubspec.yaml"
else ok ".env is not a bundled asset"; fi

printf '\n== A02 · hardcoded secret VALUES in tracked client files ==\n'
# Match real secret VALUES (JWT eyJ… or sk_live_…), not key names, empty templates, or env() refs.
# Excludes .example templates, .server files, markdown, and Edge Functions (server-side).
if git grep -InE '(sk_live_[A-Za-z0-9]{16,}|(SUPABASE_SERVICE_ROLE_KEY|TWILIO_AUTH_TOKEN|service_role)["[:space:]]*[:=]["[:space:]]*eyJ[A-Za-z0-9_.-]{20,})' \
     -- ':!supabase/functions/**' ':!**/*.server' ':!**/.env.server' ':!**/*.md' ':!**/*.example' 2>/dev/null ; then
  hit "hardcoded secret VALUE (JWT/live key) in a client-tracked file"
else ok "no hardcoded secret values in client-tracked files (templates/env-refs ignored)"; fi

printf '\n== API7/API8 · Edge Function wildcard CORS ==\n'
if grep -rInE "Allow-Origin[\"']?[[:space:]]*[:,][[:space:]]*[\"']\*" supabase/functions/ 2>/dev/null; then
  hit "wildcard CORS ('*') in an Edge Function — scope to known origins for authenticated routes"
else ok "no wildcard CORS found in Edge Functions"; fi

printf '\n== API5 · SECURITY DEFINER without SET search_path (migrations) ==\n'
found=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  grep -q 'search_path' "$f" || { printf '  ⚠ %s — has SECURITY DEFINER, no search_path\n' "$f"; found=1; }
done < <(grep -rIlE 'SECURITY DEFINER' supabase/migrations/ 2>/dev/null)
[ "$found" -eq 0 ] && ok "every DEFINER migration sets search_path (or none found)"

printf '\n== API7/API10 · external HTTP calls in Edge Functions (check for SSRF / blind trust) ==\n'
grep -rInE "fetch\(|https?://" supabase/functions/ 2>/dev/null | grep -vE '_shared|deno\.land|esm\.sh|jsr\.io' | head -30 \
  || echo "  (no external fetch targets found — verify manually)"

printf '\n---\nprobes done (informational; exit always 0). Feed 🔴/⚠ lines into the Assess step.\n'
exit 0
