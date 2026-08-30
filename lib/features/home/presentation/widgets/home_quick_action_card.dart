import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';

/// One half of the two-up action pair at the foot of the Figma **Homepage**
/// (nodes `83:4993` / `83:4998`) — "Find a Tradie" and "Applicants".
///
/// Icon, then a bold title over a muted one-line description. The pair sits in
/// a `Row` of two `Expanded`s, so both cards adopt the taller of the two
/// descriptions and stay aligned when one wraps to a second line.
class HomeQuickActionCard extends StatelessWidget {
  const HomeQuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '$title. $description',
      excludeSemantics: true,
      child: Material(
        color: c.card,
        clipBehavior: Clip.antiAlias,
        // `shape` carries radius AND border side together — Material asserts
        // that `shape` and `borderRadius` are mutually exclusive.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 24.r, color: c.actionInk),
                Gap(8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: tt.titleMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: c.text1,
                        ),
                      ),
                      Gap(4.h),
                      Text(
                        description,
                        style: tt.bodyMedium!.copyWith(
                          height: 1.4,
                          color: c.text2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
