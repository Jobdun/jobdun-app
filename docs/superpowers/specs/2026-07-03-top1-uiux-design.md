# Spec — Jobdun First-Run: Roadmap to #1 in the AU Trades Market

**Date:** 2026-07-03
**Companion:** `docs/UIUX_MARKET_AUDIT_2026-07-03.md` (evidence, scorecards, competitor matrix).
**Status:** DRAFT for user review. Phase-4 brainstorm (the interactive "what does #1 mean to you" pass) is **deferred to the user's return** — this spec proposes a recommended thesis + a set of decisions awaiting sign-off, rather than blocking. No implementation until approved.

---

## Thesis (recommended)

Jobdun already wins on **craft, voice, and identity** — the things competitors can't fake and that take longest to build. It loses on **one structural posture (auth-first) and a set of fixable frictions.** The path to #1 is therefore *not* a redesign — it's:

> **Keep the identity. Tear down the signup wall. Ship the scoped accessibility + friction fixes. Plant a flag on verification-first trust while the market's vacated it.**

Proposed **north-star for the first-run flow:** *time-to-first-real-job-seen* for a new trade (today: infinite until signup; target: < 30s, no account). Secondary: signup-completion rate and D1 return.

---

## Roadmap (top 10, ranked by new-user impact × effort)

Each item: screen · change · rationale (audit evidence) · design-system compliance · size class.
Size: **QW** ≤1 day · **S** structural · **PD** needs product decision.

### 1. Browse-before-signup — guest mode for trades  · **S + PD**
- **Screen:** FTUE slide 3 → new public jobs feed → Home.
- **Change:** add a third path off slide 3 ("BROWSE JOBS FIRST") into a read-only real jobs feed. Gate only apply/save/message behind the account. On first apply, route into the existing `/register?role=trade`.
- **Rationale:** the audit's #1 finding. Every AU competitor (Airtasker, Jora, Indeed, SEEK, ServiceSeeking) allows browse-before-signup; Jobdun gates 100%. Deferred signup ≈ +20% DAU (Duolingo). NN/g: login walls defy reciprocity.
- **Design-system:** reuse `JobCard` + the jobs feed; dark tokens; no new patterns. Anonymous feed reads the same server jobs-feed cache.
- **Decision required (see below):** what an anon user sees.

### 2. Defer the notification-permission prompt  · **QW**
- **Screen:** currently FTUE slide 1.
- **Change:** stop requesting iOS/Android notification permission on FTUE mount. Request after the first meaningful action (first apply, or first Home visit with real jobs) using a pre-permission priming screen ("Get pinged when a builder replies — allow notifications?").
- **Rationale:** confirmed firing on slide 1 across two launches (`docs/verification/2026-07-03-ios-03-*.png`). iOS HIG + NN/g: defer the OS prompt until context justifies it. Grant rates collapse when asked pre-value.
- **Design-system:** priming sheet via `showJSheet`; dark surface; "ALLOW NOTIFICATIONS" filled CTA + "NOT NOW" text.

### 3. Make slide 2's job count real (or reword)  · **QW**
- **Screen:** FTUE slide 2 (`slide_two_speed.dart:95`).
- **Change:** replace hardcoded "100+ active jobs within 15km" with the live count for the resolved area, or soften to a non-numeric promise when the count is unknown/low.
- **Rationale:** a hardcoded promise that an empty Home breaks = the "fake leads" trust break that sinks Oneflare/ServiceSeeking in reviews.
- **Design-system:** reuse the geo provider already feeding slide 2; keep tabular figures (`AppTypography.numeric()`).

### 4. Social proof at the auth CTA  · **QW**
- **Screen:** register form step + login (`register_page_form_step.dart`, `login_page.dart`).
- **Change:** a single live trust line near CREATE ACCOUNT / LOG IN — e.g. "2,400+ verified tradies on the tools" or recent-activity ("14 jobs posted in NSW today").
- **Rationale:** research — third-party social proof near auth/lead forms lifts conversion; it's absent at Jobdun's highest-friction moment. Counters the "is anyone even here?" cold-start doubt.
- **Design-system:** `bodySmall` + `c.text2`; verified tick via `AppIcons`; no color-only encoding.

### 5. Relax the password rule to length-based  · **QW + PD**
- **Screen:** register form (`register_page_form_step.dart:287–299`).
- **Change:** drop the mandatory uppercase/digit/symbol composition; require length (≥8–10). Keep the strength meter as *guidance*, not a gate.
- **Rationale:** NIST 800-63B advises against composition rules (hurt completion, don't improve real security). Baymard: every rule must fight for its life; 26% abandon over-long/complex flows. Symbol-on-phone-on-site is a known killer.
- **Design-system:** no visual change; keep `_PasswordStrengthBar`.
- **Decision required:** confirm the security-posture change is acceptable.

### 6. Fix the Home empty state  · **QW**
- **Screen:** `_HomeJobsEmpty` (`home_widgets.dart:10–52`).
- **Change:** add a filled CTA ("BROWSE ALL JOBS" → `/jobs`, or "EXPAND RADIUS →") + a Lottie, per MASTER §313. Reword the passive body.
- **Rationale:** currently icon + two lines, no CTA — a dead-end violating the house empty-state rule. A new tradie in a quiet area has nothing to do.
- **Design-system:** MASTER §313 (Lottie + headline + single filled CTA); `JButton`.

### 7. Ship the scoped AA contrast fixes (first-run screens)  · **QW**
- **Screen:** register / login fields; role cards.
- **Change:** `text3 → #8B98AB` (5.0:1) for input labels/placeholders/hints; add `borderStrong #708096` (3.63:1) for resting input/card borders; selected role icon → dark `onAction` (#0F172A) instead of white.
- **Rationale:** inherited P1s (`DESIGN_SYSTEM_AUDIT §5`, `SUGGESTIONS S1-TEXT3/S2-BORDER`) that land on the exact first screens; also the outdoor-legibility fix (dark UI in sunlight needs max contrast). Placeholders are content → 4.5:1.
- **Design-system:** update `app_colors.dart` tokens + guard pairs in `test/colors_contrast_test.dart` (coverage test fails on unguarded tokens). Not new debt — already scoped.

### 8. Trim FTUE slide 3 to one decision  · **QW**
- **Screen:** `slide_three_action.dart:81–151`.
- **Change:** the two role CTAs are the hero; demote "Continue with Google" + "I already have an account · LOG IN" to a single quiet line below the fold.
- **Rationale:** 4 visible options at one decision point exceeds the ≤4 cognitive-load rule and dilutes the one real decision (role). Also realigns SSO with `auth-onboarding.md` ("SSO demoted to tertiary").
- **Design-system:** `auth-onboarding.md` SSO rule; keep `RoleIntentCta`.

### 9. Readiness-driven splash handoff  · **QW**
- **Screen:** `splash_page.dart:29`.
- **Change:** advance as soon as auth + FTUE-gate state is loaded, capped at ~900ms — not a blind `Timer`.
- **Rationale:** the fixed timer taxes every cold start regardless of readiness.
- **Design-system:** no visual change; keep the logo animation + loading bar.

### 10. Own verification-first trust  · **S**
- **Screen:** FTUE + first jobs feed / job cards.
- **Change:** a "how we verify" micro-explainer in FTUE (licence + ABN + insurance, with real proof) and verified badges surfaced in the first feed, wired to the existing verification subsystem.
- **Rationale:** Oneflare (the verification-first incumbent) retired 30 Jun 2026 — that position is unowned, and verification is Jobdun's premise. Turn a claim ("ONLY VERIFIED") into visible proof (Uber-style trust surfacing; Airbnb badge economics).
- **Design-system:** verified tick via `AppIcons` (Fill weight for active/critical); never color-alone; tinted `*Bg`/`*Tx` pairs for badges.

**Sequencing suggestion:** ship 2–9 (mostly QW, independent, no product blocker) as a first "friction + a11y + trust polish" sprint; run the Phase-4 brainstorm on #1 and #10 (the structural + strategic pair) in parallel, then build them.

---

## Decisions awaiting the user (Phase-4 brainstorm on return)

1. **Anonymous-visibility scope (blocks #1).** What can a not-signed-in trade see? Options: (a) full job list + full detail, apply gated; (b) list + detail but poster identity/contact masked; (c) list only, detail gated. Has RLS + backend implications (anon read policy on `jobs`). *Recommend (b)* — maximum browse value, identity protected.
2. **North-star metric.** Confirm *time-to-first-real-job-seen* (trades) as primary, or weight toward *time-to-first-job-post* (builders) / D7 return. Shapes what we instrument.
3. **Password-posture change (#5).** OK to drop composition rules for length-based? Reverses a current security choice.
4. **"#1" definition.** Store rating, activation rate, or word-of-mouth-on-site — determines which lever we optimise hardest.

---

## Compliance guardrails (all items)

- Locked tokens: dark slate `#0F172A`, surface `#1E293B`, safety orange `#F97316`, Archivo (display/heading/button) + Inter (body). Aggressive-flat: no gradients (except the sanctioned `brandFlame` wordmark), no shadows, no ghost buttons, ALL-CAPS button text, dark `onAction` on orange.
- WCAG 2.2 AA enforced by `test/colors_contrast_test.dart`; 48dp touch targets; dynamic-type clamp; reduced-motion branches.
- Aussie register throughout; no soft-welcome copy.
- Do **not** re-open settled debts as new (CTA button contrast already fixed to dark `onAction`; type-scale is now Archivo/Inter, verified in `app_typography.dart` — the "Oswald/Open Sans" in older docs is the admin-console legacy only).

## Definition of done (per change, at implementation time)
`bash scripts/validate.sh` green · `context7`-verified APIs · impeccable refinement pass · re-run the screenshot capture · before/after PNGs committed to `docs/verification/` · `superpowers:verification-before-completion` passed before any "done" claim.
