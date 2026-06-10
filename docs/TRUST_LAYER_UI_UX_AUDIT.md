# Trade Credentials Trust Layer — UI/UX Audit

> **Date:** 2026-06-10 · **Branch:** `feat/trade-credentials-trust-layer` (uncommitted)
> **Method:** screen-by-screen review against `design-system/jobdun/MASTER.md`, the
> `profile-dashboard` / `applications` / `admin-web` page overrides, the `ui-ux-pro-max`
> guideline database (a11y / forms / loading), and Flutter accessibility docs (Context7).
> **Companion spec:** `docs/superpowers/specs/2026-06-10-trust-layer-ui-ux-improvements-design.md`

Severity: 🔴 fix before ship · 🟠 should fix · 🟡 polish.

---

## TL;DR

The trust layer is **functionally honest and privacy-correct** — the manual-review copy
never overclaims, the public projection is positive-only, statuses are dual-encoded, and
the AA token pairs are used everywhere. What's missing is **motivation and explorability**:
the trade never sees the payoff (the badge a builder sees), the empty state reads as three
failures, the builder can't interrogate a badge, and the admin can't triage against the
24-hour promise the app makes on every other screen. Plus two data-quality holes in the
upload sheet (no expiry validation, raw `e.toString()` errors) that undermine the badges
the whole feature exists to mint.

**Top 5 upgrades (ranked):**

| Rank | Spec ID | Upgrade | Screens | Why first-order |
|------|---------|---------|---------|-----------------|
| 1 | U1 | Upload-sheet conversion & data-quality pass (expiry validation, human errors, disabled-CTA helper, single labels, zoomable preview, PDF for insurance) | Manual upload sheet | Bug-adjacent; protects badge truth |
| 2 | U3 | Trust-hub reframe: payoff preview + positive empty state + de-burying the receipts card | Wizard hub + trade profile | Drives upload completion — the funnel's top |
| 3 | U2 | Explorable badges: one shared chip + tap-for-detail sheet + Semantics | Applicant detail | The builder is the badge's customer |
| 4 | U4 | Admin SLA triage: time-in-queue aging, oldest-first, amber-collision fix | Admin queue | The 24 h promise is UI-enforceable nowhere today |
| 5 | U5 | Expiry lifecycle: "expiring soon" state + owner renewal prompt + (later) push nudge | Receipts, badges | Prevents silent trust-signal loss |

(Spec build order is U1 → U2 → U3 → U4 → U5 — U2's shared chip is a dependency of U3's
badge preview, so it builds earlier than its impact rank.)

---

## Screen 1 — Trade credentials hub (`/verification/wizard`, trade role)

`verification_wizard_page.dart` → `_TradeCredentialsStep` → `VerificationReceipts`

**What's right**
- Honest expectation-setting: "A real person reviews each upload, usually within 24 hours" — no fake automation claims (matches the manual-only posture).
- Single source of truth: the hub reuses `VerificationReceipts`, so wizard and profile can't drift.
- Role gate (F1) renders nothing role-specific until the JWT role resolves.

**Findings**

| Sev | Finding | Where | Principle |
|-----|---------|-------|-----------|
| 🔴 | **Empty state is loss-framed.** A brand-new trade's first contact with the feature is three ✗ `closeCircle` rows reading "Not yet verified" — error glyphs for a neutral never-attempted state. Reads as "you failed three checks", not "three ways to stand out". | `verification_receipts.dart:250-256` | Error ≠ empty; empty states sell the action (MASTER: empty states get headline + CTA) |
| 🟠 | **No payoff preview.** Nothing shows what a builder will actually see (the WHITE CARD / INSURED chips). The user is asked to upload legal documents with no visualisation of the reward. | hub + `profile_page_trade.dart` | Motivation precedes effort; show the outcome |
| 🟠 | **Raw `CircularProgressIndicator` as page-body loading** while the role resolves. | `verification_wizard_page.dart:201` | MASTER: `JSkeletonList` for page-body loading; spinners are inline-only |
| 🟡 | Upload CTAs are bare text `InkWell`s (`Upload your licence →`) with ~30 dp tap height. | `verification_receipts.dart:310-323` | MASTER a11y: ≥ 48 dp touch targets |
| 🟡 | No completion signal ("1 of 3 added") anywhere on the hub. | hub | Progress feedback |
| 🟡 | Competing titles: app bar "Verification" + in-body H1 "Your credentials"; H1 forces `headlineMedium` to w700 (scale says w600). | `verification_wizard_page.dart:184,266-268` | One title per screen; respect the ramp |

**Principle scorecard:** hierarchy 🟠 · feedback 🟠 · a11y 🟡 · consistency ✅ · copy ✅ · flow ✅

---

## Screen 2 — Manual upload sheet

`manual_upload_sheet.dart`, `manual_upload_form.dart`, `manual_upload_controls.dart`, `manual_upload_priming.dart`, `manual_doc_kind.dart`

**What's right**
- The priming block (edges-in-frame / no glare / formats / human-review SLA) is exactly the right pre-upload education, carried over when the intro step was removed.
- Per-kind attestation copy anchors the legal claim; the whole card is the tap target.
- The phone-required gate fails **inline with a recovery CTA** ("VERIFY MY PHONE") instead of a dead-end snackbar — textbook error recovery.
- Keyboard insets + scroll view handled; `JTextField` reserves the error slot so layout doesn't jump.

**Findings**

| Sev | Finding | Where | Principle |
|-----|---------|-------|-----------|
| 🔴 | **Expiry is never validated.** Every kind except ABN `requiresExpiry`, but `_expiry` lives outside the `FormBuilder` and upload proceeds with `null`. `TradePublicCredential.isExpired` then stays `false` forever → a no-expiry White Card reads "verified" indefinitely. Undermines the exact signal the feature sells. | `manual_upload_sheet.dart:106-153`, `manual_upload_form.dart:175-180` | Validate on submit; data quality = badge truth |
| 🔴 | **Raw `e.toString()` shown to users** on pick and upload failures — Supabase/storage exceptions verbatim in the sheet. | `manual_upload_sheet.dart:102,181,286` | Human-readable errors near the problem |
| 🟠 | **Silently disabled UPLOAD.** Until the attestation is ticked the button greys out with zero explanation of why. | `manual_upload_controls.dart:90` | Never disable without stating the cause |
| 🟠 | **Double labels** on every labelled field: eyebrow `_Label('INSURER')` *plus* `JTextField(label: 'Insurer')` (JTextField renders its own label above the input) *plus* hint. Three names for one field. | `manual_upload_form.dart:148-174` | One label per input; visual noise |
| 🟠 | **No PDF path for insurance.** Insurers deliver Certificates of Currency as PDF email attachments; the picker is camera/gallery image-only ("JPG, PNG, WebP, or HEIC"). Real-world friction at the highest-value credential. | `manual_upload_controls.dart`, priming copy | Match the medium the artefact actually arrives in |
| 🟡 | Picked-photo preview isn't zoomable — "no glare / edges in frame" is bullet #1, yet the user can't enlarge to self-check. House pattern is `photo_view` tap-to-enlarge. | `manual_upload_controls.dart:64-71` | Support the behaviour you ask for |
| 🟡 | Success state is sparse (static icon + DONE) for the peak-end moment of the flow. 150–200 ms scale/fade via `flutter_animate` would land it without bounce. | `manual_upload_form.dart:314-338` | Peak-end; house motion rules |
| 🟡 | Attestation row should `MergeSemantics` so TalkBack reads checkbox + claim as one node. | `manual_upload_controls.dart:147-183` | Flutter a11y (Semantics/MergeSemantics) |
| 🟡 | Error text renders below the CTA at the sheet bottom; with the keyboard up it can sit offscreen with no auto-scroll. | `manual_upload_sheet.dart:284-291` | Errors must be visible when they fire |

**Principle scorecard:** hierarchy ✅ · feedback 🔴 · a11y 🟡 · consistency 🟠 · copy ✅ · flow 🟠

---

## Screen 3 — Trade's own profile

`profile_page_trade.dart` (+ `verification_receipts.dart` owner mode)

**What's right**
- "As at" dates on verified rows, expiry on supplementary rows — honest snapshot framing.
- Under-review rows show relative upload time + the 24 h SLA.
- B5 guard: a pending upload removes the upload CTA, so duplicate uploads can't start here.

**Findings**

| Sev | Finding | Where | Principle |
|-----|---------|-------|-----------|
| 🔴 | **The trust layer is buried.** `VerificationReceipts` is the *last* block — below stats, about, skills, portfolio, trade details, ratings and reviews. The page override spec puts verification directly under the header ("Profile is credibility"). The feature this branch ships is invisible without a full-page scroll. | `profile_page_trade.dart:151-160` | Hierarchy = importance; page override layout |
| 🟠 | **Two licence truths on one screen.** TRADE DETAILS shows self-declared `Licence: On file` (`hasLicence`) while the receipts card may simultaneously say "Trade licence — Not yet verified". Builders-grade trust signal contradicted by an honour-system row. | `profile_page_trade.dart:105-108` vs receipts | One source of truth per fact |
| 🟠 | **Owner can't see their public badge.** `TradeCredentialBadges` renders for builders only; the trade has no "how builders see you" mirror, so approval produces no visible reward on their own profile. | — | Self-view should mirror counterparty view |
| 🟡 | Same <48 dp text-CTA and ✗-glyph issues as Screen 1 (shared component). | `verification_receipts.dart` | a11y / framing |

**Principle scorecard:** hierarchy 🔴 · feedback 🟠 · a11y 🟡 · consistency 🟠 · copy ✅ · flow ✅

---

## Screen 4 — Applicant detail (builder evaluating a trade)

`applicant_detail_page.dart`, `applicant_detail_widgets.dart`, `trade_credential_badges.dart`

**What's right**
- Badges sit in the identity header — exactly where the hire/shortlist decision is made.
- Positive-only projection (approved creds only; never number/insurer/doc) — privacy-correct.
- Expired state is dual-encoded: clock glyph + "(EXPIRED)" text + neutral pair, not colour alone.
- AA-safe `verifiedBg`/`verifiedTx` pairs throughout.

**Findings**

| Sev | Finding | Where | Principle |
|-----|---------|-------|-----------|
| 🟠 | **Badges are dead ends.** "WHITE CARD" / "INSURED" chips answer nothing: what was checked? by whom? when? until when? No tap, no tooltip, no detail sheet — a builder who doesn't already know the term gets zero help, and the diligence-minded one gets no depth. | `trade_credential_badges.dart`, `applicant_detail_widgets.dart:83` | Progressive disclosure; trust needs provenance |
| 🟠 | **Duplicate chip implementations.** `_VBadge` (applicant detail) and `_CredChip` (badges) are near-identical pills built twice — one uses `AppRadius.chip`, the other hardcodes `6.r`. Drift is one PR away. | `applicant_detail_widgets.dart:113-148`, `trade_credential_badges.dart:49-86` | One component per pattern |
| 🟡 | **No Semantics.** Chips are bare `Container(Icon+Text)`; screen readers get the caps string with no "verified credential" meaning. | both chip widgets | `Semantics(label:)` per Flutter a11y docs |
| 🟡 | Badges pop in after the async load and reflow the header `Wrap` (content-jumping). A 150 ms fade-in would mask it. | `trade_credential_badges.dart:24-28` | Reserve/soften async arrival |
| 🟡 | Star icon uses `c.warning` here but the `c.star` token elsewhere. | `applicant_detail_widgets.dart:91` | Token discipline |

**Principle scorecard:** hierarchy ✅ · feedback 🟡 · a11y 🟠 · consistency 🟠 · copy ✅ · flow ✅

---

## Screen 5 — Admin verification queue (web)

`admin_verifications_page.dart`, `admin_verification_queue_row.dart`, `admin_verification_review_sheet.dart`

**What's right**
- Kind filter chips with live counts; PENDING/REVIEWED split; dual-encoded status (dot + caption).
- The API-failure context line on fallback uploads gives the reviewer exactly the right prior.
- Review dialog: confirm-fields prefilled from the claim ("it matches" = one tap, typos still editable), per-button spinner so the in-flight decision is unambiguous.

**Findings**

| Sev | Finding | Where | Principle |
|-----|---------|-------|-----------|
| 🟠 | **No SLA instrumentation.** The app promises review "within 24 hours" on three trade-facing surfaces, but the queue shows only an absolute timestamp — no time-in-queue, no aging colour, no visible oldest-first guarantee. The reviewer can't see what's about to breach. | `admin_verification_queue_row.dart:64-67` | Make the SLA the queue's organising principle |
| 🟠 | **Amber semantic collision.** The WHITE CARD *kind* badge uses `warningBg/warningTx` — the same amber that means *pending* everywhere else (including the status dot two columns left). Category colour reads as status. | `admin_verification_queue_row.dart:133-137` | Caution ≠ category (MASTER colour rules) |
| 🟡 | Raw `Icons.refresh` / `Icons.inbox_outlined` / `Icons.warning_amber_rounded` / `Icons.chevron_right` rather than the `AppIcons` catalogue. | both files | Icon single point of contact |
| 🟡 | REVIEWED renders the entire history unbounded — fine today, pagination flagged for scale. | `admin_verifications_page.dart:97-109` | Long-list rule |
| 🟡 | Review surface is a `Dialog`, not a route (no deep link to a specific document). Already-tracked debt from the admin overhaul — re-flagged, not re-counted. | `admin_verifications_page.dart:116-121` | Navigable state |

**Principle scorecard:** hierarchy ✅ · feedback 🟠 · a11y 🟡 · consistency 🟡 · copy ✅ · flow 🟠

---

## Cross-cutting

1. **Semantics pass (a11y).** None of the new trust surfaces annotate for screen readers: chips need `Semantics(label:)`, the attestation row needs `MergeSemantics`, receipts rows should read label + status as one node. (Verified against current Flutter docs — `Semantics`, `MergeSemantics`.)
2. **Touch-target floor.** All bare-text CTAs in `verification_receipts.dart` are below the 48 dp floor MASTER enforces on buttons.
3. **Three chip implementations** across the mobile app for the same visual (verified pill). Consolidate before a fourth appears.
4. **Owner/expired blind spot.** `VerificationStatus.expired` exists, but an owner whose approved doc expires falls through to "Not yet verified" — the *why* (expired, renew) is lost. Counterparty and owner views disagree at exactly the moment the owner should act.
5. **Flow is sound.** The macro journey (profile → hub → sheet → review → badge → builder decision) has no dead ends, every state transition is reachable, and the B3/B5/F1/F2 guards close the loops the previous audit opened. The gaps are persuasion, provenance, and operations — not navigation.

---

## Where this audit's fixes live

All five upgrades are specced with states, copy, components, and test plans in
`docs/superpowers/specs/2026-06-10-trust-layer-ui-ux-improvements-design.md`.
