# Security Audit — <YYYY-MM-DD>

_Scope: Jobdun Supabase backend (DB/RLS, Postgres functions, Edge Functions, Auth/JWT, Storage, secrets). Graded against OWASP API Security Top 10 (2023) + OWASP Top 10 (2021). Fixes are **drafted, not applied**._

## Verdict

<one line: SHIP / HOLD. e.g. "HOLD — 1 BLOCKER (self-grantable trust flags), 3 FAILs. Backend otherwise solid.">

## BLOCKERS

_Exploitable now or exposing data. Fix before anything ships. Ranked by blast radius._

### B1 · <short title> · `<OWASP tag>`
- **Plain English:** <what this means to a non-specialist — who can do what to whom>
- **Evidence:** `<file:line>` — <what the code/policy actually does>
- **Impact:** <concrete: the exploit path>
- **Drafted fix:** `supabase/migrations/<ts>_<slug>.sql` (+ `supabase/rollbacks/…`) — <recipe used>

## FAILs

_Real weaknesses, not yet a live breach. Fix soon._

### F1 · <short title> · `<OWASP tag>`
- **Plain English:** <…>
- **Evidence:** `<file:line>`
- **Drafted fix:** `<path>` — <recipe> _(or: needs product decision — <the decision>)_

## PASS ledger

_Verified solid — do not re-litigate next run._

- ✅ `<gate>` — <what was verified> (`<file:line>`)
- ✅ RLS enabled + forced on <N> user-data tables
- ✅ `search_trades` is `SECURITY DEFINER` + sanitised
- ✅ PII views (`trade_profiles_public`, `builder_profiles_public`) gate rates + round coords

## Drafted fixes

_All written, NONE applied. Review, then apply BLOCKERs first (`supabase db push` is the human's call)._

| File | Fixes | Risk | Needs product decision? |
|---|---|---|---|
| `supabase/migrations/<ts>_<slug>.sql` | B1 | medium | no |

## Method

- **context7 refs pulled:** <Supabase RLS / Edge / Storage docs consulted>
- **OWASP versions:** API Security Top 10 = 2023; Web Top 10 = 2021
- **Scripts run:** `discover.sh` (<summary>), `grep-probes.sh` (<summary>)
- **Not verifiable from files:** <anything that needs a live DB / dashboard check>
