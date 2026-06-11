import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_icons.dart';
import '../../domain/entities/trade_public_credential.dart';
import '../../domain/entities/verification_document.dart';
import '../providers/verifications_provider.dart';
import 'credential_detail_sheet.dart';
import 'trust_chip.dart';

/// Counterparty trust signals — compact "White Card" / "Insured" chips shown to
/// a builder evaluating a tradie. Reads the minimized public projection
/// (`tradePublicCredentialsProvider`) which only ever returns APPROVED
/// supplementary credentials — never the document, number, insurer, or state.
/// Renders nothing while loading or when there are none, so it's safe to drop
/// into any row without reserving space. Mirrors [BuilderVerifiedBadge].
///
/// U2: each chip opens a provenance sheet (what was checked, expiry, approval
/// date) so the badge is explorable, not a dead end.
class TradeCredentialBadges extends ConsumerWidget {
  const TradeCredentialBadges({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creds = ref
        .watch(tradePublicCredentialsProvider(userId))
        .asData
        ?.value;
    if (creds == null || creds.isEmpty) return const SizedBox.shrink();

    final chips = <Widget>[];
    for (final cred in creds) {
      final label = switch (cred.docType) {
        DocType.whiteCard => 'White Card',
        DocType.publicLiability => 'Insured',
        _ => null,
      };
      if (label == null) continue;
      chips.add(
        TrustChip(
          label: label,
          state: cred.isExpired
              ? TrustChipState.expired
              : TrustChipState.verified,
          onTap: () => _openDetail(context, cred),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    // 150ms fade so the async arrival doesn't pop into the header wrap. No
    // reserved space — absence must look identical to loading (privacy).
    // TweenAnimationBuilder (ticker-driven) rather than flutter_animate here:
    // Animate leaves a pending Timer that trips widget-test teardown.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Wrap(spacing: 6.w, runSpacing: 6.h, children: chips),
      builder: (_, t, child) => Opacity(opacity: t, child: child),
    );
  }

  void _openDetail(BuildContext context, TradePublicCredential cred) {
    final fmt = DateFormat('d MMM yyyy');
    final (title, blurb) = switch (cred.docType) {
      DocType.whiteCard => (
        'White Card (construction induction)',
        'Nationally required safety induction for construction site work.',
      ),
      DocType.publicLiability => (
        'Public liability insurance',
        'Insurance covering third-party injury and property damage caused '
            'by their work.',
      ),
      _ => (cred.docType.label, null),
    };
    showCredentialDetailSheet(
      context,
      title: title,
      blurb: blurb,
      rows: [
        (
          icon: cred.isExpired ? AppIcons.clock : AppIcons.verified,
          text: cred.isExpired ? 'Expired' : 'Verified by document review',
        ),
        if (cred.expiresAt != null)
          (
            icon: AppIcons.calendar,
            text: 'Expires ${fmt.format(cred.expiresAt!)}',
          ),
        if (cred.capturedAt != null)
          (
            icon: AppIcons.check,
            text: 'Approved ${fmt.format(cred.capturedAt!)}',
          ),
      ],
    );
  }
}
