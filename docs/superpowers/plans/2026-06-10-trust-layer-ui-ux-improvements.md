# Trust Layer UI/UX Improvements (U1–U5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the five spec'd trust-layer upgrades (upload-sheet data quality, shared TrustChip + detail sheet, trust-hub reframe, admin SLA triage, expiry lifecycle) on `feat/trade-credentials-trust-layer`.

**Architecture:** Pure presentation-layer changes plus one domain getter (`TradePublicCredential.expiresSoon`) and one admin-provider sort. No DB/migration changes. New widgets (`TrustChip`, `CredentialDetailSheet`) live in `lib/features/verification/presentation/widgets/`, each in its own file per the one-widget-per-file rule.

**Tech Stack:** Flutter, Riverpod 3, flutter_screenutil, gap, flutter_animate, photo_view, showJSheet, JButton/JCard/JSkeletonList house components.

**Spec:** `docs/superpowers/specs/2026-06-10-trust-layer-ui-ux-improvements-design.md`

> **STATUS (2026-06-10): EXECUTED.** All tasks implemented inline same day —
> `validate.sh` fully green (design greps, architecture, format, analyze,
> `test/features/` 78 verification + admin 56 tests). One extra split forced by
> the 500-LOC ceiling: `ReceiptRow` + `ReceiptCtaLink` extracted from
> `verification_receipts.dart` into `receipt_row.dart` / `receipt_cta_link.dart`.
> Two flutter_animate usages were replaced with `TweenAnimationBuilder` because
> Animate leaves a pending Timer that fails widget-test teardown. Deferred items
> (U1.6 PDF, U5.3 push) remain open at the bottom.

**Scope deviation (recorded):** U1.6 (PDF upload for insurance) is **deferred** — it requires verifying the `private-docs` bucket MIME allowlist and the admin doc viewer's PDF behaviour against the live Supabase project, which can't be validated offline. Tracked as a follow-up at the bottom.

**Commits:** intentionally none — the branch carries the user's uncommitted trust-layer WIP in the same files; bundling fixes into commits would sweep that WIP. The user commits after testing.

---

### Task 1: U1.1 — Expiry validation in the manual upload sheet

**Files:**
- Modify: `lib/features/verification/presentation/widgets/manual_upload_sheet.dart`
- Modify: `lib/features/verification/presentation/widgets/manual_upload_form.dart`
- Test: `test/features/verification/presentation/manual_upload_expiry_test.dart` (new)

- [ ] **Step 1: Write failing test** — pump the sheet for `ManualDocKind.whiteCard` (harness copied from `manual_upload_insurer_test.dart`), assert the EXPIRES row exists; simulate UPLOAD press path by asserting that `_ExpiryRow` shows the error copy after a validation attempt. Because UPLOAD needs a picked file (can't pick in widget tests), test the extracted pure guard instead: `expiryMissing(kind, expiry)` returns true for whiteCard+null, false for abnCertificate+null and whiteCard+date — plus a widget assertion that the error text renders when `errorText` is passed to the row.

```dart
// pure guard in manual_upload_form.dart
bool expiryMissing(ManualDocKind kind, DateTime? expiry) =>
    kind.requiresExpiry && expiry == null;
```

- [ ] **Step 2: Implement** — in `_ManualUploadSheetState`: add `String? _expiryError;` and a `final _expiryKey = GlobalKey();`. In `_upload()` *before* the phone gate: `if (expiryMissing(widget.kind, _expiry)) { setState(_expiryError = ...); Scrollable.ensureVisible(_expiryKey.currentContext!...); return; }`. Clear in `_onPickExpiry` on pick. Pass `expiryError: _expiryError` + `key: _expiryKey` down through `ManualUploadActiveBody` → `_ExpiryRow` (new `errorText` param: border `c.urgent` when set, error line beneath in `bodySmall`/`c.urgent`). Error copy: `Required — this date drives your badge's expiry`.
- [ ] **Step 3: Run** `flutter test test/features/verification/presentation/manual_upload_expiry_test.dart` → PASS.

### Task 2: U1.2 — Human-readable upload errors

**Files:**
- Modify: `manual_upload_form.dart` (add `humanUploadError`), `manual_upload_sheet.dart` (use it)
- Test: `test/features/verification/presentation/human_upload_error_test.dart` (new)

- [ ] **Step 1: Failing test** — unit-test mapping: SocketException-ish (`'SocketException: Failed host lookup'`) → connection copy; `'413'`/`'exceeded the maximum allowed size'` → too-big copy; `'StorageException'` with 403 → refused copy; anything else → generic copy. Assert no output ever contains `Exception`.
- [ ] **Step 2: Implement**

```dart
String humanUploadError(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('socketexception') || s.contains('timeout') ||
      s.contains('failed host lookup') || s.contains('connection')) {
    return "Couldn't upload — check your connection and try again.";
  }
  if (s.contains('413') || s.contains('payload too large') ||
      s.contains('maximum allowed size') || s.contains('too large')) {
    return 'That file is too big — keep it under 10 MB.';
  }
  if (s.contains('403') || s.contains('unauthorized') || s.contains('jwt')) {
    return 'Upload was refused. Log out and back in, then retry.';
  }
  return 'Something went wrong. Try again in a minute.';
}
```

`_pick`/`_upload` catch blocks set `_error = humanUploadError(e)`; raw `e` goes into a funnel-log metadata field (`'manual_upload_error'` event).
- [ ] **Step 3: Run test** → PASS.

### Task 3: U1.3/4/5/7/8 — sheet conversion polish

**Files:** `manual_upload_form.dart`, `manual_upload_controls.dart`
- [ ] U1.3: in `ManualUploadPickerBlock`, when `pickedFile != null && !uploadEnabled && !uploading`, render under the button row: `Tick the declaration above to enable upload` (`bodySmall`, `c.text3`).
- [ ] U1.4: remove `label:` from the INSURER and document-number `JTextField`s (eyebrow `_Label` stays the single label).
- [ ] U1.5: wrap preview `Image.file` in `GestureDetector` → `Navigator.push` fullscreen `PhotoView(imageProvider: FileImage(...))` with `Hero(tag: 'verification:picked')`; caption `Tap to check it's readable` beneath.
- [ ] U1.7: `ManualUploadDoneBlock` icon gets `.animate().scale(duration: 180.ms, curve: Curves.easeOut).fadeIn(duration: 180.ms)`.
- [ ] U1.8: wrap attestation row content in `MergeSemantics`.
- [ ] Run existing sheet tests (`manual_upload_insurer_test.dart`, `manual_upload_trade_class_test.dart`, `manual_doc_kind_test.dart`) → PASS.

### Task 4: U2 — TrustChip + credential detail sheet

**Files:**
- Create: `lib/features/verification/presentation/widgets/trust_chip.dart`
- Create: `lib/features/verification/presentation/widgets/credential_detail_sheet.dart`
- Modify: `trade_credential_badges.dart` (use TrustChip + onTap + fadeIn), `applicant_detail_widgets.dart` (`_VBadge` → TrustChip; star → `c.star`), `applicant_detail_page.dart` (pass matched `Verification` rows down)
- Test: `test/features/verification/presentation/trust_chip_test.dart` (new); migrate assertions in `trade_credential_badges_test.dart` (texts unchanged → should stay green; add tap-opens-sheet test)

- [ ] **Step 1: TrustChip**

```dart
enum TrustChipState { verified, expired, placeholder }

class TrustChip extends StatelessWidget {
  const TrustChip({super.key, required this.label, required this.state, this.onTap});
  // verified → verifiedBg/verifiedTx + AppIcons.verified
  // expired  → surfaceRaised/text1  + AppIcons.clock + ' (expired)' suffix
  // placeholder → surface bg, border c.border, text3 + AppIcons.addCircle (preview-only, non-tappable)
  // Semantics(label: '<label>, verified credential|expired credential|not yet added', button: onTap != null)
  // radius AppRadius.chip.r, padding 7.w/3.h, labelSmall letterSpacing 0.4
}
```

- [ ] **Step 2: Detail sheet** — `showCredentialDetailSheet(context, {required String title, required List<(IconData, String)> rows, String? blurb})` → `showJSheet` with drag handle, `headlineSmall` title, icon+`bodyMedium` rows, optional `bodySmall`/`text3` blurb. Per-kind plain-language blurbs live with the callers (`trade_credential_badges.dart` for supplementary kinds; applicant header for licence/ABN).
- [ ] **Step 3: Wire** — `_CredChip` deleted; `TradeCredentialBadges` maps creds → `TrustChip(onTap: () => showCredentialDetailSheet(...))` with rows: status (`Verified by document review` / `Expired`), `Expires d MMM yyyy` when present, `Approved d MMM yyyy` from `capturedAt`; wrap result in `.animate().fadeIn(duration: 150.ms)`. `_VBadge` deleted; licence/ABN chips become `TrustChip`s — page passes the matched `Verification?` rows so taps open the sheet with the existing register/as-at subtitle strings (reuse logic copied into the header part-file as small helpers).
- [ ] **Step 4: Run** badges + new chip tests, `flutter analyze` → PASS.

### Task 5: U3 — trust-hub reframe + profile de-burying

**Files:**
- Modify: `verification_receipts.dart` (empty-row copy/icon, `_CtaLink` ≥48dp, U5 hooks land in Task 7), `verification_wizard_page.dart` (hub preview, count, skeleton, app-bar title), `profile_page_trade.dart` (reorder, drop Licence row)
- Test: extend `verification_wizard_trade_credentials_test.dart` (preview + count) and `verification_receipts_supplementary_test.dart` (empty copy); both existing assertions must stay green.

- [ ] **Step 1: receipts** — no-doc owner branch: icon `AppIcons.addCircle`, sub copy per kind (licence `Shows builders a LICENCE badge on your applications`; whiteCard `Proves you're site-ready — shown as a badge to builders`; publicLiability `Shows as INSURED on every application you send`). All four text CTAs route through a private `_CtaLink` (InkWell + `ConstrainedBox(minHeight: 44.h)` + vertical padding 12.h).
- [ ] **Step 2: hub** — `_TradeCredentialsStep` becomes `ConsumerWidget`; computes per-kind "added" (licence verified row OR approved/pending doc; whiteCard/publicLiability approved/pending doc) from `myVerificationsProvider` + `verificationControllerProvider.documents` (both already overridden in tests; do NOT watch `tradePublicCredentialsProvider` here). Renders: H1 (no w700 override) + `N OF 3 ADDED` eyebrow, intro copy, `HOW BUILDERS SEE YOU` `FieldLabel` + Wrap of `TrustChip`s (verified state for added, placeholder for missing: LICENCE / WHITE CARD / INSURED), caption `Badges appear on your applications the moment a reviewer approves them.`, then the receipts card. App bar title: `Credentials` for trades, `Verification` otherwise. Role-resolving loader: `JSkeletonList(child: ...)` two-row placeholder instead of `CircularProgressIndicator`.
- [ ] **Step 3: profile** — move `VerificationReceipts` block to directly after `ProfileAvailabilityBanner`; delete the `Licence / On file` `_InfoRow`.
- [ ] **Step 4: Run** wizard + receipts + reverify tests, `flutter analyze` → PASS.

### Task 6: U4 — admin SLA triage

**Files:**
- Modify: `admin_verifications_provider.dart` (sort), `admin_verification_queue_row.dart` (age chip + recolor + AppIcons), `admin_verifications_page.dart` (reviewed cap + AppIcons)
- Test: extend `test/admin/features/admin_verifications/admin_verification_filter_test.dart`

- [ ] **Step 1: failing tests** — `filteredItems` puts pending oldest-first and reviewed newest-first; age label thresholds via pure helper:

```dart
// admin_verification_queue_row.dart
enum QueueAge { fresh, warning, breached }
QueueAge queueAgeFor(Duration inQueue) => inQueue >= const Duration(hours: 24)
    ? QueueAge.breached
    : inQueue >= const Duration(hours: 18) ? QueueAge.warning : QueueAge.fresh;
```

- [ ] **Step 2: implement** — provider: sort inside `filteredItems` (pending asc by submittedAt before non-pending desc). Row: pending rows append `· Xh in queue` (fresh = caption `text3`; warning = `warningBg/warningTx` chip; breached = `urgentBg/urgentTx` chip `SLA BREACHED · Xh`); `_KindBadge`: whiteCard → `availableBg/availableTx`, publicLiability → `surfaceRaised`+`text1`. Page: `reviewed.take(50)` + `Showing latest 50` caption when truncated. Swap `Icons.chevron_right`→`AppIcons.chevronRight`, `Icons.warning_amber_rounded`→`AppIcons.warning` (refresh/inbox stay `Icons.*` — no catalogue entry).
- [ ] **Step 3: Run** admin tests → PASS.

### Task 7: U5 — expiry lifecycle

**Files:**
- Modify: `lib/features/verification/domain/entities/trade_public_credential.dart` (`expiresSoonAt(DateTime now)` + `expiresSoon` getter), `verification_receipts.dart` (owner soon/expired branches)
- Test: `test/features/verification/domain/entities/trade_public_credential_expiry_test.dart` (new, 29/30/31-day boundaries); extend `verification_receipts_supplementary_test.dart` (owner expired-doc row, expiring-soon row)

- [ ] **Step 1: entity**

```dart
bool expiresSoonAt(DateTime now) => !isExpired && expiresAt != null &&
    !expiresAt!.isBefore(now) && expiresAt!.difference(now) <= const Duration(days: 30);
bool get expiresSoon => expiresSoonAt(DateTime.now());
```

- [ ] **Step 2: receipts owner branches** in `_buildRow`, ordered: verified-row → approved doc: if `doc.isExpired || status == expired` → clock icon, `Expired on d MMM — builders no longer see this badge`, CTA `Upload a new one →`; elif approved within 30 d of expiry → `c.warning` clock, `Expires d MMM — upload a renewal to keep your badge`, same CTA; else verified-by-document-review row (unchanged). Also: a doc with `VerificationStatus.expired` (admin sweep) hits the expired branch via a `_findDoc(..., expired)` lookup.
- [ ] **Step 3: Run** entity + receipts tests → PASS.

### Task 8: Full verification

- [ ] `flutter analyze --no-fatal-infos` → 0 errors
- [ ] `flutter test test/features/verification test/admin` → PASS
- [ ] `bash scripts/validate.sh` → green (note pre-existing reds documented in memory: lib/features Colors.white + flaky widget tests — only NEW failures block)

### Deferred follow-up (out of this plan)

- **U1.6 PDF upload for insurance** — needs live checks: `private-docs` bucket MIME allowlist accepts `application/pdf`; admin `admin_verification_doc_viewer.dart` renders or download-links PDFs. Then: `file_picker` FILE action on the publicLiability sheet + doc-tile preview + datasource contentType.
- **U5.3 renewal push** — scheduled 30 d/7 d notification via the #18 producer pattern.
