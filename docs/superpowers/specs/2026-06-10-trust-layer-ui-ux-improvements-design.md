# Trust Layer UI/UX Improvements — Design Spec

> **Date:** 2026-06-10 · **Status:** awaiting user review (not yet approved)
> **Source audit:** `docs/TRUST_LAYER_UI_UX_AUDIT.md`
> **Branch context:** builds on `feat/trade-credentials-trust-layer` (uncommitted). No DB
> schema changes required except where flagged in U5; migration `20260609000003` is
> untouched.

## Goals

1. Protect badge truth: nothing reaches review with data the badge logic can't honour.
2. Convert more trades: show the payoff before asking for documents.
3. Make badges defensible to builders: provenance one tap away.
4. Make the 24 h review promise operable by the admin.
5. Keep trust signals alive past approval (expiry lifecycle).

## Non-goals

- No automated verification claims anywhere ("checked against a regulator" stays banned
  while `AUTO_VERIFY_ENABLED` is false).
- No ABN capture for trades (marketplace posture decision, 2026-06-09).
- No new public data exposure: the counterparty projection stays positive-only and
  minimized (doc type + expiry + status; never number/insurer/document).
- Admin review-dialog→route migration stays deferred (tracked separately).

## Sequencing

| Order | Upgrade | Size | Reason |
|-------|---------|------|--------|
| 1 | U1 Upload-sheet data-quality & conversion pass | M | Bug-adjacent; everything downstream trusts its output |
| 2 | U2 Shared `TrustChip` + explorable badges | M | Component foundation U3 reuses |
| 3 | U3 Trust-hub reframe + profile de-burying | M | Highest funnel impact; needs U2's chip for the preview |
| 4 | U4 Admin SLA triage | S | Independent; admin-web only |
| 5 | U5 Expiry lifecycle | S (UI) + M (push, later) | Depends on U1's expiry guarantee |

Each upgrade is independently shippable; run `bash scripts/validate.sh` per slice and use
TDD per house process (`superpowers:test-driven-development`).

---

## U1 — Manual upload sheet: data-quality & conversion pass

**Files:** `manual_upload_sheet.dart`, `manual_upload_form.dart`, `manual_upload_controls.dart`

### U1.1 Expiry validation (🔴)

- New state in `_ManualUploadSheetState`: `String? _expiryError`.
- On UPLOAD: if `widget.kind.requiresExpiry && _expiry == null`, set
  `_expiryError = 'Required — this date drives your badge\'s expiry'`, abort upload,
  and scroll the expiry row into view (`Scrollable.ensureVisible` on a `GlobalKey`).
- `_ExpiryRow` gains `errorText` param: border flips to `c.urgent`, error renders beneath
  in `bodySmall` + `c.urgent` (same pattern as `JTextField`'s reserved error slot).
- Picking a date clears the error.
- Disallow approval-side nulls later (admin confirm-fields already capture dates); client
  validation is the contract for now.

*Alternative considered:* move expiry into `FormBuilderDateTimePicker` so the form owns
validation. Rejected — the custom row + native `showDatePicker` is already built and
matches the input spec; adding a second date-picker idiom costs consistency.

### U1.2 Human-readable errors (🔴)

- Add `String humanUploadError(Object e)` (small pure helper, unit-testable, lives in
  `manual_upload_form.dart` or a sibling): 
  - network/socket/timeout → `Couldn't upload — check your connection and try again.`
  - payload-too-large / file-size → `That file is too big — keep it under 10 MB.`
  - storage/permission → `Upload was refused. Log out and back in, then retry.`
  - fallback → `Something went wrong. Try again in a minute.`
- Raw `e` keeps flowing to the funnel logger metadata for diagnosis; the user never sees it.
- Applies to `_pick` and `_upload` catch blocks.

### U1.3 Disabled-UPLOAD cause (🟠)

- When `pickedFile != null && !attested`, render one caption line under the button row:
  `Tick the declaration above to enable upload` (`bodySmall`, `c.text3`).
- Keep the disable behaviour (don't switch to enabled-then-error); the helper makes the
  gate legible without letting an unattested submit exist even transiently.

### U1.4 Single labels (🟠)

- Wherever an eyebrow `_Label` precedes a `JTextField`, pass `label: null` to the field
  (JTextField supports this explicitly for shared-label layouts). Keep hints.
- Eyebrow remains the house `FieldLabel` style — it's the pattern; the field label was
  the duplicate.

### U1.5 Zoomable preview (🟡)

- Wrap the picked-image preview in `GestureDetector` → full-screen `PhotoView` with
  `Hero(tag: 'verification:picked')`, per the house image-viewer rule.
- Caption under preview: `Tap to check it's readable` (`bodySmall`, `c.text3`) — closes
  the loop with the "no glare" priming bullet.

### U1.6 PDF for insurance (🟠)

- `ManualDocKind.publicLiability` only: add a third picker action `FILE` (uses
  `file_picker`, already a dependency; filter `pdf`).
- Preview for a PDF: document tile (AppIcons doc glyph + filename + size), not an image.
- Upload path: `uploadDocument` already takes a `File`; verify the
  `verification-documents` bucket accepts `application/pdf` and the admin doc viewer can
  render or download it. **If the viewer can't render PDFs, ship the admin download
  affordance in the same slice — a reviewer who can't open the doc is a hard blocker.**
- Update priming bullet: `JPG, PNG, WebP, HEIC — or PDF for insurance — up to 10 MB`.

### U1.7 Success moment (🟡)

- `ManualUploadDoneBlock`: animate the verified icon `.animate().scale(150ms).fadeIn(150ms)`
  (ease, no bounce — MASTER motion rules). Keep copy as-is ("Sent for review" + SLA).

### U1.8 Attestation semantics (🟡)

- Wrap the attestation row in `MergeSemantics` so checkbox + claim read as one node;
  add `Semantics(checked:)` is inherited from `Checkbox` — verify with TalkBack.

**Tests:** widget tests for expiry-block (upload refused, error shown, cleared on pick),
error mapping unit tests, disabled-helper visibility, PDF tile rendering for insurance
kind, label renders exactly once per field.

---

## U2 — Shared `TrustChip` + explorable badges (builder side)

**Files:** new `lib/features/verification/presentation/widgets/trust_chip.dart`;
refactor `trade_credential_badges.dart`, `applicant_detail_widgets.dart` (`_VBadge`).

### U2.1 One chip component

```dart
TrustChip(
  label: 'White Card',        // rendered uppercase via transform
  state: TrustChipState.verified | .expired,
  onTap: ...,                  // null = static
)
```

- Visual: current `_CredChip` spec (verified pair / neutral-expired pair, micro icon,
  `labelSmall`), radius `AppRadius.chip.r` (token, not raw 6).
- Replaces `_VBadge` and `_CredChip`. Licence/ABN/Verified chips in the applicant header
  become `TrustChip`s too.
- `Semantics(label: '<label>, verified credential' / '<label>, expired credential',
  button: onTap != null)` baked into the component so every call site is covered.

### U2.2 Tap → credential detail sheet

- Tapping any `TrustChip` in applicant detail opens `showJSheet` with:
  - Title: full credential name (`White Card (construction induction)` /
    `Public liability insurance` / `Trade licence` / `Business (ABN)`).
  - Status row: `Verified by document review` (supplementary) or the existing
    register/as-at subtitle (licence/ABN — reuse `VerificationReceipts` subtitle logic).
  - Expiry row when present: `Expires 12 Mar 2027`.
  - One plain-language line per kind, e.g. White Card: `Nationally required safety
    induction for construction site work.`
  - Nothing else — no numbers, no insurer, no document (projection stays minimized).
- Data: `TradePublicCredential` already carries `docType / expiresAt / isExpired`.
  If a "verified on" date is wanted in the sheet, extend the projection RPC with
  `reviewed_at` — **optional, flag at implementation; do not block on it.**

*Alternative considered:* long-press `Tooltip`. Rejected — undiscoverable on touch,
invisible to screen readers in practice, and can't carry three rows of provenance.

### U2.3 Arrival polish

- `TradeCredentialBadges` wraps its chips in `.animate().fadeIn(150ms)` to soften the
  async pop-in (no reserved space — privacy means absence must look identical to loading).
- Applicant-header star icon: `c.warning` → `c.star`.

**Tests:** golden/widget test for both chip states; sheet opens with correct rows per
kind; semantics label assertions (`tester.getSemantics`); existing
`trade_credential_badges_test.dart` migrated to `TrustChip`.

---

## U3 — Trust-hub reframe + profile de-burying (trade side)

**Files:** `verification_receipts.dart`, `verification_wizard_page.dart`,
`profile_page_trade.dart`

### U3.1 Positive empty rows

- In `_buildRow`'s "no doc at all" branch (owner view): icon `AppIcons.addCircle`
  (`c.text3`) instead of `closeCircle`; sub copy becomes the payoff per kind:
  - Licence → `Shows builders a LICENCE badge on your applications`
  - White Card → `Proves you're site-ready — shown as a badge to builders`
  - Public liability → `Shows as INSURED on every application you send`
- Counterparty view unchanged (it already renders nothing for missing supplementary
  creds, and "Not yet verified" stays correct for licence/ABN rows builders can see).
- "Not yet verified" remains for **rejected/expired-then-missing** owner rows? No —
  rejection surfacing is out of scope here (owner doc list already covers it); the
  add-state copy above is unconditional for the no-doc branch.

### U3.2 ≥48 dp CTAs

- All bare-text CTAs in receipts (`Upload your licence →`, `Re-verify →`,
  `Or upload a document →`, `Verify in about a minute →`): keep the link look, but pad
  the `InkWell` to `minHeight: 44.h` with `EdgeInsets.symmetric(vertical: 12.h)` and
  set `visualDensity`-equivalent hit area ≥ 48 dp.

### U3.3 "How builders see you" preview

- New private widget on the credentials hub (`_TradeCredentialsStep`), under the intro
  copy, above the receipts card:
  - `FieldLabel('HOW BUILDERS SEE YOU')`
  - A row of `TrustChip`s rendering the user's **current approved** supplementary creds,
    plus ghost-free placeholders for missing ones (muted `surface` chip, `addCircle`
    micro icon, e.g. `WHITE CARD` in `c.text3`) — placeholders are *not* buttons; the
    receipts rows below remain the action surface.
  - Caption: `Badges appear on your applications the moment a reviewer approves them.`
- Progress: hub header gains `N OF 3 ADDED` as a `labelSmall` eyebrow next to
  "Your credentials" (count = approved + under-review supplementary/licence docs). No
  progress bar — three items don't earn one.

### U3.4 Profile ordering + single licence truth

- `profile_page_trade.dart`: move `VerificationReceipts` to directly after
  `ProfileAvailabilityBanner` (before ABOUT), per the profile-dashboard override layout.
- Remove the self-declared `Licence: On file` row from TRADE DETAILS (`hasLicence`).
  The receipts card two blocks up is the only licence statement on the page.
- Wizard hub loading: replace the bare `CircularProgressIndicator` with `JSkeletonList`
  wrapping the hub layout (title line + receipts skeleton — the receipts loading state
  already exists and can be reused).
- App bar title for the trade hub: `Credentials` (builders keep `Verification`); drop
  the w700 override on the H1 (use `headlineMedium` as-is).

**Tests:** profile golden/order test (receipts before ABOUT, no licence row in details);
hub shows preview chips + count; empty-row copy per kind; CTA hit-target test
(`tester.getRect` ≥ 48 logical px tall).

---

## U4 — Admin queue: SLA triage

**Files:** `admin_verifications_provider.dart`, `admin_verification_queue_row.dart`

### U4.1 Time-in-queue aging

- Pending rows replace `submitted 9 Jun 2026 · 14:02` with both signals:
  `submitted 9 Jun · 14:02 — 22 h in queue`.
- Age chip thresholds (pending only): < 18 h → plain `c.text3` text; ≥ 18 h →
  `warningBg/warningTx` chip; ≥ 24 h → `urgentBg/urgentTx` chip labelled `SLA BREACHED`.
- Thresholds as consts next to the widget; no config plumbing.

### U4.2 Oldest-first

- Provider sorts pending ascending by `submittedAt` (oldest at top); reviewed stays
  newest-first. Sort lives in `filteredItems` so all filters inherit it.

### U4.3 Amber collision fix

- `_KindBadge`: WHITE CARD `warningBg/warningTx` → `availableBg/availableTx` (blue);
  INSURANCE `availableBg/availableTx` → `surfaceRaised`/`text1` (neutral). Amber is
  hereafter status-only in the queue.

### U4.4 Housekeeping (same slice, cheap)

- Swap raw `Icons.*` for `AppIcons.*` equivalents where the catalogue has them.
- REVIEWED section caps at the latest 50 with a `Showing latest 50` caption
  (`AdminText.caption(c.text3)`); real pagination deferred.

**Tests:** extend `admin_verification_filter_test.dart` — pending sort order; age-chip
threshold rendering at 17 h/19 h/25 h (inject clock or compute from fixture
`submittedAt`); kind-badge colour pairs.

---

## U5 — Expiry lifecycle

**Files:** `trade_public_credential.dart`, `verification_receipts.dart`,
`trust_chip.dart`; backend follow-up separate.

### U5.1 "Expiring soon" (≤ 30 days)

- `TradePublicCredential.expiresSoon` getter: `!isExpired && expiresAt != null &&
  expiresAt.difference(now) <= 30 days`. (Inject `now` for testability — entity stays
  pure Dart.)
- Owner receipts row: amber clock (`c.warning`) +
  `Expires 12 Mar — upload a renewal to keep your badge` + the upload CTA re-appears
  (renewal path = same sheet; B5 pending-guard still applies once they submit).
- Counterparty surfaces **unchanged** until actual expiry — the public signal must not
  degrade early; the nudge is owner-only.

### U5.2 Owner expired row

- Today an expired doc falls through to "Not yet verified". New branch in `_buildRow`
  (owner only): if the newest doc for the kind has `VerificationStatus.expired` (or
  approved-with-past-expiry), render clock icon + `Expired on 12 Mar — builders no
  longer see this badge` + `Upload a new one →` CTA.

### U5.3 Renewal push (backend follow-up — separate slice)

- Scheduled job (pg_cron or edge cron) emits a notification 30 d and 7 d before
  `expiry_date` on approved docs, through the #18 push-producer pattern. UI work above
  does not depend on it; listed so the lifecycle has an end-to-end owner.

**Tests:** `expiresSoon` boundary unit tests (29/30/31 d, null expiry); owner receipts
golden for soon/expired branches; counterparty unchanged at `expiresSoon`.

---

## Open questions (flagged, defaults chosen)

1. **Attestation tone** — current copy threatens "law enforcement" at the conversion
   point. Default: keep (legal anchor outweighs friction); revisit if funnel data shows
   drop-off at the attestation step.
2. **CAMERA vs GALLERY primacy** — GALLERY is currently the filled primary. Default:
   keep; most credential photos already exist in the camera roll.
3. **`reviewed_at` in the public projection** (U2.2) — only if the detail sheet feels
   thin without it; requires touching the RPC + model + migration.

## Verification before completion

Per slice: `bash scripts/validate.sh` (design greps + format + analyze + tests) and
`bash scripts/check-architecture.sh`. UI slices need screenshots in the PR per repo
policy. New widgets stay under the 400/500 LOC budget — `TrustChip` and the detail
sheet are separate files from day one.
