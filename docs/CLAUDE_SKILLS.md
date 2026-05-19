# Claude Code Skills — Jobdun Inventory & Plain-English Usage Guide

> Snapshot: 2026-05-20. Regenerate by running the scope checks in §7.
> **What is a "skill"?** A folder of instructions Claude loads *on demand* when your
> request matches it. Think of it as a specialist Claude can phone for advice mid-task.
> You don't install knowledge into your code — Claude reads the skill, then acts.
>
> Skills arrive three ways:
> - **manual** — a folder you drop in `.claude/skills/` (you own it, it's committed)
> - **plugin** — installed from a marketplace; one plugin can bundle many skills
> - **bundled** — ships inside Claude Code itself; always there, invoked with `/name`

---

## 0. 30-second summary — what you actually use on Jobdun

| You're doing… | Skill that fires | Layman's terms |
|---------------|------------------|----------------|
| Any screen / widget / colour / layout | **ui-ux-pro-max** | Your design-system brain. Knows Jobdun's dark+orange look. |
| Anything Supabase (DB, auth, RLS, storage, edge fn) | **supabase** | Backend expert for your exact Supabase client version. |
| Writing/finalising a migration or slow query | **supabase-postgres-best-practices** | Database tuning — indexes, RLS speed, scale to 25k users. |
| Starting a feature | **brainstorming** → **writing-plans** | Forces "what & why" before code. Stops wasted work. |
| Fixing a bug | **systematic-debugging** | Find root cause before patching. |
| Writing feature/bugfix code | **test-driven-development** | Write the failing test first. |
| About to say "done" | **verification-before-completion** | Prove it works (run the check) before claiming success. |
| Before a PR / merge | **requesting-code-review**, `/security-review` | Self-review + security pass on auth/RLS/PII diffs. |

Everything else listed below is either situational or **noise you can ignore**
(most of the Vercel + document/office skills — Jobdun is a Flutter mobile app).

---

## 1. PROJECT scope — bound to Jobdun (`./.claude/`, committed, travels with repo)

These define how Claude works **on Jobdun specifically** and bind any teammate + CI.

### 1.1 Manual skill — `./.claude/skills/`

| Skill | What it is (layman) | Use it in Jobdun when… |
|-------|---------------------|------------------------|
| **ui-ux-pro-max** | A design consultant that knows 67 styles, 96 palettes, fonts, Flutter UI patterns — and is wired to *your* design system. | **Any** visual work: a new screen, a button, spacing, colours, "make this look better". It auto-reads `design-system/jobdun/MASTER.md` then the page override. ⚠️ Also installed globally (identical) — see §5. |

### 1.2 Project-scoped plugins — declared in `./.claude/settings.json`

Source: `supabase-agent-skills` marketplace (official Supabase). Version `daaed4afe2c7`.
**Both plugins below bundle the same two skills** (`supabase` + `supabase-postgres-best-practices`) — see §5 redundancy note.

| Skill | What it is (layman) | Use it in Jobdun when… |
|-------|---------------------|------------------------|
| **supabase** | Your backend co-pilot. Up-to-date on the `supabase_flutter` client, Auth, RLS, Storage, Realtime, Edge Functions — *trust it over Claude's memory* for version-specific API. | Touching anything backend: writing a query/repository in `data/`, an RLS policy, a storage upload (`avatars`, `verification-documents`…), or starting the empty `supabase/functions/` Edge work. |
| **supabase-postgres-best-practices** | A database performance reviewer — indexing, query plans, RLS that doesn't tank speed, connection pooling. | Before you finalise *any* migration or a query on a hot path (jobs feed, messages). Directly serves the "every query has an index" rule + 25k-user scale target. |

**Why PROJECT not GLOBAL:** they encode *Jobdun's* backend; they must bind CI and a
future teammate, and must NOT fire on unrelated non-Supabase projects.

---

## 2. GLOBAL scope — machine-wide (`~/.claude/`), every project you open

### 2.1 `superpowers@superpowers-marketplace` v5.1.0 — 14 skills, process discipline

The backbone. These decide *how* work is approached and outrank implementation skills
(process before code). Let them fire automatically; don't skip because a task "feels simple".

| Skill | What it is (layman) | Use it in Jobdun when… |
|-------|---------------------|------------------------|
| **brainstorming** | Interview-before-build. Pins down intent + requirements before any code. | The MUST-FIRST step for any new feature/screen/behaviour change. |
| **writing-plans** | Turns a spec into a numbered, reviewable plan. | After brainstorming, before touching a multi-step task. |
| **executing-plans** | Runs a written plan with checkpoints. | Working through a plan file in a fresh session. |
| **subagent-driven-development** | Splits a plan's independent tasks across helper agents in one session. | A plan has chunks that don't depend on each other. |
| **dispatching-parallel-agents** | Fan-out: 2+ fully independent tasks at once. | E.g. "audit RLS" + "refactor theme" — no shared state. |
| **test-driven-development** | Rigid: failing test → code → green. Follow exactly. | Before writing *any* feature or bugfix code. |
| **systematic-debugging** | Root-cause method, not symptom patching. | Any bug, test failure, or "why is this weird". |
| **verification-before-completion** | Forces you to run the check and quote output before saying "done". | Before every "fixed/works/passing" claim, commit, or PR. Pairs with `bash scripts/validate.sh`. |
| **requesting-code-review** | Structured self-review against requirements. | Finishing a feature / before merge. |
| **receiving-code-review** | How to act on review feedback with rigour (not blind agreement). | When you get review comments to apply. |
| **using-git-worktrees** | Isolated workspace for feature work. | Starting feature work that shouldn't touch your current tree. |
| **finishing-a-development-branch** | Decide merge vs PR vs cleanup. | Work is done and tested — what now. |
| **writing-skills** | Authoring/editing skills properly. | Building the gap skills (AU Privacy Act, RLS-author) — see §6. |
| **using-superpowers** | Bootstraps the skill-first workflow each session. | Automatic at session start; you don't call it. |

### 2.2 `example-skills@anthropic-agent-skills` — Anthropic official, Apache-2.0 (17 skills)

⚠️ **This set is now byte-identical to `document-skills` (§2.3)** — pure duplication.

| Skill | What it is (layman) | Jobdun fit |
|-------|---------------------|------------|
| **skill-creator** | Anthropic's scaffold/validator for new skills. | ✅ Use when authoring the custom Jobdun skills (RLS-author, privacy-act-au). Overlaps `superpowers:writing-skills` — prefer that for discipline, this for the scaffold. |
| **mcp-builder** | Guide to build an MCP server (lets Claude talk to an external service). | 🟡 Only if/when you build a live Supabase MCP — Phase 2+, not now. |
| **claude-api** | Build/debug apps that call the Claude API (with prompt caching). | 🟡 Only if Jobdun ever adds a Claude-powered feature. Not used today. |
| **frontend-design** | Web UI (HTML/React) design quality. | ❌ Web-oriented. Jobdun is Flutter — `ui-ux-pro-max` is your real design skill. |
| **brand-guidelines** | Applies Anthropic's brand look. | ❌ It's *Anthropic's* brand, not Jobdun's. Ignore. |
| **webapp-testing** | Playwright browser testing. | ❌ Not applicable to a Flutter mobile app. |
| **pdf** | Read/fill/merge/split PDFs. | 🟡 Maybe later for AU privacy/retention paperwork or verification docs. Not now. |
| **docx / pptx / xlsx** | Generate Word/PowerPoint/Excel files. | 🟡 Only for one-off compliance/report exports. Minor. |
| **doc-coauthoring** | Structured workflow for writing docs/specs. | 🟡 Handy for writing `docs/` proposals & specs. |
| **internal-comms** | Status reports, leadership updates, FAQs. | 🟡 Optional — only if you write formal status comms. |
| **theme-factory** | Themes for slides/HTML artifacts. | ❌ Artifact styling, not Flutter. Ignore. |
| **canvas-design / algorithmic-art / slack-gif-creator / web-artifacts-builder** | Posters, generative art, Slack GIFs, fancy HTML artifacts. | ❌ Not relevant to this codebase. Ignore. |

### 2.3 `document-skills@anthropic-agent-skills` — same 17 skills as §2.2

Source-available (NOT open source) — **read the license before commercial reliance**
(matters for `pdf`/office output you ship to customers). Functionally a duplicate of
`example-skills`; keep one, mentally ignore the other. Same Jobdun fit as §2.2.

### 2.4 `vercel@claude-plugins-official` v0.43.0 — ~26 skills — LARGELY IRRELEVANT

**Jobdun is Flutter + Supabase, not Next.js/Vercel.** This plugin was pulled in as a
default. Treat the whole thing as background noise; **do not invoke**. The only
conceivable use is a *separate* future admin web app on Next.js/Vercel — not this repo.

Skills (one-liners, all ❌ for the Flutter app unless noted): `ai-sdk`, `ai-gateway`,
`nextjs`, `next-cache-components`, `next-forge`, `next-upgrade`, `react-best-practices`,
`shadcn`, `turbopack`, `routing-middleware`, `runtime-cache`, `vercel-functions`,
`vercel-storage`, `vercel-cli`, `vercel-sandbox`, `vercel-agent`, `vercel-firewall`
(new in 0.43.0), `auth`, `env-vars`, `bootstrap`, `marketplace`, `chat-sdk`,
`deployments-cicd`, `verification`, `workflow`, `knowledge-update`.
Plus internal plugin-dev skills (`benchmark-*`, `release`, `plugin-audit`,
`vercel-plugin-eval`) — Vercel's own tooling, **not for you at all**.

🟡 Single faint maybe: **chat-sdk** *if* you ever build a Slack/Telegram bot around
Jobdun — out of scope today.

---

## 3. BUNDLED — ships with Claude Code, always available (invoke with `/name`)

| Command | What it does (layman) | Use it in Jobdun when… |
|---------|-----------------------|------------------------|
| **/security-review** | Security scan of the uncommitted diff on your branch. | Before any PR touching auth, RLS, or PII. |
| **/review** | Reviews a pull request. | Reviewing a teammate's / your own PR. |
| **/init** | (Re)generates `CLAUDE.md` from the codebase. | After big structural changes. |
| **/simplify** | Finds reuse/quality issues in changed code, then fixes. | After a messy implementation, before review. |
| **/loop** | Repeats a prompt/command on an interval. | Polling a deploy or watching CI. |
| **/schedule** | Cron-style recurring remote agent. | Recurring automated task (rarely needed here). |
| **/claude-api** | Build against the Claude/Anthropic API. | Not used in Jobdun yet. |
| **/update-config**, **/keybindings-help**, **/fewer-permission-prompts** | Harness/settings tooling. | Tweaking Claude Code itself, not the app. |

---

## 4. The "regenerate the full list" prompt (copy-paste)

> Regenerate the skill inventory for this repo. Run all of these and show the results:
> 1. `ls -1 .claude/skills` — project manual skills
> 2. `cat .claude/settings.json` — project-scoped plugins
> 3. `ls -1 ~/.claude/skills` — global manual skills
> 4. `claude plugin list` — all installed plugins + scope
> 5. `find ~/.claude/plugins/cache -name SKILL.md | sed -E 's#.*/plugins/cache/##; s#/SKILL.md##' | sort -u` — **every** skill in **every** plugin
>
> Then rewrite `docs/CLAUDE_SKILLS.md` with today's snapshot date, keeping the
> PROJECT / GLOBAL / BUNDLED structure, the plain-English columns, and §5 redundancies.

---

## 5. Redundancies & cautions (be deliberate)

- **`ui-ux-pro-max` installed twice** — identical in `./.claude/skills/` AND
  `~/.claude/skills/`. Project copy wins for Jobdun; global copy is dead weight.
  Remove `~/.claude/skills/ui-ux-pro-max` if you want one source of truth.
- **Supabase ships as two plugins, each bundling both skills** — `supabase@…` and
  `postgres-best-practices@…` from `supabase-agent-skills` both contain `supabase` +
  `supabase-postgres-best-practices`. Harmless (same content) but you only conceptually
  need one entry per skill.
- **`example-skills` ≈ `document-skills`** — now the same 17 skills. Pure duplication;
  pick one mentally and ignore the other. Both are global noise except `skill-creator`.
- **Vercel cache holds 3 versions** (`0.40.1`, `0.42.1`, `0.43.0`) — only `0.43.0` is
  live; the others are disk bloat in `~/.claude/plugins/cache`. Safe to leave.
- **`skill-creator` vs `superpowers:writing-skills`** — overlapping. Prefer
  `superpowers:writing-skills` for discipline; `skill-creator` only for the scaffold.
- **Community `security-review` NOT installed** — bundled `/security-review` covers it.
- **`frontend-design` / `webapp-testing` do not fit Flutter** — never let them drive
  mobile UI/testing; `ui-ux-pro-max` owns that.
- **Context-window cost** — every enabled skill's description loads at session start.
  The Vercel suite is the biggest unwanted tax; leave it but never invoke it.

---

## 6. Gaps — no skill covers these Jobdun needs (author them)

Per `docs/NEXT_STEPS.md`, nothing covers: **AU Privacy Act 1988 / APPs**, **Jobdun
RLS-policy authoring conventions**, **feature scaffolding**, or **migration
conventions**. Build these with `skill-creator` / `superpowers:writing-skills` when
ready — they'd belong in `./.claude/skills/` (PROJECT scope, committed).

---

## 7. Regenerate this inventory

```bash
ls -1 .claude/skills                 # project manual skills
cat .claude/settings.json            # project-scoped plugins (enabledPlugins)
ls -1 ~/.claude/skills               # global manual skills
claude plugin list                   # all installed plugins + scope

# Every skill in every plugin, one sweep (no per-marketplace filter):
find ~/.claude/plugins/cache -name SKILL.md \
  | sed -E 's#.*/plugins/cache/##; s#/SKILL.md##' | sort -u
```
