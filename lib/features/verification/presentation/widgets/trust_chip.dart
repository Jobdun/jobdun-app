import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/theme/app_icons.dart';

/// Visual state of a [TrustChip].
enum TrustChipState {
  /// Current, reviewer-approved credential — the green verified pair.
  verified,

  /// Lapsed credential — neutral pair + "(expired)" suffix, never colour-only.
  expired,

  /// Preview-only ghost on the owner's "How builders see you" strip: the
  /// credential hasn't been added yet. Never tappable, never counterparty-
  /// visible.
  placeholder,
}

/// The one verified-credential pill (U2). Replaces the near-identical
/// `_VBadge` (applicant detail) and `_CredChip` (trade credential badges) so
/// the trust visual can't drift between surfaces. Carries its own [Semantics]
/// so every call site reads correctly to screen readers.
class TrustChip extends StatelessWidget {
  const TrustChip({
    super.key,
    required this.label,
    required this.state,
    this.onTap,
  });

  /// Sentence-case credential name ('White Card', 'Insured', 'Licence').
  /// Rendered uppercase by the chip — don't pre-uppercase.
  final String label;

  final TrustChipState state;

  /// When set the chip opens its provenance (credential detail sheet).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final (Color bg, Color fg, IconData icon) = switch (state) {
      TrustChipState.verified => (
        c.verifiedBg,
        c.verifiedTx,
        AppIcons.verified,
      ),
      TrustChipState.expired => (c.surfaceRaised, c.text1, AppIcons.clock),
      TrustChipState.placeholder => (c.surface, c.text3, AppIcons.addCircle),
    };
    final text = state == TrustChipState.expired ? '$label (expired)' : label;
    final semantics = switch (state) {
      TrustChipState.verified => '$label, verified credential',
      TrustChipState.expired => '$label, expired credential',
      TrustChipState.placeholder => '$label, not yet added',
    };

    final chip = Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.chip.r),
        border: state == TrustChipState.placeholder
            ? Border.all(color: c.border)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.micro.r, color: fg),
          Gap(3.w),
          Text(
            text.toUpperCase(),
            style: tt.labelSmall!.copyWith(letterSpacing: 0.4, color: fg),
          ),
        ],
      ),
    );

    return Semantics(
      label: semantics,
      button: onTap != null,
      child: ExcludeSemantics(
        child: onTap == null
            ? chip
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadius.chip.r),
                child: chip,
              ),
      ),
    );
  }
}
