import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/j_card.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/theme/app_icons.dart';
import '../../domain/entities/trade_public_credential.dart';
import '../../domain/entities/verification.dart';
import '../../domain/entities/verification_document.dart' as docs;
import '../providers/verification_provider.dart';
import '../providers/verifications_provider.dart';
import 'manual_upload_sheet.dart';
import 'receipt_cta_link.dart';
import 'receipt_row.dart';

/// "What's been checked" receipts panel. Lives on the profile page.
///
/// Renders three logical states:
///   - fully verified  → green check rows for every verified row
///   - partially verified → mixed; missing rows shown muted; "Verify in about
///     a minute →" CTA only when [isOwner] is true
///   - not verified    → single muted row "Not verified" + CTA (if owner)
class VerificationReceipts extends ConsumerWidget {
  const VerificationReceipts({
    super.key,
    required this.userId,
    required this.isOwner,
    this.showAbnRow = true,
    required this.showLicenceRow,
    this.showWhiteCardRow = false,
    this.showInsuranceRow = false,
  });

  /// The profile being viewed (own or someone else's).
  final String userId;

  /// True when the current user is looking at their own profile — only then
  /// do we show "Verify in about a minute →" CTAs.
  final bool isOwner;

  /// Builders verify ABN. Trades skip ABN entirely. Caller decides.
  final bool showAbnRow;

  /// Trades verify a licence. Builders skip licence. Caller decides.
  final bool showLicenceRow;

  /// Trades can add a White Card (construction induction). Trust signal only.
  final bool showWhiteCardRow;

  /// Trades can add public-liability insurance. Trust signal only.
  final bool showInsuranceRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(verificationsForUserProvider(userId));
    return async.when(
      loading: () => JSkeletonList(
        enabled: true,
        child: JCard(
          title: 'WHAT\'S BEEN CHECKED',
          children: const [
            ReceiptRow(
              icon: AppIcons.clock,
              label: 'Loading…',
              sub: 'Checking your records',
              isVerified: false,
            ),
            ReceiptRow(
              icon: AppIcons.clock,
              label: 'Loading…',
              sub: 'Checking your records',
              isVerified: false,
            ),
          ],
        ),
      ),
      error: (e, _) => JCard(
        title: 'WHAT\'S BEEN CHECKED',
        children: [
          ReceiptRow(
            icon: AppIcons.closeCircle,
            label: 'Couldn\'t load verification status',
            sub: '$e',
            isVerified: false,
          ),
        ],
      ),
      data: (rows) => _buildCard(context, ref, rows),
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    List<Verification> rows,
  ) {
    final abn = _findVerified(rows, VerificationKind.abn);
    final licence = showLicenceRow
        ? _findVerified(rows, VerificationKind.licence)
        : null;

    // Manual-upload state is owner-only (verification_documents has owner-only
    // RLS). Other viewers never see "Under review" — only regulator-confirmed
    // receipts. Skip the second watch when viewing someone else's profile.
    final uploaded = isOwner
        ? ref.watch(verificationControllerProvider).documents
        : const <docs.VerificationDocument>[];

    // White Card / public liability never create a `verifications` row, so a
    // counterparty reads their APPROVED state from the minimized projection.
    final publicCreds = (!isOwner && (showWhiteCardRow || showInsuranceRow))
        ? (ref.watch(tradePublicCredentialsProvider(userId)).asData?.value ??
              const <TradePublicCredential>[])
        : const <TradePublicCredential>[];

    return JCard(
      title: 'WHAT\'S BEEN CHECKED',
      children: [
        if (showAbnRow)
          _buildRow(
            context: context,
            label: 'Business (ABN)',
            verified: abn,
            verifiedSub: abn == null ? '' : _abnSubtitle(abn),
            docType: docs.DocType.abnCertificate,
            uploaded: uploaded,
          ),
        if (showLicenceRow)
          _buildRow(
            context: context,
            label: 'Trade licence',
            verified: licence,
            verifiedSub: licence == null ? '' : _licenceSubtitle(licence),
            docType: docs.DocType.tradeLicence,
            uploaded: uploaded,
          ),
        if (showWhiteCardRow)
          _buildSupplementaryRow(
            context: context,
            label: 'White Card',
            docType: docs.DocType.whiteCard,
            uploaded: uploaded,
            publicCreds: publicCreds,
          ),
        if (showInsuranceRow)
          _buildSupplementaryRow(
            context: context,
            label: 'Public liability',
            docType: docs.DocType.publicLiability,
            uploaded: uploaded,
            publicCreds: publicCreds,
          ),
      ],
    );
  }

  /// White Card / public liability are supplementary credentials: they have no
  /// `verifications` row, so the owner derives status from their uploaded docs
  /// while a counterparty sees only the APPROVED projection (owner-RLS hides
  /// pending / rejected docs). Counterparty rows are positive-only — nothing
  /// renders until a reviewer approves.
  Widget _buildSupplementaryRow({
    required BuildContext context,
    required String label,
    required docs.DocType docType,
    required List<docs.VerificationDocument> uploaded,
    required List<TradePublicCredential> publicCreds,
  }) {
    if (isOwner) {
      return _buildRow(
        context: context,
        label: label,
        verified: null,
        verifiedSub: '',
        docType: docType,
        uploaded: uploaded,
      );
    }
    TradePublicCredential? cred;
    for (final c in publicCreds) {
      if (c.docType == docType) {
        cred = c;
        break;
      }
    }
    if (cred == null) return const SizedBox.shrink();
    final expires = cred.expiresAt != null
        ? ' · expires ${DateFormat('d MMM yyyy').format(cred.expiresAt!)}'
        : '';
    return ReceiptRow(
      icon: cred.isExpired ? AppIcons.clock : AppIcons.verified,
      label: label,
      sub: cred.isExpired
          ? 'Expired$expires'
          : 'Verified by document review$expires',
      isVerified: !cred.isExpired,
    );
  }

  Widget _buildRow({
    required BuildContext context,
    required String label,
    required Verification? verified,
    required String verifiedSub,
    required docs.DocType docType,
    required List<docs.VerificationDocument> uploaded,
  }) {
    if (verified != null) {
      return ReceiptRow(
        icon: AppIcons.verified,
        label: label,
        sub: verifiedSub,
        isVerified: true,
        cta: isOwner ? _reverifyCta(context, docType) : null,
      );
    }
    final approved = _findDoc(
      uploaded,
      docType,
      docs.VerificationStatus.approved,
    );
    if (approved != null) {
      // U5.2: an approved doc whose expiry has passed is a lapsed badge —
      // say so and offer the renewal, instead of falling back to "not
      // verified" with no explanation.
      if (approved.isExpired) {
        return _expiredRow(context, label, docType, approved.expiryDate);
      }
      // U5.1: inside the 30-day renewal window — owner-only nudge; the
      // public badge stays verified until it actually lapses.
      if (_expiresSoon(approved.expiryDate)) {
        return ReceiptRow(
          icon: AppIcons.clock,
          iconColor: context.c.warning,
          label: label,
          sub:
              'Expires ${_fmtDate(approved.expiryDate!)} — upload a renewal '
              'to keep your badge',
          isVerified: false,
          cta: isOwner ? _renewalCta(context, docType) : null,
        );
      }
      return ReceiptRow(
        icon: AppIcons.verified,
        label: label,
        sub:
            'Verified by document review · '
            '${_relative(approved.submittedAt)}',
        isVerified: true,
      );
    }
    final pending = _findDoc(
      uploaded,
      docType,
      docs.VerificationStatus.pending,
    );
    if (pending != null) {
      return ReceiptRow(
        icon: AppIcons.clock,
        label: label,
        sub:
            'Under review · uploaded ${_relative(pending.submittedAt)}. '
            'A reviewer will confirm within 24 h.',
        isVerified: false,
      );
    }
    // U5.2: the expiry sweep flips lapsed docs to status=expired — keep the
    // "why" visible for the owner instead of a bare empty row.
    final expired = _findDoc(
      uploaded,
      docType,
      docs.VerificationStatus.expired,
    );
    if (expired != null && isOwner) {
      return _expiredRow(context, label, docType, expired.expiryDate);
    }
    // U3.1: a never-attempted credential is an opportunity, not a failure —
    // the owner gets an add-affordance glyph + the payoff the badge buys.
    // Counterparties keep the muted factual "Not yet verified".
    return ReceiptRow(
      icon: isOwner ? AppIcons.addCircle : AppIcons.closeCircle,
      label: label,
      sub: isOwner ? _payoffCopy(docType) : 'Not yet verified',
      isVerified: false,
      cta: isOwner ? _ownerCtas(context, docType) : null,
    );
  }

  // U5: lapsed-credential row — honest about the consequence (the badge is
  // gone from builder view) with the renewal as the next step.
  Widget _expiredRow(
    BuildContext context,
    String label,
    docs.DocType docType,
    DateTime? expiry,
  ) {
    final when = expiry == null ? '' : ' on ${_fmtDate(expiry)}';
    return ReceiptRow(
      icon: AppIcons.clock,
      label: label,
      sub: 'Expired$when — builders no longer see this badge',
      isVerified: false,
      cta: isOwner ? _renewalCta(context, docType) : null,
    );
  }

  static bool _expiresSoon(DateTime? expiry) {
    if (expiry == null) return false;
    final now = DateTime.now();
    return !expiry.isBefore(now) &&
        expiry.difference(now) <= const Duration(days: 30);
  }

  static String _fmtDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

  static Widget _renewalCta(BuildContext context, docs.DocType docType) {
    final kind = switch (docType) {
      docs.DocType.tradeLicence => ManualDocKind.tradeLicence,
      docs.DocType.whiteCard => ManualDocKind.whiteCard,
      docs.DocType.publicLiability => ManualDocKind.publicLiability,
      _ => ManualDocKind.abnCertificate,
    };
    return ReceiptCtaLink(
      label: 'Upload a new one →',
      onTap: () => showManualUploadSheet(context: context, kind: kind),
    );
  }

  // What the builder actually sees once this credential is approved — shown
  // on the owner's empty rows so the upload effort has a visible reward.
  static String _payoffCopy(docs.DocType docType) => switch (docType) {
    docs.DocType.abnCertificate =>
      'Shows tradies a verified-business badge on your job posts',
    docs.DocType.tradeLicence =>
      'Shows builders a LICENCE badge on your applications',
    docs.DocType.whiteCard =>
      "Proves you're site-ready — shown as a badge to builders",
    docs.DocType.publicLiability =>
      'Shows as INSURED on every application you send',
    _ => 'Adds a verified badge to your profile',
  };

  // B5: this CTA only renders in the "no doc at all" branch of `_buildRow`
  // (verified / approved / pending are all handled before it), so a user with
  // a pending upload sees the "Under review · …" row instead of an "Upload"
  // affordance — they can't open a second sheet from here. Keep that ordering
  // intact; it's the guard against duplicate pending uploads on this surface.
  static Widget _ownerCtas(BuildContext context, docs.DocType docType) {
    // ABN keeps the wizard CTA — its ABR auto-path IS live (roughly a minute) —
    // with a manual upload fallback beneath it.
    if (docType == docs.DocType.abnCertificate) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _wizardCta(context),
          ReceiptCtaLink(
            label: 'Or upload a document →',
            muted: true,
            underline: true,
            onTap: () => showManualUploadSheet(
              context: context,
              kind: ManualDocKind.abnCertificate,
            ),
          ),
        ],
      );
    }
    // Every other kind is manual-review only — a human reviews the upload,
    // usually within 24 h — so show one honest CTA that opens the sheet.
    final (kind, label) = switch (docType) {
      docs.DocType.tradeLicence => (
        ManualDocKind.tradeLicence,
        'Upload your licence →',
      ),
      docs.DocType.whiteCard => (
        ManualDocKind.whiteCard,
        'Upload your White Card →',
      ),
      docs.DocType.publicLiability => (
        ManualDocKind.publicLiability,
        'Add your insurance →',
      ),
      _ => (ManualDocKind.tradeLicence, 'Upload a document →'),
    };
    return ReceiptCtaLink(
      label: label,
      onTap: () => showManualUploadSheet(context: context, kind: kind),
    );
  }

  static docs.VerificationDocument? _findDoc(
    List<docs.VerificationDocument> list,
    docs.DocType type,
    docs.VerificationStatus status,
  ) {
    for (final d in list) {
      if (d.docType == type && d.status == status) return d;
    }
    return null;
  }

  static Verification? _findVerified(
    List<Verification> rows,
    VerificationKind kind,
  ) {
    for (final r in rows) {
      if (r.kind == kind && r.isVerified) return r;
    }
    return null;
  }

  static String _abnSubtitle(Verification v) {
    final entity = v.abnEntityName?.trim();
    final prefix = entity?.isNotEmpty == true ? '$entity · ' : '';
    final gst = v.gstRegistered == true ? ' · GST registered' : '';
    return '${prefix}Australian Business Register$gst${_asAt(v)}';
  }

  static String _licenceSubtitle(Verification v) {
    final state = v.licenceState ?? '';
    final reg = state.isNotEmpty ? '$state Fair Trading' : 'state regulator';
    final expires = v.expiresAt != null
        ? ' · expires ${DateFormat('d MMM yyyy').format(v.expiresAt!)}'
        : '';
    return 'Checked against $reg\'s public register${_asAt(v)}$expires';
  }

  // Snapshot freshness: a verification is true only "as at" the moment it was
  // captured — a business can be cancelled the day after. Always render the
  // as-at date next to a verified row; never a bare "Verified". Falls back to
  // verifiedAt for rows captured before detail_captured_at existed.
  static String _asAt(Verification v) {
    final at = v.detailCapturedAt ?? v.verifiedAt;
    return at == null ? '' : ' · as at ${DateFormat('d MMM yyyy').format(at)}';
  }

  // Owner-only re-verify affordance on an already-verified row. ABN re-runs the
  // ABR wizard; licence re-opens the manual upload sheet. Both carry the
  // explicit re-verify intent so the wizard doesn't short-circuit the
  // already-verified row straight back out (B3) — without `?reverify=1` the
  // ABN CTA used to dead-end on a "you're already verified" snackbar.
  static Widget _reverifyCta(BuildContext context, docs.DocType docType) {
    final isLicence = docType == docs.DocType.tradeLicence;
    return ReceiptCtaLink(
      label: 'Re-verify →',
      muted: true,
      onTap: () => isLicence
          ? showManualUploadSheet(
              context: context,
              kind: ManualDocKind.tradeLicence,
            )
          : context.push('/verification/wizard?reverify=1'),
    );
  }

  static String _relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    if (d.inDays < 30) return '${d.inDays} d ago';
    return DateFormat('d MMM yyyy').format(t);
  }

  static Widget _wizardCta(BuildContext context) {
    return ReceiptCtaLink(
      label: 'Verify in about a minute →',
      onTap: () => context.push('/verification/wizard'),
    );
  }
}
