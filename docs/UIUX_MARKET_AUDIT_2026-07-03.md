# Jobdun — First-Run UI/UX Market Audit

**Date:** 2026-07-03
**Scope:** The first five screens a new user meets — Splash → FTUE carousel → Role select → Create account / Login → First Home.
**Goal:** Benchmark against the apps Australian tradies and builders actually use, and map the path to the best-feeling first-run in the AU trades market.
**Method:** `superpowers:brainstorming` (context stage) · `ui-ux-pro-max` + design-system docs · `impeccable critique` lens (Nielsen + cognitive-load + persona) · live competitor research (3 agents, cited).

> **Capture-coverage honesty note.** Real device renders were captured on the **iPhone 17 Pro Max simulator** (iOS 26.5) for: Splash, FTUE slide 1 (hero photo + headline), and the notification-permission timing issue. The macOS sandbox blocked synthetic tap/swipe injection (`osascript` has no assistive-access), and no Android emulator is installed on this host (the SDK has no `emulator`/system-images; `scripts/capture_app_screenshots.sh` targets a Linux/KVM box). So **FTUE slides 2–3, role select, the register form, login, and Home were audited from full source reads**, not interactive renders. Every finding cites `file:line`. Interactive capture of those five is the one open verification item — re-run the audit on the Android box or grant Simulator accessibility to close it.

---

## 1. Executive summary

Jobdun's first-run flow is **well-crafted and genuinely on-brand** — it passes the AI-slop test cleanly, which most competitors fail. The dark-slate + safety-orange + Archivo/Inter system, the authentic worksite photography, and the pitch-perfect Aussie tradie voice ("ONLY VERIFIED. NO TIMEWASTERS.", "sparkies, chippies, plumbers, and crews") give it an identity no incumbent has. That is a real moat.

But it loses the market on **one structural decision and a handful of fixable frictions**. The single biggest gap: **Jobdun gates 100% of its value behind account creation.** A new tradie cannot see one real job before signing up. *Every* competitor benchmarked — Airtasker, Jora, Indeed, SEEK, ServiceSeeking — lets you browse before you commit; Indeed has an explicit "continue without an account." Deferred signup is one of the highest-leverage growth moves known (Duolingo: ~+20% DAU). Fixing this is worth more than everything else combined.

Second: the **iOS notification-permission prompt fires on FTUE slide 1** (confirmed across two launches) — before the user has seen any value, which tanks grant rates and first impression. Third: several **inherited accessibility debts** (input-label/placeholder contrast 3.07:1, resting input borders 1.41:1) land squarely on the register/login screens users hit first. None are new; all are scoped in `DESIGN_SYSTEM_SUGGESTIONS.md`.

The market itself just shifted: **Oneflare retired into Airtasker on 30 June 2026**, leaving its verification-first position (ABN + licence + insurance checked before quoting) **unowned**. Jobdun's whole premise is verification. This is an open goal.

### Per-screen scorecard (8-dimension rubric, 1–10)

| # | Screen | Value clarity | Friction→value | Trust | Craft | A11y | Perf | Copy | Flow | **Avg** |
|---|--------|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| 1 | Splash | 5 | 4 | 4 | 8 | 6 | 4 | 6 | 7 | **5.5** |
| 2 | FTUE carousel | 7 | 3 | 7 | 8 | 6 | 6 | 9 | 5 | **6.4** |
| 3 | Role select | 8 | 5 | 4 | 7 | 5 | 7 | 8 | 7 | **6.4** |
| 4 | Create account / Login | 7 | 4 | 4 | 7 | 4 | 7 | 7 | 8 | **6.0** |
| 5 | First Home | 7 | 6 | 6 | 7 | 6 | 6 | 6 | 6 | **6.3** |

Lowest columns tell the story: **Friction→value** (the signup wall) and **Accessibility** (inherited contrast debt) are the systemic drags; **Craft** and **Copy** are the systemic strengths.

### Nielsen design-health score (whole flow)

| # | Heuristic | Score | Key issue |
|---|-----------|:--:|-----------|
| 1 | Visibility of system status | 3 | Splash uses a *fixed* 900ms timer, not a readiness signal |
| 2 | Match system / real world | 4 | Aussie tradie language is fluent throughout — best pillar |
| 3 | User control & freedom | 3 | SKIP/back/CHANGE all present; but no browse-without-account |
| 4 | Consistency & standards | 3 | Shipped SSO treatment contradicts `auth-onboarding.md`; doc copy tables are stale |
| 5 | Error prevention | 3 | Good validators; password composition rule is over-strict |
| 6 | Recognition vs recall | 3 | Labelled role cards + SSO + icons-with-text |
| 7 | Flexibility & efficiency | 3 | Tap-to-advance, deep-linked role, autofill, SSO shortcuts |
| 8 | Aesthetic & minimalist | 3 | Slide 3's 4-way decision + the notification interrupt dent it |
| 9 | Error recovery | 3 | Inline errors near fields, human copy, no form wipe |
| 10 | Help & documentation | 2 | No contextual help / "why verify?" explainer / support entry in-flow |
| **Total** | | **30/40** | **Good** — strong foundation; friction + help are the gaps |

**AI-slop verdict: PASS.** Distinctive dark-slate/orange/flat identity, authentic photography, opinionated voice. Not templated SaaS. (Concurs with the prior `DESIGN_SYSTEM_AUDIT` 4/4 anti-slop.)

> Assessment B note: `impeccable`'s deterministic detector and browser overlay **cannot run on this target** — it parses web frameworks (TSX/Astro/CSS), not Dart (documented in `CLAUDE.md`). So this is a single-track design review from source + real renders, not a dual-agent critique. ⚠️ DEGRADED by design for a Flutter target — flagged, not hidden.

---

## 2. Screen-by-screen findings

### Screen 1 — Splash (`/splash`, `splash_page.dart`)
**Render:** dark navy, animated forge logo + "JOBDUN" wordmark (sanctioned `brandFlame` gradient) + tagline + 2px loading bar. Clean, on-brand, distinctive.
**Top issues:**
- **[P2] Fixed 900ms delay tax.** `splash_page.dart:29` — `Timer(Duration(milliseconds: 900))` fires regardless of whether auth/FTUE state is ready. Every cold start pays 900ms even when it could hand off sooner. Casey (distracted mobile) abandons on artificial waits.
- **[P3] Loading bar is decorative** (fixed 800ms tween, `splash_page.dart:142`), not tied to real progress — mild honesty gap.
**Highest-leverage fix:** advance on readiness (auth + FTUE gate loaded), capped at ~900ms, instead of a blind timer.

### Screen 2 — FTUE carousel (`/ftue`, `ftue_page.dart` + 3 slides)
**Render (slide 1):** authentic photo of a real tradie in hi-vis at a timber worksite (DeWalt tools — not a stock model), "ONLY VERIFIED. / NO TIMEWASTERS." (navy + orange split), body, orange page dot, SKIP. Excellent.
**Strengths:** best-in-class copy voice; authentic imagery (picture-superiority + NN/g "real photos are read as content, stock is ignored"); slide 2's IP-geo personalization ("JOBS IN <city>" + real suburb chips, `slide_two_speed.dart`) is a genuine wow-moment.
**Top issues:**
- **[P1] Notification prompt fires here, pre-value.** Confirmed across two launches (`docs/verification/2026-07-03-ios-03-notif-prompt-on-ftue.png`). iOS HIG + NN/g both say defer the OS prompt until context justifies it. Asking on slide 1 — before the user has seen a single job — depresses grant rates and reads as a demand before a gift.
- **[P1] The signup wall starts here.** The router forces new users splash → `/ftue` → role → `/register`/`/login` (`app_router.dart:86–118`). No path shows a real job before an account. This is the market gap (see §3).
- **[P2] Slide 2's "100+ active jobs within 15km" is hardcoded copy** (`slide_two_speed.dart:95`), not a live count. If the user then lands on an empty Home, the promise is broken — the exact "fake leads" complaint that sinks competitors.
- **[P2] Slide 3 is a 4-way decision** (I'm hiring / I'm looking for work / Continue with Google / I already have an account · LOG IN), `slide_three_action.dart:81–151`. Cognitive-load rule is ≤4 visible options at a decision point; the two role CTAs are the *one* real decision and the extras dilute it. The mid-slide Google button also contradicts `auth-onboarding.md` ("SSO demoted to tertiary, small text links").
**Highest-leverage fix:** defer the notification prompt; add a "browse jobs first" path off slide 3.

### Screen 3 — Role select (`register_page_role_step.dart`, `register_page.dart`)
**Source:** "WHICH SIDE ARE YOU ON?" + two tap-to-advance cards ("I'M HIRING" / "I'M LOOKING FOR WORK") + SSO trio + login link. Confident and decisive.
**Strengths:** tap-to-advance (no Continue button, `register_page.dart:65`) is efficient; CHANGE chip fixes misclicks (`register_page_form_step.dart:211`); back returns to picker. Well-modelled.
**Top issues:**
- **[P2] Selected role icon is white-on-orange** (`register_page_role_step.dart:214`, "intentional: white-on-action") = 2.80:1, fails the 3:1 UI-component floor. The CTA *buttons* were already fixed to dark `onAction` (#0F172A, 6.37:1) — this icon is a leftover of the old white-on-orange pattern.
- **[P1, inherited] Resting card/input borders 1.41:1** — invisible until the orange focus border appears (`DESIGN_SYSTEM_AUDIT §5`, `SUGGESTIONS S2-BORDER`; fix = `borderStrong #708096`, 3.63:1). Not new; confirmed present here.
**Highest-leverage fix:** swap the selected icon to dark `onAction`; ship the `borderStrong` token.

### Screen 4 — Create account / Login (`register_page_form_step.dart`, `login_page.dart`)
**Source:** role chip + "CREATE ACCOUNT" + role-specific headline ("Let's get you on the tools.") + full name / email / password (+ strength bar) + terms. Login mirrors it with email/password + 3 SSO tiles.
**Strengths:** phone deferred to first apply/post (`register_page_form_step.dart:118` — good friction call); password strength bar; inline errors; autofill + Next-key traversal; tap-outside-to-dismiss (`login_page.dart:103`). Solid engineering.
**Top issues:**
- **[P1] Password composition rule is over-strict for the audience.** Requires ≥8 chars **and** an uppercase **and** a digit **and** a symbol (`register_page_form_step.dart:287–299`). NIST 800-63B explicitly advises *against* composition rules (they hurt completion without improving real security); length is what matters. On a phone, on a worksite, the symbol requirement is a known abandonment driver.
- **[P1, inherited] Field labels / placeholders / hints use `text3` = 3.07:1** — fails AA 4.5:1 for content text (placeholders are content). Governs every field on both screens (`DESIGN_SYSTEM_AUDIT §5`, `SUGGESTIONS S1-TEXT3`; fix = `#8B98AB`, 5.0:1).
- **[P2] No social proof at the highest-friction moment.** Nothing reassures the user that real people are here ("2,400+ verified tradies on the tools"). Research: third-party social proof near auth/lead forms lifts conversion; competitors that lack it get "is anyone even on this?" complaints.
- **[P2] Login's 3 prominent SSO tiles contradict the design-system doc** (`auth-onboarding.md`: "SSO demoted to tertiary — small text links only. No large SSO brand buttons."). Either the doc or the shipped screen is wrong; they disagree.
**Highest-leverage fix:** relax the password rule to length-based (product sign-off needed); ship the `text3` contrast fix.

### Screen 5 — First Home (`home_page.dart` + parts)
**Source:** tradie = availability bar + Action Deck ("where do I stand") + "JOBS NEAR YOU" feed (or `_HomeJobsEmpty`); builder = bento grid with **real** live stat tiles (active jobs / applicants / tradies-nearby). New users get an `OnboardingCompletionSheet` (role+name) + a welcome toast.
**Strengths:** status-first IA (matches the product's own "put status first" principle); builder bento uses real counts, not fake stats; floating LinkedIn-style top bar; staggered lists; server-side jobs-feed cache.
**Top issues:**
- **[P2] Empty state is a passive dead-end.** `_HomeJobsEmpty` (`home_widgets.dart:10–52`) is icon + "No jobs nearby yet" + "New jobs in your area will appear here." — **no CTA, no Lottie**, violating MASTER §313 ("Lottie + bold headline + single filled CTA. Never blank. Never text-only."). A new tradie in a quiet area hits a screen with nothing to *do*. Add "BROWSE ALL JOBS" / "EXPAND RADIUS →".
- **[P2] New-user modal gate.** A fresh SSO/phone user lands on Home and is immediately met with the role/name sheet (`home_page.dart:169`) before touching anything — another gate stacked on the signup wall.
- **[P3] Welcome toast is fine** ("You're in. Finish your profile to start applying.", `home_page.dart:204`) — direct, on-voice; keep it.
**Highest-leverage fix:** give the empty state a filled CTA + Lottie; make sure the first Home can show *real* jobs (ties to browse-before-signup).

---

## 3. Competitor benchmark (AU, July 2026 — cited)

**Market structure shift (verified 3 Jul 2026):** **Oneflare retired 30 June 2026** and folded into Airtasker (`oneflare.com.au` 301s to airtasker.com; [Airtasker notice](https://support.airtasker.com/hc/en-au/articles/59294413002393-Oneflare-is-retiring-here-s-what-you-need-to-know)). The market is now **hipages vs Airtasker** on the marketplace side; newer entrants (Tradiespace, ServiceTasker) show no meaningful traction. **Oneflare's verification-first position — ABN + licence + insurance checked before quoting — is now unowned.**

### First-five-screens comparison (rubric dimensions × app)

| Dimension | **Jobdun** | Airtasker | hipages (tradie) | ServiceSeeking | Jora / Indeed / SEEK |
|-----------|:--:|:--:|:--:|:--:|:--:|
| Value clarity pre-signup | 7 | 8 | 7 | 7 | 8 |
| **Browse before signup** | **2** | 8 | **1** (pay+contract first) | 6 (see leads free) | 9 (Indeed: explicit guest mode) |
| Trust/verification display | 7 | 9 (badges everywhere) | 5 ("vetted" opaque) | 5 (self-serve badges) | 6 |
| First-feed relevance | 6 | 8 | 6 | 6 | 7 (but top complaint = geo relevance) |
| Craft / distinctiveness | **8** | 6 | 4 ("glitchy") | 4 ("poorly executed") | 6 |
| Copy / voice | **9** | 6 | 6 | 6 | 6 |
| Store rating | n/a (pre-launch) | 4.9★ iOS / 4.53★ Play | 3.5★ business iOS | 3.9★ business iOS | 4.7★ across |

Jobdun **leads on craft and voice**, is **competitive on trust**, and **loses decisively on browse-before-signup** — the one dimension every incumbent nails.

### Review-mined complaints = Jobdun's open goals

Recurring UX complaints across incumbent store reviews (all cited in the research appendix), each an opening:

| Competitor pain point | Representative complaint | Jobdun's move |
|-----------------------|--------------------------|---------------|
| **Lead-price opacity** | hipages "$70–$200 per lead… waste of time"; Oneflare credits repriced 27→100+ silently | Show full cost before any commitment |
| **Pay-before-value gate** | hipages: can't see a single lead without a paid plan + 6–12mo contract | Free browse + free first apply |
| **Contract lock-in** | "locked into 6–12-month contracts with aggressive debt collection" | No contracts, cancel in-app |
| **Fake / stale leads** | Oneflare "70% of leads are fake"; ServiceSeeking "leads already taken by morning" | Real verified jobs, real-time; never fake counts (see slide-2 finding) |
| **App quality** | Airtasker "clunky, glitchy uploads"; ServiceSeeking "deleted all my messages" | **Polish as the differentiator** — Jobdun's craft already wins here |
| **Trust theatre** | hipages "vetted" claims + review censorship | Oneflare-grade verification, *surfaced day one* |
| **Geo relevance** | Jora/Indeed's #1 complaint: "jobs way out of my area" | Radius-accurate feed (Jobdun's geo-personalized FTUE already leans here) |

### Craft patterns worth stealing (global references)

- **Duolingo — deferred signup + personalization quiz + goal gradient.** Moving the signup wall back a few steps = ~+20% DAU ([First Round](https://review.firstround.com/the-tenets-of-a-b-testing-from-duolingos-master-growth-hacker/)); a 3–5 tap quiz that visibly reshapes the experience; progress bars pre-seeded above 0% (goal-gradient, Kivetz 2006: endowed progress → 34% faster completion). → Let a tradie search + open a job + start an apply; ask for the account only to submit. Pre-seed the profile-strength meter.
- **Uber Driver — earnings-first + stateful verification funnel.** Shows city-specific earnings *before* paperwork; document upload is one-step-at-a-time with visible per-item status + expected review time, full access while pending. → Show live local jobs + typical rates before asking for a document; verification (White Card / licence / ABN) as a checklist with status, not a wall.
- **Airbnb — imagery-led trust + progressive disclosure.** Professional photos drove up to +40% views; ask minimal inputs first, defer the rest. → Real job-site photos on cards (Jobdun already uses authentic FTUE photography — extend it to job cards); ask trade + postcode first, defer rates/docs/portfolio.

### Onboarding evidence base (numbers, cited)

- **Deferred signup:** login walls have high interaction cost and defy reciprocity ([NN/g](https://www.nngroup.com/articles/login-walls/)); Duolingo soft-wall **+20% DAU**.
- **Form-field count:** Baymard — **26%** abandon solely because a flow is too long; reference redesigns cut 16→8 fields. Every field/rule must fight for its life. → password composition rule.
- **Social proof on auth:** third-party proof outranks self-claims ([NN/g](https://www.nngroup.com/articles/social-proof-ux/)); testimonials near signup/lead forms lift conversion (vendor tests +18–34%, lower-confidence).
- **Picture superiority:** recall ~10% (text) vs ~65% (with relevant image); NN/g eye-tracking — **stock "feel-good" images are ignored, real photos are read as content**. A real founder photo beat the best stock by 35%. → Jobdun's authentic-photo policy is correct; never regress to stock hi-vis models.
- **Dark UI outdoors:** positive-polarity (dark-on-light) is more legible in general, but dark mode reduces fatigue **in bright ambient light** (ETRA 2025). → Keep the dark brand; compensate on-site with max-contrast text (#F1F5F9 on #0F172A ≈ 15:1), heavier weights + larger sizes for glanceable data (rates, suburbs, CTAs), and never load-bearing `#94A3B8`. This is exactly the inherited `text3`/border contrast debt — fixing it *is* the outdoor-legibility fix.

---

## 4. Gap analysis

**Where Jobdun already wins** (protect these):
- Distinctive, non-slop identity — dark slate + safety orange + Archivo/Inter.
- Authentic worksite photography (picture-superiority done right).
- Pitch-perfect Aussie tradie voice — no competitor is close.
- App craft/polish — incumbents' #1 complaint class is "glitchy/poorly executed."
- Verification premise — and the market just vacated the verification-first position.

**Where Jobdun lags** (close these):
- Browse-before-signup: Jobdun is the *only* one that gates 100%. Biggest lever.
- Notification-prompt timing: asked pre-value.
- Accessibility contrast on the exact first-run screens (inherited, scoped, unshipped).
- Signup friction: password composition rule; no social proof at the CTA.

**Where nobody is good** (own these):
- Lead-cost transparency + no lock-in (every incumbent is hated for this).
- Verification surfaced as day-one trust with real proof, not claims (Oneflare's vacated seat).
- Radius-accurate first feed (Jora/Indeed's top complaint; Jobdun's geo-FTUE already gestures at it).

---

## 5. Roadmap — top 10 by (new-user impact × effort)

Ranked. Size class: **QW** = quick win ≤1 day · **S** = structural · **PD** = needs product decision. Full detail + design-system compliance notes in `docs/superpowers/specs/2026-07-03-top1-uiux-design.md`.

1. **Browse-before-signup (guest mode for trades).** Let a new trade see the *real* local jobs feed before creating an account; gate only apply/save. — **S + PD** · biggest lever; ~+20% DAU precedent; closes the one dimension every competitor wins.
2. **Defer the notification-permission prompt** to after the first meaningful action (browse/apply), not FTUE slide 1. — **QW** · lifts grant rates + first impression.
3. **Make slide 2's job count real** (or reword) so the FTUE promise matches the Home feed. — **QW** · kills a "fake leads"-class trust break (`slide_two_speed.dart:95`).
4. **Add social proof to the CREATE ACCOUNT / LOG IN screens** — live verified-tradie count / recent activity near the CTA. — **QW** · conversion at the highest-friction moment.
5. **Relax the password rule** to length-based (NIST 800-63B), keep the strength meter as guidance. — **QW + PD** · cuts signup abandonment (`register_page_form_step.dart:287`).
6. **Fix the Home empty state** — filled CTA ("BROWSE ALL JOBS" / "EXPAND RADIUS →") + Lottie per MASTER §313. — **QW** · removes a dead-end (`home_widgets.dart:10`).
7. **Ship the inherited AA contrast fixes on first-run screens** — `text3 → #8B98AB` (5.0:1) for input labels/placeholders; `borderStrong #708096` (3.63:1) for resting borders; selected role icon → dark `onAction`. — **QW** · AA compliance + outdoor legibility, already scoped in `SUGGESTIONS`.
8. **Trim FTUE slide 3 to one decision** — two role CTAs as hero; demote Google SSO + login link to one quiet line. — **QW** · fixes the >4-option cognitive spike; realigns with `auth-onboarding.md`.
9. **Replace the fixed 900ms splash timer with a readiness-driven handoff** (cap ~900ms). — **QW** · removes a per-launch latency tax (`splash_page.dart:29`).
10. **Own verification-first trust (Oneflare's vacated seat)** — a "how we verify" micro-explainer in FTUE + verified badges in the first feed, tied to the existing verification subsystem. — **S** · brand-defining, timely.

**One strategic decision for the user before build:** #1 reverses the current auth-first posture — deciding *what an anonymous user can see* (which jobs, how much detail, poster identity/RLS for anon reads) is a product + backend call, not a cosmetic one. This is the Phase-4 brainstorm to have on your return; the rest of the roadmap can proceed without it.

---

## 6. Deliverables & next step

- **This report** — `docs/UIUX_MARKET_AUDIT_2026-07-03.md`.
- **Roadmap spec** — `docs/superpowers/specs/2026-07-03-top1-uiux-design.md` (top-10 detail + open decisions).
- **Real renders** — `docs/verification/2026-07-03-ios-0{1,2,3}-*.png`.

**Hard stop.** No code, no screen edits until you've reviewed the spec and made the browse-before-signup call. On your go, implementation runs `superpowers:writing-plans` → TDD → `context7`-verified APIs → impeccable refinement → `validate.sh` green + before/after screenshots + `verification-before-completion`.
