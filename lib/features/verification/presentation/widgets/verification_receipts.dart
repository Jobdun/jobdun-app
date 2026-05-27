import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/j_card.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/theme/app_icons.dart';
import '../../domain/entities/verification.dart';
import '../../domain/entities/verification_document.dart' as docs;
import '../providers/verification_provider.dart';
import '../providers/verifications_provider.dart';
import 'manual_upload_sheet.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(verificationsForUserProvider(userId));
    return async.when(
      loading: () => JSkeletonList(
        enabled: true,
        child: JCard(
          title: 'WHAT\'S BEEN CHECKED',
          children: const [
            _ReceiptRow(
              icon: Icons.circle,
              label: 'Loading…',
              sub: 'Checking your records',
              isVerified: false,
            ),
            _ReceiptRow(
              icon: Icons.circle,
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
          _ReceiptRow(
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
      ],
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
      return _ReceiptRow(
        icon: AppIcons.verified,
        label: label,
        sub: verifiedSub,
        isVerified: true,
      );
    }
    final approved = _findDoc(
      uploaded,
      docType,
      docs.VerificationStatus.approved,
    );
    if (approved != null) {
      return _ReceiptRow(
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
      return _ReceiptRow(
        icon: AppIcons.clock,
        label: label,
        sub:
            'Under review · uploaded ${_relative(pending.submittedAt)}. '
            'A reviewer will confirm within 24 h.',
        isVerified: false,
      );
    }
    return _ReceiptRow(
      icon: AppIcons.closeCircle,
      label: label,
      sub: 'Not yet verified',
      isVerified: false,
      cta: isOwner ? _ownerCtas(context, docType) : null,
    );
  }

  static Widget _ownerCtas(BuildContext context, docs.DocType docType) {
    final manualKind = docType == docs.DocType.tradeLicence
        ? ManualDocKind.tradeLicence
        : ManualDocKind.abnCertificate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _wizardCta(context),
        InkWell(
          onTap: () =>
              showManualUploadSheet(context: context, kind: manualKind),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h),
            child: Text(
              'Or upload a document →',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: context.c.text3,
                decoration: TextDecoration.underline,
                decorationColor: context.c.text3,
              ),
            ),
          ),
        ),
      ],
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
    final checked = v.verifiedAt != null
        ? _relative(v.verifiedAt!)
        : 'recently';
    final prefix = entity?.isNotEmpty == true ? '$entity · ' : '';
    return '${prefix}Checked against the Australian Business Register · $checked';
  }

  static String _licenceSubtitle(Verification v) {
    final state = v.licenceState ?? '';
    final reg = state.isNotEmpty ? '$state Fair Trading' : 'state regulator';
    final checked = v.verifiedAt != null
        ? _relative(v.verifiedAt!)
        : 'recently';
    final expires = v.expiresAt != null
        ? ' · expires ${DateFormat('d MMM yyyy').format(v.expiresAt!)}'
        : '';
    return 'Checked against $reg\'s public register · $checked$expires';
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
    return InkWell(
      onTap: () => context.push('/verification/wizard'),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Text(
          'Verify in about a minute →',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: context.c.action,
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.isVerified,
    this.cta,
  });

  final IconData icon;
  final String label;
  final String sub;
  final bool isVerified;
  final Widget? cta;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.r, color: isVerified ? c.verified : c.text3),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: c.text1,
                  ),
                ),
                Gap(2.h),
                Text(
                  sub,
                  style: TextStyle(fontSize: 12.sp, color: c.text2),
                ),
                ?cta,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
