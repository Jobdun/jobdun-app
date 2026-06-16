# AGENTS.md

Guidance for AI coding agents (Claude Code, Copilot, Codex, Gemini, etc.) working in the Jobdun repo.

## Read this first

1. **`CLAUDE.md`** (project root) — the single source of truth for project context, architecture, commands, packages, design tokens, branch strategy, and CI/CD. Everything in CLAUDE.md applies to all agents and **overrides default agent behavior**.
2. **`design-system/jobdun/MASTER.md`** then **`design-system/jobdun/pages/<page>.md`** — read before building or modifying any screen. Page overrides win over MASTER.
3. **`docs/CLAUDE_SKILLS.md`** — inventory of every installed skill, what it is in plain terms, and when to use it on Jobdun. Only project-scoped skills (`.claude/`) travel to cloud/remote runs; global ones do not.

## Testing UI changes — always screenshot the live app

**Mandatory rule for any change that affects the mobile app's UI** (new screens, redesigns, copy, form fields, navigation, theming, asset swaps):

> **Always run the app in the Android emulator and capture real screenshots before claiming the change is done.**

Mockups, AI-generated UI, and stock photography are not substitutes. The marketing site at `jobdun.com.au` reuses real app screenshots as product visuals, and the docs/verification/ set is the canonical visual record. New screenshots flow into both.

The full workflow is in **`docs/ANDROID_SCREENSHOTS.md`** — emulator boot, APK install, `adb shell` driving, `screencap` capture, asset pipeline. One command:

```bash
bash scripts/capture_app_screenshots.sh
```

When invoked, that script:
1. Boots `jobdun_test` AVD (KVM-accelerated on this host; user is in the `kvm` group).
2. Installs `build/app/outputs/flutter-apk/app-debug.apk` and pre-grants `POST_NOTIFICATIONS` so the runtime dialog doesn't sit on top of FTUE.
3. Launches `MainActivity`, drives the FTUE / role-select / create-account flow with `adb input tap` / `input swipe`, captures each screen with `screencap -p`.
4. Writes the PNGs to `docs/verification/<date>-emulator-NN-<screen>.png` (committed) AND `assets/website/screenshots/<key>.png` (consumed by the marketing site).

The script is **idempotent and re-runnable**. Run it any time the app's UI changes; commit the new verification PNGs alongside the code change so reviewers can see the actual screen.

When the marketing site needs updated product visuals, edit the new `docs/verification/` PNGs down to the 3 site-consumed names (`ftue-splash.png`, `aussie-site.jpg`, `create-account.png`) in `assets/website/screenshots/`, rebuild, and redeploy.

## Required tools & skills

**Four mandatory, always-use skills** (see `CLAUDE.md → Required skills — ALWAYS use` for the canonical list): **`ui-ux-pro-max`**, **`impeccable`**, **`superpowers`** (the `obra` collection), and **`context7`**. Invoke the relevant one *before* acting, every session. `ui-ux-pro-max` + `impeccable` are committed under `.claude/skills/`; `context7` is project-scoped in `.mcp.json`; superpowers is global.

Always reach for these before writing code:

- **Superpowers skills** (`obra`) — invoke the relevant skill *before* acting (not after). Key ones:
  - `superpowers:brainstorming` — before any feature/creative work or entering plan mode.
  - `superpowers:test-driven-development` — before writing implementation code.
  - `superpowers:systematic-debugging` — before proposing any bug fix.
  - `superpowers:verification-before-completion` — before claiming work done / committing / opening a PR.
  - `superpowers:writing-plans` / `superpowers:executing-plans` — for multi-step work.
  - If there's even a 1% chance a skill applies, invoke it. Process skills first, then implementation skills.
- **`ui-ux-pro-max` skill** — for any UI/UX work (planning, building, reviewing screens, components, color, typography, layout, animation). Use it together with the Jobdun design system files above.
- **`impeccable` skill** — design-quality / anti-AI-slop pass on every screen: `/impeccable shape` (plan UX), `/impeccable craft` (design-then-build), `/impeccable critique` + `/impeccable audit` (review), then `/impeccable typeset | layout | colorize | animate | polish | distill | clarify | harden`. Pair with `ui-ux-pro-max` (they complement). ⚠️ Flutter caveat: the `npx impeccable detect` CLI/Chrome detector parse web frameworks (TSX/Astro/CSS), not Dart — use the design-thinking commands, not the detector.
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

**If you touched any mobile UI**, also run the screenshot capture so the verification set is current:

```bash
bash scripts/capture_app_screenshots.sh
# then commit the new docs/verification/*.png and the updated
# assets/website/screenshots/*.png that the marketing site consumes.
```

PRs require passing `flutter analyze` + `flutter test`, a reviewer, screenshots for UI changes, and migration notes for DB changes. Branch from `main`; never commit/push unless asked.
