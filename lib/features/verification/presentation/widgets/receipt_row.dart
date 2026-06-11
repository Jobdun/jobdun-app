import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';

/// One line of the "What's been checked" receipts card: status glyph,
/// credential label, status subtitle, and an optional CTA beneath.
/// Extracted from `verification_receipts.dart` (500-LOC ceiling).
class ReceiptRow extends StatelessWidget {
  const ReceiptRow({
    super.key,
    required this.icon,
    required this.label,
    required this.sub,
    required this.isVerified,
    this.iconColor,
    this.cta,
  });

  final IconData icon;
  final String label;
  final String sub;
  final bool isVerified;

  /// Overrides the verified/muted default — the expiring-soon row uses
  /// warning amber (caution ≠ error, caution ≠ muted).
  final Color? iconColor;

  final Widget? cta;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: AppIconSize.md.r,
            color: iconColor ?? (isVerified ? c.verified : c.text3),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: tt.titleSmall!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.text1,
                  ),
                ),
                Gap(2.h),
                Text(sub, style: tt.bodySmall),
                ?cta,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
