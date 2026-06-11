# Account-Sheet Navigation (Option A) — Design Spec

> **Date:** 2026-06-10 · **Status:** direction approved by user (picked A of 3); spec awaiting review
> **Problem (from nav audit):** the home top-bar avatar and the bottom-nav Profile tab both open
> `/profile` (pure duplication); Settings is a 36 px gear buried two levels deep inside the profile
> header; the Profile tab mixes public credibility with account plumbing; and the thumb row spends
> one of five slots on a destination used ~weekly.
> **Pattern:** M3 account-sheet canon (Gmail/Maps avatar → account surface), the direction LinkedIn
> is moving; deliberately NOT the SEEK/Indeed "Profile = 5th tab" default — parity isn't the goal.

## Design

### 1. Bottom nav → 4 all-work tabs

`TabSpec.forRole` drops the Profile entry for both roles:

- Trade: **Home · Find · Applied · Messages**
- Builder: **Home · My Jobs · Applicants · Messages**

The freed 5th slot is **reserved for a future SCHEDULE tab** (availability calendar + timesheets,
already built as pages) — explicitly out of scope for this change; do not add it now (YAGNI), but
don't design anything that blocks it.

### 2. Avatar = the account entry point, on every root tab

- The home `JTopBar` avatar stays; its tap changes from `context.go('/profile')` to **opening the
  account sheet**.
- New shared widget `JAvatarAction` (40 dp avatar + completeness ring) added as a trailing action
  to the app bars of the other root tabs (Find/My Jobs, Applied/Applicants, Messages), so account
  access never requires switching to Home first.
- **Completeness ring:** a `CircularPercentIndicator`-style ring around the avatar driven by the
  same percentage as `ProfileCompletenessBanner`; hidden at 100%. This replaces "the Profile tab
  badge" as the onboarding nudge.

### 3. The account sheet (`showJSheet`)

Opens from any avatar tap. Content, top to bottom:

```
◉  Ken Garcia                      ← avatar 48dp, name titleLarge
   Carpenter · Penrith             ← bodyMedium text2; role chip TRADIE
   [✓LICENCE] [✓WHITE CARD] [⊕INSURED]   ← TrustChip strip (reuse U3 preview logic)
──────────────────────────────────
▸ My profile                       → push /profile
▸ Credentials          2 OF 3      → push /verification/wizard
▸ Edit profile                     → push /profile/edit
▸ Availability calendar            → push existing route        (trade only)
▸ Settings                         → push /settings
▸ Notification settings            → push /settings/notifications
──────────────────────────────────
▸ Sign out                         → confirm dialog, then sign out
```

- Rows are ≥48 dp list rows (AppIcons leading, chevron trailing), Oswald row labels per house style.
- Sign out keeps the existing confirmation flow.
- The sheet is the ONLY place account plumbing lives; the profile page keeps its content focus
  (credibility: identity, stats, receipts, portfolio, reviews). The gear icon on the profile page
  header may remain as a secondary affordance — it no longer needs to carry the whole load.

### 4. Routing changes

- Remove the profile branch from `StatefulShellRoute`; `/profile` (+ `/profile/edit`,
  `/profile/verify-phone`, etc.) become top-level routes pushed above the shell, with a back arrow.
- Audit every `context.go('/profile')` / branch-index assumption (swipe gesture indices shift
  automatically with `tabs.length`; notification deep links and FTUE gates need a grep).

### 5. Friction rationale (AU tradie lens)

- Bottom sheet = thumb-reachable; rows are large targets (gloves).
- Every bottom-nav slot is now a daily-work surface.
- Settings goes from 2-taps-deep-behind-a-36px-gear to one avatar tap + one row.

## Out of scope

- SCHEDULE tab itself (future; slot reserved).
- Any change to tab page content, the bell/notifications entry, or admin web.

## Tests

- `TabSpec.forRole` returns 4 tabs for both roles (update existing shell tests).
- Avatar tap opens the sheet (widget test); each row navigates to its route.
- Completeness ring hidden at 100%, shown below.
- Router: `/profile` reachable as pushed route with back; no dead `go('/profile')` callers.

## Research trail

M3 NavigationBar/Drawer guidance via Flutter docs (Context7); ui-ux-pro-max UX DB (nav/touch
rules); LinkedIn top-bar consolidation experiments; bottom-nav 3–5 destination convention.
Sources: [Social Media Today — LinkedIn nav experiment](https://www.socialmediatoday.com/news/linkedins-experimenting-updated-top-navigation-bar/731297/),
[UX Planet — bottom tab bar best practices](https://uxplanet.org/bottom-tab-bar-navigation-design-best-practices-48d46a3b0c36),
[Tapcart — bottom navigation UX](https://www.tapcart.com/blog/bottom-navigation-ux).
