# 📦 Archive — do not read or action

> **STATUS: ARCHIVED — historical reference only.**
> Everything in this folder is a **point-in-time snapshot** (audits, plans, sprint
> prompts, reality checks, specs) that reflected the codebase on the date it was
> written. It is **not** a description of how the system currently works.

## For a future AI / Claude Code

**Do not read these files as current truth, and do not action their findings.**
An audit here may say "X is missing" or "fix Y" — those issues were captured at a
moment in time and are very likely already resolved. Treating them as live will
cause you to "re-fix" done work or trust stale claims.

If you need ground truth, read the **live** sources instead:
- The actual code in `lib/`
- `supabase/migrations/` for schema/RLS reality
- `CLAUDE.md` at the repo root for current conventions
- `git log` / `git blame` for history

These docs were moved here on **2026-05-30** to keep them out of the default
reading surface. They remain in git history regardless, so nothing is lost.

## What's here
- Top-level `*.md` — audits, plans, and reference snapshots from ~May 2026
- `audit/` — numbered backend/architecture audit set (00–08)
- `superpowers/` — dated plans + specs from the superpowers workflow
