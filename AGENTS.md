# AGENTS.md

Guidance for AI coding agents (Claude Code, Copilot, Codex, Gemini, etc.) working in the Jobdun repo.

## Read this first

1. **`CLAUDE.md`** (project root) — the single source of truth for project context, architecture, commands, packages, design tokens, branch strategy, and CI/CD. Everything in CLAUDE.md applies to all agents and **overrides default agent behavior**.
2. **`design-system/jobdun/MASTER.md`** then **`design-system/jobdun/pages/<page>.md`** — read before building or modifying any screen. Page overrides win over MASTER.
3. **`docs/CLAUDE_SKILLS.md`** — inventory of every installed skill, what it is in plain terms, and when to use it on Jobdun. Only project-scoped skills (`.claude/`) travel to cloud/remote runs; global ones do not.

## Required tools & skills

Always reach for these before writing code:

- **Superpowers skills** — invoke the relevant skill *before* acting (not after). Key ones:
  - `superpowers:brainstorming` — before any feature/creative work or entering plan mode.
  - `superpowers:test-driven-development` — before writing implementation code.
  - `superpowers:systematic-debugging` — before proposing any bug fix.
  - `superpowers:verification-before-completion` — before claiming work done / committing / opening a PR.
  - `superpowers:writing-plans` / `superpowers:executing-plans` — for multi-step work.
  - If there's even a 1% chance a skill applies, invoke it. Process skills first, then implementation skills.
- **`ui-ux-pro-max` skill** — for any UI/UX work (planning, building, reviewing screens, components, color, typography, layout, animation). Use it together with the Jobdun design system files above.
- **Context7** — use the Context7 MCP to pull up-to-date, version-accurate docs for Flutter, Dart, Supabase, Riverpod, GoRouter, and any package in CLAUDE.md's "Key packages" list before relying on API details. Prefer Context7-verified APIs over memory.
- **Claude Code skills** generally — check the available-skills list each session and use the matching skill rather than improvising (e.g. `simplify`, `review`, `security-review`, `update-config`).

## Best practices (from CLAUDE.md — follow exactly)

- **Architecture**: Feature-first Clean Architecture. Domain layer must not import Flutter/Supabase. Only the `data/` layer talks to Supabase. Never cross sibling feature layers directly.
- **Supabase**: anon key only (never service-role) in the Flutter app; privileged ops via RLS / Edge Functions. RLS required on all tables.
- **State / nav**: Riverpod (preferred) + GoRouter, per the documented route graph and job/application lifecycles.
- **UI/UX conventions**:
  - Spacing: `Gap(n)` — never raw `SizedBox(height/width:)`.
  - Sizing: `flutter_screenutil` extensions (`.w/.h/.sp/.r`) — never hardcoded pixels.
  - Icons: `Iconsax.*` by default.
  - Fonts: configure `google_fonts` only in `lib/app/theme/app_theme.dart` — never `GoogleFonts.*` per widget.
  - No white backgrounds, ghost buttons, gradients, thin fonts, or `Color(0xFF...)` / `AppColors.*` in `lib/features/`.
  - Empty states: Lottie + headline + CTA. Bottom sheets: `modal_bottom_sheet`. Forms: `flutter_form_builder` + `form_builder_validators`.
- **Use cases** return `Future<Either<Failure, T>>` (fpdart).

## Before you finish

Run local validation and confirm it passes — do not claim success without evidence:

```bash
bash scripts/validate.sh          # design + format + lint + tests (~60s)
FULL=1 bash scripts/validate.sh   # also builds debug APK (~5 min)
```

PRs require passing `flutter analyze` + `flutter test`, a reviewer, screenshots for UI changes, and migration notes for DB changes. Branch from `main`; never commit/push unless asked.
