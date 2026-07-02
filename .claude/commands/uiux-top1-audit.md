---
description: Full UI/UX market audit — score the first-run flow against AU competitor apps, then brainstorm the roadmap to make Jobdun #1 in the Australian trades market
argument-hint: [optional: specific screens/flows to focus on instead of the first-run flow]
---

# Jobdun — Top-1 AU Market UI/UX Audit

**Mission:** Audit Jobdun's mobile app UI/UX with hard evidence, benchmark it against the apps Australian tradies and builders actually use, and produce an approved, prioritised roadmap that makes Jobdun the best-feeling app in this market. Default focus: the **first five screens** a new user meets — this is where #1 is won or lost. If `$ARGUMENTS` names specific screens or flows, audit those instead.

This entire audit runs as the **context-exploration stage of `superpowers:brainstorming`** — invoke that skill FIRST (Skill tool), tell it the topic is "make Jobdun's first-run flow #1 in the AU trades market", and treat Phases 0–3 below as its "explore project context" step. The interactive questions, approaches, and design doc come in Phase 4, after you have evidence. HARD GATE: no implementation, no code, no screen edits until the Phase 4 spec is approved by the user.

## The first five screens (verify against `lib/app/router/app_router.dart` before trusting this list)

1. **Splash** — `/splash`
2. **FTUE carousel** — `/ftue`, 3 slides in `lib/features/ftue/presentation/slides/` (trust, speed, action); treat as one screen with three states
3. **Role select** — Builder vs Trade, inside the register flow
4. **Create account / Login** — `/register` and `/login` (plus `/phone-auth`, `/verify-email` edges)
5. **First authenticated Home** — `/home` on a fresh account, including its empty states

Note: there is no `/onboarding` route despite what CLAUDE.md's route list says — audit what the router actually serves.

## Ground rules (non-negotiable)

- **Skills are mandatory**, in this order: `superpowers:brainstorming` wraps everything; `ui-ux-pro-max` + the design-system docs for every screen assessment; `/impeccable critique` and `/impeccable audit` for the design-quality pass; `superpowers:writing-plans` only after spec approval; `context7` before relying on any Flutter/package API during implementation.
- **Impeccable caveat:** use the design-thinking commands only — the `npx impeccable detect` CLI and Chrome detector cannot parse Dart.
- **Evidence or it didn't happen.** Every score and claim about Jobdun's UI must trace to a real emulator screenshot captured this session. Every claim about a competitor must cite a source (store listing URL, review quote, walkthrough video). Mark inference as inference.
- **Design tokens are locked** (dark slate `#0F172A`, safety orange `#F97316`, Archivo/Inter, Aggressive Flat, MASTER.md anti-patterns). Propose deltas within the system, not rebuilds. If the evidence genuinely argues for a token change, flag it as a strategic decision for the user with computed WCAG math — never change it unilaterally.
- **Don't re-litigate settled debts.** Known open items to reference, not re-discover: CTA white-on-orange contrast 2.80:1 (user decision pending), type-scale Plan B (pending review). Check `docs/DESIGN_SYSTEM_AUDIT.md` and `docs/DESIGN_SYSTEM_SUGGESTIONS.md` before flagging anything colour/type related as new.
- **The working tree may contain WIP.** Never stash, revert, or park it. Audit what renders.
- **Australia-coded throughout:** AU spelling, tradie register (chippies, sparkies, brickies), no soft welcome copy, sunlight-and-gloves usability lens (outdoor glare, gloved thumbs, one-handed use in a ute).

## Phase 0 — Absorb the setup (no opinions yet)

Read in order: `CLAUDE.md`, `docs/ARCHITECTURE.md`, `design-system/jobdun/MASTER.md`, `design-system/jobdun/pages/auth-onboarding.md`, `design-system/jobdun/pages/jobs-feed.md`, `docs/CLAUDE_SKILLS.md`. Then skim the prior audits so you inherit instead of repeat: `docs/DESIGN_SYSTEM_AUDIT.md`, `docs/TRUST_LAYER_UI_UX_AUDIT.md`, `docs/BUILDER_PROFILE_HOME_AUDIT.md`, `docs/VERIFICATION_FLOW_AUDIT.md`, `docs/DESIGN_SYSTEM_TYPOGRAPHY_AUDIT.md`.

Output: a half-page **constraints brief** — locked tokens, standing anti-patterns, open design debts, and what prior audits already fixed.

## Phase 1 — Capture reality

Build the APK and run `bash scripts/capture_app_screenshots.sh` (boots the `jobdun_test` AVD, drives FTUE → role select → create account). The script covers only part of the flow — capture the rest (role select, login, first home on a fresh account, error and empty states) manually with `adb shell input` + `adb exec-out screencap -p`, saved to `docs/verification/<today>-emulator-NN-<screen>.png`. Then read the page source for each screen (`lib/features/ftue/`, `lib/features/auth/presentation/pages/`, the home page) so findings cite `file:line`, not vibes.

No mockups, no stale screenshots from `docs/verification/` — the newest set there is weeks old and predates current work.

## Phase 2 — Current-state audit, screen by screen

For each of the five screens run `/impeccable critique`, then `/impeccable audit` across the whole flow, paired with `ui-ux-pro-max` (query the Flutter stack guidance: `python3 .claude/skills/ui-ux-pro-max/scripts/search.py "<topic>" --stack flutter`). Score each screen 1–10 on these eight dimensions — the same rubric is reused for competitors, so score honestly:

1. **3-second value clarity** — does a first-time tradie/builder know what this app does for them and what to do next?
2. **Friction-to-value** — taps + fields + seconds from this screen to first real value (job seen / job posted)
3. **Trust signals** — verification, licences, ABN, social proof, "real people here" cues
4. **Craft & distinctiveness** — would a designer screenshot this? Any MASTER.md anti-patterns or AI-slop tells?
5. **Accessibility** — computed contrast ratios (from actual hex, not eyeballed), touch targets ≥ 48dp, TalkBack labels, sunlight legibility
6. **Performance feel** — cold start, skeletons vs spinners, jank, perceived speed
7. **Copy voice** — direct, Aussie, zero soft-welcome filler; would a sparkie smirk or cringe?
8. **Flow logic** — back behaviour, dead ends, error/edge states, keyboard handling

Output per screen: screenshot, scores, top 3 issues with `file:line` evidence, and the single highest-leverage fix.

## Phase 3 — Competitor benchmark (current research, not memory)

Research what AU tradies/builders actually have installed, via WebSearch + store listings + review mining — do not trust training data for 2026 market state. Seed list, then verify and extend with "best app for tradies Australia 2026" / store-chart searches:

- **Lead-gen / marketplace side:** hipages, Airtasker, ServiceSeeking, Oneflare
- **Job-board side:** SEEK, Jora, Indeed
- **First-run craft references (global, steal patterns not positioning):** Uber Driver, Airbnb, Duolingo

For each competitor answer: how do their first five screens handle (a) value pitch before signup, (b) signup friction — count the taps and fields, (c) role/intent capture, (d) trust/verification display, (e) first-feed relevance. **Mine their Play Store / App Store reviews for recurring UX complaints** — competitor pain points are Jobdun's open goals. Cite everything.

Output: a comparison matrix — rows = the 8 rubric dimensions, columns = Jobdun + each competitor — plus a "review-mined complaints" list per competitor.

## Phase 4 — Brainstorm the #1 thesis with the user (interactive)

Now return to the `superpowers:brainstorming` flow with the evidence in hand: ask the user its clarifying questions **one at a time** (what "#1" means to them — rating? activation? word-of-mouth on site?; which north-star metric: time-to-first-application for trades, time-to-first-job-post for builders, D7 return; appetite for structural vs cosmetic change). Propose 2–3 roadmap shapes with trade-offs and a recommendation. Then present the design section by section and write the approved spec to `docs/superpowers/specs/<today>-top1-uiux-design.md`.

The roadmap inside the spec: **top 10 improvements ranked by new-user impact × effort**, each with screen, change, rationale citing Phase 2/3 evidence, design-system compliance note, and size class (quick win ≤ 1 day / structural / strategic-needs-product-decision).

## Phase 5 — Write the audit report

Consolidate Phases 0–3 into `docs/UIUX_MARKET_AUDIT_<today>.md`: exec summary with the per-screen scorecard table, per-screen findings, competitor matrix, review-mined open goals, gap analysis (where Jobdun already wins / lags / where nobody is good), and the approved roadmap. This document plus the spec are the deliverables. **STOP here and hand both to the user.**

## Phase 6 — Implement (only after explicit approval)

On the user's go: `superpowers:writing-plans` → execute with `superpowers:test-driven-development`, verify APIs through `context7`, refine visuals with the impeccable refinement commands (`typeset | layout | colorize | animate | polish | distill | clarify | harden`). Definition of done per change: `bash scripts/validate.sh` green, re-run the screenshot script, before/after PNG pairs committed to `docs/verification/`, and `superpowers:verification-before-completion` passed before claiming anything works.
