import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/design/colors.dart';

/// U3.2: the one text-link CTA used inside receipt rows. Keeps the link look
/// but pads the hit area to the 48dp floor MASTER enforces on buttons —
/// the old bare `InkWell(Text)` rows were ~30dp tall.
/// Extracted from `verification_receipts.dart` (500-LOC ceiling).
class ReceiptCtaLink extends StatelessWidget {
  const ReceiptCtaLink({
    super.key,
    required this.label,
    required this.onTap,
    this.muted = false,
    this.underline = false,
  });

  final String label;
  final VoidCallback onTap;

  /// True for secondary links (re-verify, "or upload") — text3 + bodySmall.
  final bool muted;

  final bool underline;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final base = muted ? tt.bodySmall! : tt.bodyMedium!;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 48.h),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Text(
              label,
              style: base.copyWith(
                fontWeight: FontWeight.w600,
                color: muted ? c.text3 : c.action,
                decoration: underline ? TextDecoration.underline : null,
                decorationColor: underline ? c.text3 : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
