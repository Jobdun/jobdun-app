# Page Override — Applications

> **LOGIC:** This file **overrides** `../MASTER.md` for the applications surface.
> Anything not stated here inherits MASTER. When this doc and the code disagree,
> **code wins** (see MASTER → *Sources of Truth*).

**Updated:** 2026-06-04 — first override for this surface. Codifies the status
system, card/row anatomy, and the Material-3 modernization targets after a
`ui-ux-pro-max` audit of the three live screens. The P0+P1 modernization pass
**shipped the same day** (see *Material-3 targets* below for ✅/◻ status).

---

## Scope — this is three screens, one mental model

| Screen | File | Role | Job |
|--------|------|------|-----|
| **Status / Applicants tab** | `applications_page.dart` (+ `_card`, `_widgets`) | Trade: *"Track status"* · Builder: *"Applicants"* | Filterable list of every application that touches me |
| **Job → Applicants** | `job_applicants_page.dart` (+ `_widgets`) | Builder | One job's applicants, verified-first, with verified-only toggle |
| **Applicant detail** | `applicant_detail_page.dart` (+ `_widgets`) | Builder | One tradie: identity, verification, quote, stats, decide |

The unifying idea: **a pipeline of status**. Every surface answers "where does this
stand, and what do I do next?" Status is the spine — it drives colour, ordering,
and which action leads.

---

## Status system (the spine — do not reinvent per screen)

Application lifecycle: `Pending → Shortlisted → Accepted(Hired) / Rejected / Withdrawn / DeclinedByTrade`.

**Every status is dual-encoded — colour + label, never colour alone** (MASTER a11y).
The card carries a 3px top **status strip** *and* a tinted **status chip**; keep both.

| Status | Strip / accent | Chip pair | Meaning |
|--------|----------------|-----------|---------|
| Pending | `c.warning` (amber) | `warningBg`/`warningTx` | Awaiting a decision — **amber, not orange, not red** |
| Shortlisted | `c.available` (blue) | `availableBg`/`availableTx` | In the running |
| Hired/Accepted | `c.verified` (green) | `verifiedBg`/`verifiedTx` | Won |
| Rejected | `c.urgent` (red) | `urgentBg`/`urgentTx` | Closed — declined |
| Withdrawn / DeclinedByTrade | `c.surfaceRaised` + `c.text1` | neutral terminal | Closed — neutral |

Rules:
- **Pending = amber `c.warning`.** It is a *caution*, not an error and not a CTA.
  Never red, never brand orange (MASTER → Colour Rules: *Caution ≠ error*).
- Status chips use the semantic `*Bg`/`*Tx` pairs only — never
  `colour.withValues(alpha:…)` + same-colour text (lands below AA).
- A **shortlisted** card gets a 1.5px `c.action` border — the one place orange
  frames a *row*, because shortlisting is the builder's active decision lane.
- Chip + strip colour logic is duplicated across `_card` and `_widgets` today.
  When touched, lift `statusStrip()` / `statusChip()` into one shared helper so the
  three screens can never drift.

---

## Filter chips (the tab row)

The status tabs are **filter chips** (`GvChip`), horizontally scrollable — this is
correct M3 behaviour, keep it. Tighten it:

- **Show counts.** Modern pipelines label the filter, e.g. `Pending · 3`,
  `Shortlisted · 1`. A bare `Pending` makes the user tap to discover an empty bucket.
  Counts come from the full (pre-filter) list the controller already holds.
- Active chip must be **dual-encoded** — filled `c.action` *and* a weight/label shift,
  never fill-colour alone (a11y; verify `GvChip` already does this).
- Filters stay **visible** — never collapse status filters behind a funnel icon
  (`ui-ux-pro-max` anti-pattern: *hidden filters*).
- The verified-only control belongs on the same shelf as the filters, not buried.
  Use the shared **`JSwitch`** on *all three* screens (the global tab still uses a
  raw `Switch` — unify it).

---

## Card & row anatomy

**Status card** (`_AppCard`) — the dense, action-bearing row:
`status strip → [chip · relative-date] → job title (titleLarge) → counterparty
(+ verified tick) → location → pricing line (budget vs quote, display-only) →
contextual actions`.

**Applicant row** (`_ApplicantRow`) — the scannable people row:
`avatar(initials) → name (+verified tick) → trade · quote → status chip → chevron`.

Anatomy rules:
- **Pricing is display-only.** "Budget $X · Quote $Y" is never ranked, sorted, or
  auto-compared. Keep the wording neutral ("vs your $X budget").
- **Action hierarchy is status-driven**, not fixed:
  - Pending (builder): `REJECT` (secondary) · `SHORTLIST` (primary) + `MESSAGE`.
  - Shortlisted (builder): `HIRE` leads (filled) · `MESSAGE` · `REJECT`.
  - Terminal: `MESSAGE` only.
  - Pending (trade): a quiet underlined `Withdraw`.
- One filled CTA per context. Destructive (`REJECT`) is secondary, never a bare
  red button competing with the primary.
- **Swipe is additive, not a replacement** — slidable reject/shortlist/withdraw on
  *pending* rows only, with `HapticFeedback.lightImpact()` inside every action
  (MASTER). Inline buttons stay for discoverability.
- **HIRE on green is dark `c.onAction`**, never white (white-on-green = 2.28:1, fails).

---

## Loading & empty states

- **Loading:** `JSkeletonList` wrapping a real-shaped placeholder card/row — keep.
  Never a spinner for the page body.
- **Empty:** MASTER spec is *animation + bold headline + single filled CTA*. Make
  the two empty states **consistent**:
  - Global tab `_EmptyTab` — `AnimatedEmptyGlyph` + headline + CTA (CTA on the
    "All" tab only). ⚠️ Fix the dead ternary `context.go(isBuilder ? '/jobs' : '/jobs')`
    — both branches go to `/jobs`; the builder CTA should land on **`/jobs/create`**.
  - Per-job `_EmptyApplicants` — currently a static icon + text with **no CTA and
    no motion**. Bring it up to the same `AnimatedEmptyGlyph` + headline pattern.
- **"Hidden by filter" ≠ "empty".** The verified-only "N hidden — SHOW ALL"
  notice is the right call — never let an active filter masquerade as zero results.

---

## Motion

- Inherits MASTER: list entrances via `JStaggeredList` (200ms fade-slide, respects
  reduced-motion); micro-interactions via `flutter_animate`; 150–200ms, no spring.
- **Add a `Hero`** on the applicant avatar from `_ApplicantRow` → `_DetailHeader`
  (`tag: 'applicant:${app.id}'`) so row→detail flows (MASTER image-viewer convention,
  applied to the avatar).
- Status changes (shortlist/hire/reject) should animate the row's chip/strip colour
  over 150–200ms rather than hard-cutting.

---

## Material-3 / Google-standards modernization targets

The "make it more modern" deltas — Material 3 + Google mobile guidance, on top of
an already-solid base. P0+P1 **shipped 2026-06-04**:

1. ✅ **Tap feedback everywhere.** `GestureDetector` taps replaced with
   `Material` + `InkWell` (M3 state-layer ripple) + `Semantics(button: true)`:
   `_ApplicantRow`, the "HIRE THIS TRADIE" tile, the trade `Withdraw` link,
   "SHOW ALL APPLICANTS".
2. ✅ **48dp touch targets.** The HIRE tile is now `minHeight: 48`; the text links
   are padded into a ≥48dp hit area.
3. ✅ **Lazy lists.** `job_applicants_page` moved from `SingleChildScrollView` +
   `...map` to a `CustomScrollView` + `SliverList.builder` (summary/count in a
   `SliverToBoxAdapter`). Flutter guideline: `ListView.builder` over
   `ListView(children:)` (severity: High).
4. ✅ **Pull-to-refresh.** All three screens wrap a `RefreshIndicator`
   (`AlwaysScrollableScrollPhysics` so short lists still pull) → controller reload
   / provider invalidate.
5. ◻ **Scroll-aware headers (P2, deferred).** The static `Container(color: c.card)`
   headers can still become M3 scroll-behaviour app bars (pinned, divider/elevation
   on scroll) now that the screens are sliver-based.
6. ✅ **Load in `build()`, not `initState`.** Both pages' `addPostFrameCallback`
   load triggers were deleted; the shared `ApplicationsController.build()` now
   kicks off the role-appropriate load (`Future.microtask`) and reloads on account
   change — one load serves all three screens.

Also shipped (P1): per-status **chip counts** (`Pending · 3`), the **Hero**
avatar (row → detail), unified **`JSwitch`**, consistent **empty states**, the
`/jobs/create` empty-CTA fix, and extra **bottom clearance** (`AppSpacing.xl +
viewPadding.bottom`) so the last row/field always clears the nav + home indicator.

Still open: P2 scroll-aware app bars; the availability-calendar TODO in
`applicant_detail`; `infinite_scroll_pagination` is **not** wired — applicant
counts are small today, so revisit only if a single job's list can exceed ~50.

---

## Anti-patterns (this surface)

- ❌ Orange or red for a **Pending** status — it's amber `c.warning`.
- ❌ Ranking/sorting applicants by quote, or auto-flagging "cheapest". Display only.
- ❌ Hiding status filters behind an icon — filters stay visible.
- ❌ `GestureDetector` with no ripple / no semantics for a primary action.
- ❌ Touch targets < 48dp on Hire / Withdraw / Show-all.
- ❌ Eager `Column(children: list.map(...))` for an unbounded applicant list.
- ❌ A second empty-state style — the two empties must match.
- ❌ White text on the green HIRE tile (fails contrast) — dark `c.onAction`.

---

## Page checklist (in addition to MASTER's)

- [ ] Pending = amber; every status chip uses a semantic `*Bg`/`*Tx` pair
- [ ] Status dual-encoded (strip + chip), never colour alone
- [ ] Filter chips show per-status counts; active chip dual-encoded; filters visible
- [ ] `JSwitch` (not raw `Switch`) for verified-only on all three screens
- [ ] Every tappable surface = `InkWell`/`JButton` with ripple + `Semantics`, ≥48dp
- [ ] Applicant list is sliver/`ListView.builder`, not eager `map`
- [ ] Each list wrapped in `RefreshIndicator`
- [ ] Both empty states share the `AnimatedEmptyGlyph` + headline (+ CTA) pattern
- [ ] Builder empty CTA routes to `/jobs/create`, not `/jobs`
- [ ] Initial load lives in the notifier's `build()`, not `initState`
- [ ] Hero on the applicant avatar (row → detail)
- [ ] HIRE/green foregrounds are dark `c.onAction`
