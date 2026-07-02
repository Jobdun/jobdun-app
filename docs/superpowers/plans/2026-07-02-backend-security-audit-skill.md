# Backend Security Audit Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `.claude/skills/backend-security-audit/` — a repeatable, OWASP-anchored security audit skill for the Jobdun Supabase backend that discovers current state, grades it against OWASP API Top 10 (2023) + Web Top 10 (2021), and drafts (never auto-applies) fixes.

**Architecture:** Progressive-disclosure skill. Lean `SKILL.md` (workflow + gate index + report format) delegates depth to `references/` (OWASP mappings, threat model, fix recipes) and mechanical enumeration to `scripts/` (drift-proof discovery + static probes). Follows the repo's existing `play-review-check` / `app-store-review-check` audit-skill pattern.

**Tech Stack:** Markdown skill + Bash scripts (grep/awk over `supabase/schema.sql`), optional read-only Supabase introspection. Authored via `writing-skills` (mechanical→scripts, judgment→prose) methodology.

**Spec:** `docs/superpowers/specs/2026-07-02-backend-security-audit-skill-design.md` (authoritative for content; this plan sequences the build).

**Acceptance (from spec §10):** A fresh `backend-security-audit` run must (1) flag API3 BLOCKER for self-grantable trust flags, (2) flag API8/A02 for the bundled service-role key/rotation, (3) flag API5 for any `SECURITY DEFINER` fn without pinned `search_path`, (4) flag API1/API9 for unindexed FKs / schema drift, and (5) NOT false-BLOCKER the verified-solid items (RLS-forced tables, sanitised `search_trades`, gated PII views).

---

## File Structure

| File | Responsibility |
|---|---|
| `.claude/skills/backend-security-audit/SKILL.md` | Entry point: frontmatter, when-to-use, 5-step workflow, one-line gate index, report format. Stays under size budget. |
| `references/jobdun-threat-model.md` | Jobdun's attack surface: anon-key trust, RLS reliance, edge-fn auth/CORS, bucket privacy matrix, JWT hook, trust boundaries. |
| `references/owasp-api-top10.md` | The 10 API gates. Per gate: Plain English · Discovery command · PASS criteria · FAIL/BLOCKER criteria · Fix recipe pointer. |
| `references/owasp-web-top10.md` | Net-new Web gates (A02/A03/A04/A06/A08/A09); overlaps redirect to the API file. |
| `references/fix-patterns.md` | Canonical drafted-fix recipes (RLS template, DEFINER `search_path` pin, index-the-FK, secret rotation, CORS lock, private-bucket). |
| `scripts/discover.sh` | Enumerate tables/RLS/policies/DEFINER fns/FKs/indexes/buckets from `supabase/schema.sql`; `--live` read-only introspection fallback. |
| `scripts/grep-probes.sh` | Static probes: service-role key in client, hardcoded secrets, unpinned `search_path`, CORS `*`, public buckets. |
| `assets/report-template.md` | Dated PASS/FAIL/BLOCKER report skeleton matching `BACKEND_FULL_AUDIT`. |

**Gate index (canonical order, used by SKILL.md + report):** API1 BOLA, API2 AuthN, API3 Property-Auth, API4 Resource, API5 Function-Auth, API6 Business-Flows, API7 SSRF, API8 Misconfig, API9 Inventory, API10 3rd-Party, then net-new Web: A02 Crypto, A03 Injection, A04 Insecure-Design, A06 Components, A08 Data-Integrity, A09 Logging.

---

## Task 1: Scaffold + SKILL.md

**Files:**
- Create: `.claude/skills/backend-security-audit/SKILL.md`

- [ ] **Step 1: Create the skill directory tree**

```bash
mkdir -p .claude/skills/backend-security-audit/{references,scripts,assets}
```

- [ ] **Step 2: Write SKILL.md**

Frontmatter + body. Frontmatter matches repo convention (`play-review-check`):

```markdown
---
name: backend-security-audit
description: Use when auditing the Jobdun Supabase backend for security, hardening the database/Edge Functions/Auth/Storage, before a release or after schema/migration/RLS/policy/Edge-Function changes, or when asked "is the backend secure". Discovers current state, grades against OWASP API Security Top 10 (2023) + OWASP Top 10 (2021), reports PASS/FAIL/BLOCKER with file:line, and drafts (never auto-applies) migration/patch fixes. Backend only — not Flutter client or admin web.
---
```

Body sections (keep lean; delegate depth to `references/`):
1. **Overview** — what/why, one paragraph. Companion to `play-review-check`/`app-store-review-check`.
2. **When to Use** — before release, after migrations/RLS/policy/Edge-Function/storage changes, on demand.
3. **The 5-step workflow** — Research (context7 + pin OWASP versions) → Discover (`scripts/`) → Assess (walk every gate, PASS/FAIL/BLOCKER, cite `file:line`) → Draft fixes (from `fix-patterns.md`, DO NOT apply) → Report (`assets/report-template.md` → `docs/SECURITY_AUDIT_<date>.md`).
4. **Gate index** — the 16 gates (one line each) with a pointer to the two OWASP reference files. NO gate skipped; "N/A" needs a one-line justification.
5. **Rules** — draft-only (never `supabase db push`); keep rollbacks; product-decision findings state the decision, don't guess; validate against spec §10.
6. **Report format** — the section order.

- [ ] **Step 3: Verify frontmatter parses + triggers**

Run: `head -5 .claude/skills/backend-security-audit/SKILL.md` and confirm `name:` + `description:` present, description contains trigger words ("secure", "backend", "audit", "RLS", "OWASP").
Expected: frontmatter block intact.

- [ ] **Step 4: Verify size budget**

Run: `wc -l .claude/skills/backend-security-audit/SKILL.md`
Expected: comfortably under 200 lines (depth lives in references).

---

## Task 2: references/jobdun-threat-model.md

**Files:**
- Create: `.claude/skills/backend-security-audit/references/jobdun-threat-model.md`

- [ ] **Step 1: Write the threat model** (port spec §1 + design tokens). Must contain:
  - **Trust boundaries:** `anon` (unauthenticated) → `authenticated` (RLS-scoped) → `service_role` (bypasses RLS, server-only) → `admin` (role-gated via JWT claim). The anon key is PUBLIC by design; all protection is RLS.
  - **Surface inventory:** 4 Edge Functions (`jobs-feed`, `push-send`, `verify-abn`, `verify-licence`), JWT `custom_access_token_hook`, 5 buckets with intended privacy (`avatars`=public, `company-logos`=public, `portfolio-images`=public, `verification-documents`=**PRIVATE**, `job-attachments`=**PRIVATE/relationship-scoped**).
  - **Core tables** and who may read/write each (owner / relationship / admin).
  - **Known-open baseline** (spec §1) so the auditor confirms rather than rediscovers.

- [ ] **Step 2: Verify** — `grep -c "verification-documents" <file>` ≥ 1 and PRIVATE marked. Expected: pass.

---

## Task 3: references/owasp-api-top10.md

**Files:**
- Create: `.claude/skills/backend-security-audit/references/owasp-api-top10.md`

- [ ] **Step 1: Write all 10 API gates.** Each gate uses this EXACT sub-structure (worked example for API3 shown; replicate the shape for API1–API10 using spec §6 content):

```markdown
## API3:2023 — Broken Object Property Level Authorization

**Plain English:** Even on a row you're allowed to touch, can you read or write fields you shouldn't — e.g. set your own `verified`/trust flag to true?

**Discover:**
- `bash scripts/discover.sh --policies` → list every UPDATE policy and its WITH CHECK.
- Grep policies whose WITH CHECK does NOT exclude trust/verification/role columns.

**PASS when:** every user-writable table has a WITH CHECK that blocks writes to verification/trust/role/rating columns; PII columns are gated by a view or column privilege.

**FAIL / BLOCKER when:** a user can UPDATE a trust/verification/role column on their own row (BLOCKER — privilege/trust escalation); PII column readable beyond intended audience (FAIL).

**Fix:** `fix-patterns.md → Column-guard WITH CHECK`. Known-open: self-grantable trust flags = **BLOCKER**.
```

Replicate for API1 (RLS enabled+forced, owner/relationship scoping, public-view leakage), API2 (JWT hook integrity, admin non-self-assign, OTP/session), API4 (pagination caps, rate limits on push/OTP/search), API5 (DEFINER `search_path` pinned, `admin_*` role checks), API6 (throttles on job/application/broadcast/verification), API7 (external URLs constant, no user-controlled fetch), API8 (bucket privacy, service-role never client-side, CORS), API9 (schema↔model drift, stray debug RPCs, deprecated columns), API10 (validate ABR/licence/Twilio/FCM responses, timeouts).

- [ ] **Step 2: Verify all 10 present** — `grep -c "^## API" <file>`. Expected: `10`.

---

## Task 4: references/owasp-web-top10.md

**Files:**
- Create: `.claude/skills/backend-security-audit/references/owasp-web-top10.md`

- [ ] **Step 1: Write the net-new Web gates** (A02, A03, A04, A06, A08, A09) using the same sub-structure as Task 3, content from spec §6 "Web Top 10" block. At the top, a redirect table: A01→API1/API3/API5, A05→API8, A07→API2, A10→API7 (audited there, not duplicated).

- [ ] **Step 2: Verify** — `grep -c "^## A0" <file>` ≥ 6 and redirect table present. Expected: pass.

---

## Task 5: references/fix-patterns.md

**Files:**
- Create: `.claude/skills/backend-security-audit/references/fix-patterns.md`

- [ ] **Step 1: Write canonical fix recipes**, each a copy-paste template with a `<placeholder>` legend and a matching rollback:
  - **Enable+force RLS** on a table.
  - **Owner-scoped SELECT/UPDATE policy** (by `auth.uid()`).
  - **Column-guard WITH CHECK** (block writes to trust/verification/role columns) — the P0 fix.
  - **DEFINER search_path pin** (`ALTER FUNCTION ... SET search_path = ''` / `public, pg_temp`).
  - **Index-the-FK** (`CREATE INDEX CONCURRENTLY`).
  - **Private bucket + storage policy**.
  - **Edge Function CORS lock** (allowlist origin, not `*`).
  - **Secret rotation checklist** (rotate service-role + Twilio, confirm `.env` split guard).
  - Each recipe notes: risk level, whether it needs a product decision, and the rollback path (`supabase/rollbacks/`).

- [ ] **Step 2: Verify** — `grep -c "Rollback" <file>` ≥ 6 (every DB-mutating recipe has one). Expected: pass.

---

## Task 6: scripts/discover.sh (+ test)

**Files:**
- Create: `.claude/skills/backend-security-audit/scripts/discover.sh`

- [ ] **Step 1: Write discover.sh** — parses `supabase/schema.sql` (no hardcoded table names). Sections selectable by flag (`--tables --rls --policies --definers --fks --buckets`, default all):

```bash
#!/usr/bin/env bash
set -euo pipefail
SCHEMA="${SCHEMA:-supabase/schema.sql}"
[ -f "$SCHEMA" ] || { echo "ERR: $SCHEMA not found (run: supabase db dump)"; exit 2; }

section() { echo; echo "== $1 =="; }

want() { [ "$#" -eq 0 ] || printf '%s\n' "$ARGS" | grep -q -- "$1"; }
ARGS="${*:-all}"; [ "$ARGS" = "all" ] && ARGS="--tables --rls --policies --definers --fks --buckets"

if printf '%s' "$ARGS" | grep -q -- '--tables'; then
  section "TABLES"; grep -oE 'CREATE TABLE (IF NOT EXISTS )?[^ (]+' "$SCHEMA" | sed 's/CREATE TABLE \(IF NOT EXISTS \)\?//' | sort -u
fi
if printf '%s' "$ARGS" | grep -q -- '--rls'; then
  section "RLS ENABLED";  grep -oE 'ALTER TABLE [^ ]+ ENABLE ROW LEVEL SECURITY' "$SCHEMA" | awk '{print $3}' | sort -u
  section "RLS FORCED";   grep -oE 'ALTER TABLE [^ ]+ FORCE ROW LEVEL SECURITY'  "$SCHEMA" | awk '{print $3}' | sort -u
fi
if printf '%s' "$ARGS" | grep -q -- '--policies'; then
  section "POLICIES"; grep -nE 'CREATE POLICY' "$SCHEMA"
fi
if printf '%s' "$ARGS" | grep -q -- '--definers'; then
  section "SECURITY DEFINER FUNCTIONS"; grep -nE 'SECURITY DEFINER' "$SCHEMA"
  section "DEFINER WITHOUT PINNED search_path (SUSPECT)"
  # flag definer functions with no 'SET search_path' within their body window
  awk '/SECURITY DEFINER/{d=NR} /SET search_path/{if(d && NR-d<40) ok[d]=1} END{}' "$SCHEMA" >/dev/null 2>&1 || true
  grep -nE 'SECURITY DEFINER' "$SCHEMA" | while IFS=: read -r ln _; do
    if ! sed -n "$((ln-15)),$((ln+15))p" "$SCHEMA" | grep -q 'SET search_path'; then echo "  suspect @ line $ln"; fi
  done
fi
if printf '%s' "$ARGS" | grep -q -- '--fks'; then
  section "FOREIGN KEYS"; grep -nE 'REFERENCES [a-zA-Z_."]+' "$SCHEMA"
  section "INDEXES"; grep -nE 'CREATE (UNIQUE )?INDEX' "$SCHEMA"
fi
if printf '%s' "$ARGS" | grep -q -- '--buckets'; then
  section "STORAGE BUCKETS"; grep -nE "storage\\.buckets" "$SCHEMA" | grep -iE 'insert|public|id' || echo "  (none in schema.sql — check migrations)"
fi
```

- [ ] **Step 2: Make executable + run against the real schema**

Run: `chmod +x .claude/skills/backend-security-audit/scripts/discover.sh && bash .claude/skills/backend-security-audit/scripts/discover.sh --tables`
Expected: prints a sorted, de-duplicated list of real Jobdun tables (`profiles`, `jobs`, `job_applications`, `messages`, `trade_profiles`, ...). If empty → schema.sql format changed; fix the grep before proceeding.

- [ ] **Step 3: Run the DEFINER suspect check**

Run: `bash .claude/skills/backend-security-audit/scripts/discover.sh --definers`
Expected: lists `SECURITY DEFINER` functions and flags any without a nearby `SET search_path` as "suspect". Sanity-check ≥1 known DEFINER fn (`search_trades`) appears.

---

## Task 7: scripts/grep-probes.sh (+ test)

**Files:**
- Create: `.claude/skills/backend-security-audit/scripts/grep-probes.sh`

- [ ] **Step 1: Write grep-probes.sh** — static, client-vs-server aware:

```bash
#!/usr/bin/env bash
set -uo pipefail
fail=0
hit() { echo "🔴 $1"; fail=1; }
ok()  { echo "🟢 $1"; }

echo "== service-role key reachable from client =="
if grep -rInE 'service_role|SERVICE_ROLE' lib/ 2>/dev/null | grep -vE '\.g\.dart'; then hit "service_role referenced under lib/ (client)"; else ok "no service_role under lib/"; fi

echo "== secrets in bundled assets =="
if grep -qE '^\s*-\s*\.env\s*$' pubspec.yaml 2>/dev/null; then hit ".env bundled as a Flutter asset (pubspec.yaml)"; else ok ".env not a bundled asset"; fi

echo "== hardcoded secrets in tracked non-server files =="
git grep -InE '(SUPABASE_SERVICE_ROLE_KEY|TWILIO_AUTH_TOKEN|sk_live_|AIza[0-9A-Za-z_-]{20,})' -- ':!*.server' ':!**/.env.server' ':!supabase/functions/**' 2>/dev/null && hit "possible hardcoded secret" || ok "no obvious hardcoded secrets in client-tracked files"

echo "== Edge Function CORS wildcard =="
if grep -rInE "Access-Control-Allow-Origin['\"]?\s*[:,]\s*['\"]\\*" supabase/functions/ 2>/dev/null; then hit "CORS '*' in an Edge Function"; else ok "no wildcard CORS"; fi

echo "== DEFINER without pinned search_path (migrations) =="
grep -rIlE 'SECURITY DEFINER' supabase/migrations/ 2>/dev/null | while read -r f; do
  grep -q 'SET search_path' "$f" || echo "  ⚠ $f has SECURITY DEFINER, check search_path"
done

exit $fail
```

- [ ] **Step 2: Make executable + run**

Run: `chmod +x .claude/skills/backend-security-audit/scripts/grep-probes.sh && bash .claude/skills/backend-security-audit/scripts/grep-probes.sh`
Expected: prints 🟢/🔴 lines. This is a probe, not a gate — findings feed the Assess step. Confirm it runs without a bash error and evaluates the `.env`-bundled check (the known leak vector).

---

## Task 8: assets/report-template.md

**Files:**
- Create: `.claude/skills/backend-security-audit/assets/report-template.md`

- [ ] **Step 1: Write the template** — sections from spec §7: `Verdict` / `BLOCKERS` / `FAILs` / `PASS ledger` / `Drafted fixes` / `Method`. Each finding row: **Plain English · OWASP tag · `file:line` · drafted-fix reference**. Include a filled one-line example per section so the format is unambiguous.

- [ ] **Step 2: Verify** — `grep -cE '^## ' <file>` == 6. Expected: `6`.

---

## Task 9: ACCEPTANCE — run the real audit

**Files:**
- Create: `docs/SECURITY_AUDIT_2026-07-02.md`
- Create (drafts, unapplied): `supabase/migrations/<ts>_<slug>.sql` + `supabase/rollbacks/...` per BLOCKER

- [ ] **Step 1: Run the full skill workflow** against the live backend: Research → Discover (`discover.sh`, `grep-probes.sh`) → Assess every gate → Draft fixes → Report.

- [ ] **Step 2: Verify acceptance (spec §10)** — the report MUST contain:
  - API3 **BLOCKER** — self-grantable trust flags.
  - API8/A02 finding — service-role key / rotation.
  - API5 finding — any DEFINER fn without pinned `search_path` (or explicit PASS if all pinned).
  - API1/API9 finding — unindexed FKs / schema drift.
  - PASS ledger includes RLS-forced tables, sanitised `search_trades`, gated PII views (NOT false BLOCKERs).
  If any known-open item is missing → the reference checks are too weak; fix them and re-run (writing-skills RED→GREEN).

- [ ] **Step 3: Verify drafts are unapplied** — `git status supabase/migrations/` shows new files; confirm none were pushed (`supabase db push` NOT run).

---

## Task 10: Verify + commit

- [ ] **Step 1: verification-before-completion** — re-read spec goals vs. built artifact; confirm all 16 gates covered, scripts run clean, acceptance met, no auto-applied fixes.

- [ ] **Step 2: Scoped commit (skill + spec + plan + report only — NOT user WIP)**

```bash
git add .claude/skills/backend-security-audit/ \
        docs/superpowers/specs/2026-07-02-backend-security-audit-skill-design.md \
        docs/superpowers/plans/2026-07-02-backend-security-audit-skill.md \
        docs/SECURITY_AUDIT_2026-07-02.md \
        supabase/migrations supabase/rollbacks
git status   # confirm ios/, LEGAL_REVIEW_PACKET.md, real_logo/ are NOT staged
git commit -m "feat(security): add backend-security-audit skill + first OWASP audit"
```

Expected: only security-work files staged; user WIP untouched. Do NOT push (develop is shared — user pushes).

---

## Self-Review (writing-plans)

- **Spec coverage:** §4 architecture→Tasks 1–8; §5 workflow→SKILL.md (T1) + T9 run; §6 OWASP→T3/T4; §7 report→T8; §8 fix-drafting→T5+T9; §9 scripts→T6/T7; §10 validation→T9 acceptance; §11 build methodology→writing-skills throughout. No gap.
- **Placeholder scan:** script bodies are complete + runnable; reference files use a worked-example template (API3) replicated across gates from committed spec §6 — concrete, not "TODO".
- **Consistency:** gate index order identical in File Structure, T3/T4, T8, T9. Script paths identical everywhere. `fix-patterns.md` recipe names referenced by T3 match T5 definitions (Column-guard WITH CHECK, DEFINER search_path pin, Index-the-FK).
