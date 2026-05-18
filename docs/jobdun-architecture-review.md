# Jobdun — Setup & Architecture Review (for second-opinion AI)

> Self-contained briefing. Paste this whole file into another AI and ask:
> "Is this the right setup for this product, and what would you change?"
> Written deliberately to include weaknesses, not just strengths.

## 1. What Jobdun is

Mobile-first job-matching / workforce app for the Australian construction
trades. Two in-app roles: **Builders** (post jobs, manage applicants) and
**Trades/Crews** (find jobs, apply, upload verification). Admin is a
**separate web app** — the Flutter app has no admin UI. Pre-launch.

## 2. Current stack (factual)

| Layer | Choice |
|---|---|
| Client | Flutter (Dart 3.11.5), Android + iOS |
| Backend | Supabase — Postgres, Auth, Storage, Realtime, RLS, Edge Functions |
| State | Riverpod (Notifier/NotifierProvider) |
| Routing | GoRouter, `StatefulShellRoute.indexedStack` (5-branch bottom nav) |
| Arch | Feature-first Clean Architecture: each feature has `data/` `domain/` `presentation/`; domain has no Flutter/Supabase imports; only data talks to Supabase |
| Auth/role | Role from JWT claim, DB fallback; RLS on all tables |
| Design system | Token files (`AppIconSize`, `AppTouchTarget`, `AppSpacing`, `AppRadius`, `AppSelection`, `AppNavBar`, `JColors` theme extension), `ui-ux-pro-max` skill + `design-system/jobdun/MASTER.md`, grep guards in `scripts/validate.sh` + CI |
| Icons | `flutter_tabler_icons` behind an `AppIcons` semantic catalogue |
| Tests | `flutter_test` + `mocktail`; ~106 unit/widget tests; no integration/E2E |

## 3. Implementation state — the honest part

A meaningful share of the "trade app" is **UI built ahead of backend**, by
explicit decision, with honest placeholders (no faked data):

- **Real today:** auth, profile, jobs CRUD, full-text job search (Postgres
  `tsvector` + GIN), trade/budget/start-date filters, real `.range()`
  pagination, labelled adaptive bottom nav, standardized 44/48 touch targets.
- **Deferred (no backend, shown as honest "coming soon"):** PostGIS distance
  / "nearest" sort, relevance (`ts_rank`) sort, `saved_jobs` table (heart
  toggle), applications realtime, map view + marker clustering, the Builder-
  side UI rollout, "new matches" scoring.
- **Known debt:** `HomePage` and `JobsPage` are single widgets role-branched
  (builder vs trade) — getting complex; a clean role-split was deferred.
  Tests are unit/widget only (the screens are deeply Supabase-coupled, so no
  integration coverage). Design-token discipline drifted historically and was
  re-standardized this cycle (now guarded in CI).

## 4. My assessment — is this the best setup?

**For an MVP at this stage: yes, mostly — with caveats.**

Strengths
- Flutter + Supabase is a strong, cheap, fast MVP combo for a 2-sided
  mobile marketplace; RLS-everywhere is the right security posture.
- Feature-first Clean Architecture + a domain layer with no framework
  imports is sound and testable.
- Token-driven design system + automated grep guards is unusually
  disciplined for this stage and is paying off (touch-target/icon
  consistency, accessibility).

Risks / things a second opinion should pressure-test
1. **Clean Architecture overhead vs team size.** Three layers per feature is
   a lot of boilerplate for a small team racing to launch. Is the
   domain/usecase indirection earning its cost, or would a lighter
   data→provider→UI shape ship faster?
2. **Role-branched mega-screens.** `HomePage`/`JobsPage` doing
   `isBuilder ? … : …` is a smell. Builder vs Trade likely warrant separate
   widget trees (or even separate routed shells) before more divergence.
3. **UI-ahead-of-backend.** Several headline features are placeholders. Risk
   of demoing/shipping perceived completeness; needs a hard "T-backend"
   phase (PostGIS + geolocation, `saved_jobs`+RLS, realtime, `ts_rank`).
4. **Testing depth.** No integration/E2E and screens are Supabase-coupled →
   real regressions can pass CI. Consider a thin repository seam + fake
   Supabase, or `patrol`/integration tests for critical flows.
5. **Supabase ceiling.** Fine now; revisit if matching logic gets heavy
   (Edge Functions vs DB functions vs a real search/geo service).
6. **`.h`/`.r` responsive units on chrome.** Recurring bug source — fixed
   chrome (nav bar, touch targets) must be fixed dp, not screen-scaled.
   Mostly corrected; worth a lint/guard so it can't regress.

## 5. Questions to ask the second-opinion AI

1. Is full Clean Architecture justified here, or is it premature
   abstraction for a pre-launch 2-sided marketplace?
2. Builder vs Trade: branch one screen, or split into two shells/widget
   trees? At what point does the split pay off?
3. Is Supabase the right backend through ~v1, given PostGIS distance
   matching, realtime, and full-text relevance are core to the product?
4. Minimum viable test strategy to make CI trustworthy without a huge
   harness investment (the screens are Supabase-coupled)?
5. Sequencing: keep building UI with honest stubs, or stop and land the
   deferred backend now so features are real before launch?
6. Any structural risk in `StatefulShellRoute.indexedStack` for a
   role-divergent 2-sided app?
