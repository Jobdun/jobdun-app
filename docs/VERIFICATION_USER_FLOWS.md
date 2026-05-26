# Jobdun — Verification User Flows (v2.1)

> **Companion to** `docs/VERIFICATION_AUDIT.md` (architecture) and `docs/W1_W3_REALITY_CHECK.md` (sprint state).
> **Model decision locked (2026-05-26):** verification is **optional, never gating**. Everyone can join, post, apply, and message. Verification is a **visible feature of the profile** — receipts, not permission. Builders choose whether to filter for verified workers. Tradies choose whether to verify.
> **Scope tightened (2026-05-27):** verification is now **role-scoped to a single kind** — Builders verify ABN (business identity), Trades verify trade licence (qualification). Each wizard is one step. Both surfaces offer a manual document-upload fallback when the regulator can't be reached or returns ambiguous results. Supersedes v1 + the v2 dual-step trade flow.

This doc is the user journey, the architectural posture, and the punch list of v1→v2 changes.

---

## 1. Model in one sentence

**Jobdun tells you exactly what's been verified, by whom, and when — and lets you choose how much that matters to you.**

Verification isn't a gate. It's a **receipt** on a profile. Builders see it. Builders decide.

---

## 2. Why this model wins

- **No supply exclusion.** Painters, labourers, apprentices, tilers, plasterers, casual chippies — all join from day 1. Forcing a state Fair Trading licence on everyone would shrink the platform to ~60% of the real AU market.
- **Honest trust signal.** Hipages says "verified" when a tired admin glanced at a JPG. Jobdun says what was actually checked (ABN ✓, NSW Fair Trading ✓, expires 2028) — or honestly says "Not verified."
- **Builder discretion.** Residential build doing a $50k kitchen wants verified. Commercial builder hiring six labourers for demo doesn't. Both valid; both supported.
- **Defensible marketing.** "Every profile shows exactly what was checked" holds whether 10% or 80% of supply is verified. The transparency itself is the moat.
- **Hipages can't copy this without downgrading every existing "verified" stamp to "not verified" overnight.** They won't. They're stuck.

---

## 3. Tradie — first time

```
Splash → FTUE → Register (role = Trade) → Verify email
   ↓
Onboarding — name, primary trade, avatar, bio
(NO ABN, NO licence collected here)
   ↓
HOME (jobs feed)
   ↓
   ┌────────────────────────────────────────────────────────┐
   │ Soft nudge banner (per-session dismissible):           │
   │ "Verified workers get hired faster. About a minute.    │
   │  [ Get verified → ]                              [ × ] │
   └────────────────────────────────────────────────────────┘
   ↓
   ✓ Can browse all jobs
   ✓ Can apply to all jobs
   ✓ Can message any matched builder
   ✓ Profile is live immediately
```

The wizard is reachable from:
- The home banner
- Profile → "Verify in about a minute →" CTA on each unverified receipt row
- (Future) a contextual nudge after the first few applications

### Wizard (single step, optional throughout)

```
Step 1 of 1: State + licence
   → Adapter call (verify-licence Edge Function)
   → verified  → result screen, licence row in `verifications`
   → failed    → "We couldn't verify this licence"
                 [ UPLOAD DOCUMENT INSTEAD ] [ TRY AGAIN ] [ CONTINUE ]
   → manual_review (regulator unreachable)
                 [ UPLOAD DOCUMENT INSTEAD ] [ TRY AGAIN ] [ CONTINUE ]
```

Tradies do **not** enter an ABN. The licence is the signal that matters
for trade qualification; the ABN proves business identity (relevant for
builders, not workers). A sole-trader sparkie's ABN doesn't make them a
qualified electrician — the NSW Fair Trading licence does.

**Manual-upload fallback.** When the regulator can't confirm a licence
(stub, real outage, ambiguous match, no API for that state yet), the
failure screen offers an "Upload document instead" CTA. The tradie
picks a photo or PDF of their licence, it lands in
`verification_documents` as `pending`, and a reviewer flips it to
`verified` within 24 h. The profile receipt updates automatically when
the row flips.

Key changes from v2.0:
- ABN step removed for trades entirely.
- Step label "Step 1 of 1" (was "Step 2 of 2").
- Failure path stays on the licence step instead of bouncing to the
  result screen, so the upload fallback is visible at the moment of
  failure rather than one screen later.

---

## 4. Builder — first time

```
Splash → FTUE → Register (role = Builder) → Verify email
   ↓
Onboarding — company name, logo, description
(NO ABN collected here)
   ↓
HOME (builder shell)
   ↓
   ┌────────────────────────────────────────────────────────┐
   │ Soft nudge banner:                                     │
   │ "Verified businesses get more applicants. 15 secs.     │
   │  [ Get verified → ]                              [ × ] │
   └────────────────────────────────────────────────────────┘
   ↓
   ✓ Can post jobs immediately
   ✓ Can browse all trades
   ✓ Can message any trade who applies
```

Builder wizard = ABN-only, single step. Entirely optional.

```
Step 1 of 1: ABN
   → ABR call (verify-abn Edge Function, JSONP-aware)
   → verified  → entity-name confirm → "Yes, that's me"
   → failed    → "We couldn't verify this ABN"
                 [ UPLOAD DOCUMENT INSTEAD ] [ TRY A DIFFERENT ABN ]
   → manual_review (ABR unreachable)
                 [ UPLOAD DOCUMENT ] [ CONTINUE WITHOUT UPLOAD ]
```

Same manual-upload fallback as the trade flow. ABN certificate lands
in `verification_documents` as `pending`; reviewer confirms within 24 h.

---

## 5. Builder — the applicant list (this is where the model lives or dies)

```
Job: "Sparky for kitchen rewire, Bondi, $1.2k"
Applicants (8):

┌──────────────────────────────────────────────────────────┐
│ [ Verified workers only ]  ●  on  (default ON)           │
│ Sort: Verified first ▾                                   │
└──────────────────────────────────────────────────────────┘

──────────────────────────────────────────────────────────
Sam Wilson  ★ 4.8 (23 reviews)
 Electrician · Bondi NSW
 ✓ ABN active (Australian Business Register)
 ✓ NSW Electrical Licence (NSW Fair Trading) — expires 2028
 Quoted: $1,150 · Available: Tue
 [ Message ]  [ View profile ]
──────────────────────────────────────────────────────────
Dave Murphy  ★ — (new)                  (only when filter OFF)
 Electrician · Bronte NSW
 ◯ Not verified
 Quoted: $850  · Available: Today
 [ Message ]  [ View profile ]
```

**Defaults that matter:**
- Filter defaults **ON** (verified only). Toggle exposes the one-time consent dialog.
- Sort defaults to "verified first." When filter is off, verified workers still render above unverified ones.

The verified-first sort applies everywhere a list of users appears (applicant list, future browse-trades directory, search, recommendations).

---

## 6. Profile badges — the receipts

The badge isn't one binary tick. It's a list of receipts, rendered by `VerificationReceipts` (`lib/features/verification/presentation/widgets/verification_receipts.dart`).

### Fully verified
```
What's been checked
─────────────────────────────
✓ Business (ABN)
  Jones Building & Electrical Pty Ltd · Checked against the
  Australian Business Register · 2 days ago

✓ Trade licence
  Checked against NSW Fair Trading's public register ·
  2 days ago · expires 14 Feb 2028
```

### Partially verified (owner viewing own)
```
What's been checked
─────────────────────────────
✓ Business (ABN)
  Checked against the Australian Business Register · 1 week ago

◯ Trade licence
  Not yet verified
  Verify in about a minute →    ← only visible to the owner
```

### Not verified
```
What's been checked
─────────────────────────────
◯ Business (ABN)
  Not yet verified
  Verify in about a minute →

◯ Trade licence
  Not yet verified
  Verify in about a minute →
```

**Critical wording rules** (legal — ABR agreement clause 3):
- ✅ "Checked against the Australian Business Register"
- ✅ "Checked against NSW Fair Trading's public register"
- ❌ Never "Verified by ABR" / "Government-approved"
- ❌ Never put a regulator logo on the badge

---

## 7. What stays silent in the background

For users who do verify:

```
Nightly cron, 02:00 Sydney   (Phase 2 — not in v2-launch PR)
   ↓
For every row where status = 'verified':
   if expires_at < now()        → flip to 'expired', Realtime ping
   if last_checked_at > 24h ago → re-check, update timestamp
```

Result on the user side:
- Badge downgrades to "Expired" / "Not verified" if state changes
- Push notification when their licence expires or is suspended
- Existing applications are **not** retracted — they were legit when submitted

7-day-lookahead push (Phase 2):
> Heads up — your NSW Electrical licence expires in 7 days. Renew with Service NSW, then re-verify in Jobdun.

**No per-action regulator call** anywhere. Apply/Post are pure Postgres lookups. Verification is a profile attribute, not a permission.

---

## 8. Trust & Safety guardrails

| Guardrail | Status |
|---|---|
| **G1.** One-time "include unverified workers" consent dialog on filter-OFF | ✅ Ships in v2 launch — `UnverifiedConsentDialog` + `builder_unverified_acknowledgements` table |
| **G2.** Asymmetric report thresholds (3 strikes for verified vs 1 for unverified) | Phase 2 |
| **G3.** Hire-time verification snapshot on reviews | ✅ Ships in v2 launch — `applications.verification_snapshot_at_hire` + `reviews.reviewee_verification_snapshot` |
| **G4.** Job-post rate limits on unverified builders | Phase 2 |
| **G5.** Verification-rate top-line dashboard tile | Phase 2 (telemetry rows already write to `verification_funnel_events`) |

---

## 9. What changed vs. v1 — concrete file list

### Backend
| File | Change |
|---|---|
| `supabase/functions/verify-licence/index.ts` | **Dropped the 412 "ABN required first" gate.** |
| `supabase/migrations/20260526000001_verification_v2.sql` | **NEW.** `builder_unverified_acknowledgements`, `applications.verification_snapshot_at_hire`, `reviews.reviewee_verification_snapshot`. |
| `lib/features/applications/data/datasources/application_remote_datasource.dart` | (1) Stamp `applied_when_verified_at` on apply when tradie has a verified licence. (2) Compute + stamp `verification_snapshot_at_hire` when status flips to `hired`. |
| `lib/features/reviews/data/datasources/review_remote_datasource.dart` | Copy `applications.verification_snapshot_at_hire` onto the new review at write time. |

### Flutter (new files)
- `lib/features/verification/domain/entities/verification.dart`
- `lib/features/verification/domain/repositories/verifications_repository.dart`
- `lib/features/verification/domain/usecases/{get_my_verifications,invoke_verify_abn,invoke_verify_licence}.dart`
- `lib/features/verification/data/models/verification_model.dart`
- `lib/features/verification/data/datasources/verifications_remote_datasource.dart`
- `lib/features/verification/data/repositories/verifications_repository_impl.dart`
- `lib/features/verification/presentation/providers/verifications_provider.dart`
- `lib/features/verification/presentation/pages/verification_wizard_page.dart`
- `lib/features/verification/presentation/widgets/{wizard_abn_step,wizard_licence_step,wizard_result_screen,verification_receipts,verification_nudge_banner,unverified_consent_dialog,job_card_poster_badge}.dart`
- `lib/features/reviews/presentation/widgets/review_card.dart`

### Flutter (changed files)
- `lib/features/profile/presentation/pages/profile_page.dart` — `_VerificationRow` block deleted; replaced with `VerificationReceipts(userId, isOwner: true, showLicenceRow: <role>)`.
- `lib/features/jobs/presentation/pages/jobs_page.dart` — `VerificationNudgeBanner` inserted between error banner and results count.
- `lib/core/design/widgets/job_card.dart` — optional `posterVerificationStatus` param.
- `lib/features/applications/presentation/pages/applications_page.dart` — `_VerifiedOnlyToggle` in header (builders only); switches to `filteredIncoming`; first-time tap of OFF launches `UnverifiedConsentDialog`.
- `lib/features/applications/presentation/providers/applications_provider.dart` — `verifiedOnlyFilter` state + `filteredIncoming` derived list + `setVerifiedOnlyFilter()`.
- `lib/features/reviews/presentation/pages/reviews_page.dart` — placeholder scaffold replaced with real list + `ReviewCard`.
- `lib/features/reviews/data/models/review_model.dart` + `lib/features/reviews/domain/entities/review.dart` — `VerificationSnapshot` value object on `Review`.
- `lib/app/router/app_router.dart` — `/verification/wizard` nested route.

### What was deliberately NOT built (planned for v1, dropped in v2)
- `pendingActionAfterVerifyProvider` — nothing is gated, no deep-link return.
- Apply-button gating in `job_detail_page.dart`.
- Post-button gating in `job_create_page.dart`.
- Hard-gate consent router lockout — consent moves into the wizard scope.

---

## 10. Phase 2 / Phase 3 punch list

Phase 2:
- Whitecard / SafeWork adapter
- Apprenticeship register adapter (federal AAPathways)
- VIC + QLD Fair Trading adapters
- Real NSW Fair Trading scraper (stub still routes deterministically today)
- Nightly proactive re-check cron
- Expiry cron + per-user-local-time 7-day push
- Asymmetric reporting thresholds (G2)
- Job-post rate limits on unverified builders (G4)
- Standalone "browse trades" directory

Phase 3:
- Remaining state adapters (SA, WA, TAS, ACT, NT)
- High Risk Work Licence adapter
- Asbestos Class A/B adapters
- Industry membership verification (MEA, NECA, etc.)
- Insurance verification (manual upload + admin review)
- Premium tier: priority queue, auto-rechecks, expiry SMS

---

## 11. The one risk that would kill this model

**Verification rate stays under 15% indefinitely.** Then the badge is meaningless because almost nobody has it, builders stop using the filter, and Jobdun becomes "Hipages without even the fake stamp."

Detection (Phase 2 — daily auto):
- Verification rate per cohort
- % of builders who use the filter ≥ once per week
- % of hires that go to verified workers
- Time-to-first-verification per cohort

Thresholds:
- < 15% at week 4 → review nudge copy / placement
- < 20% at week 12 → introduce caps (e.g. max 5 active applications for unverified tradies per week)
- Filter usage < 30% of active builders → improve filter UI prominence

We **do not** force verification by default. We watch metrics. If carrots aren't working, tighten gradually — never with a blanket gate.

---

## 12. Layman's analogy

Jobdun is a notice board. Every posting (tradie or builder) has a sticker showing exactly what's been checked. Some say *"✓ Business confirmed by the Australian Business Register"*. Some say *"✓ Electrical licence current with NSW Fair Trading, expires 2028."* Others say *"◯ Nothing has been checked yet."*

Both kinds are on the same board. Nobody got kicked off for not having stickers. The board is honest about who has them and who doesn't.

Anyone walking up to the board can flip a switch labelled *"only show me postings with green stickers."* Most do — that's the whole reason they came here instead of Facebook. Some flip it off — looking for a labour crew, a cheap quote, an apprentice rate. That's their call.

The other notice boards in town (Hipages, Oneflare) put green stickers on every posting whether they checked or not. Everyone there knows the stickers are mostly bullshit. Builders pretend to trust them; tradies pretend they mean something; everybody knows everybody's pretending.

Jobdun's deal: **no pretending.**
