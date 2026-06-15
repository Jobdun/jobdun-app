import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';

/// "Three things we won't do." — a single dense row of three short
/// value-props. Each block is a bold one-liner + a one-sentence
/// qualifier. The whole strip reads as the inside cover of a
/// job-site clipboard, not a feature grid.
///
/// No section header above it. The strip is its own statement.
class ValuesStrip extends StatelessWidget {
  const ValuesStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final w = MediaQuery.sizeOf(context).width;
    final stacked = w < 900;

    const items = [
      _Value(
        label: 'No subscription.',
        body: 'Builders post jobs. Trades apply. There is no monthly fee '
            'and no "premium" tier that unlocks real features.',
      ),
      _Value(
        label: 'No take rate.',
        body: "We don't skim a cut off your pay. The job pays what you "
            'agreed, and that is the whole story.',
      ),
      _Value(
        label: 'No anonymous operators.',
        body: 'Every account is checked at sign-up. Anonymous profiles '
            'do not exist on Jobdun.',
      ),
    ];

    return Container(
      width: double.infinity,
      color: c.background,
      padding: EdgeInsets.symmetric(
        horizontal: _hPad(w),
        vertical: AppSpacing.xxl.h,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cross = stacked ? 1 : 3;
              return Wrap(
                spacing: AppSpacing.xl.w,
                runSpacing: AppSpacing.xl.h,
                children: items
                    .map(
                      (it) => SizedBox(
                        width: stacked
                            ? double.infinity
                            : (constraints.maxWidth - AppSpacing.xl.w * (cross - 1)) / cross,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Short orange tick — sits above the label
                            // and reads as a "yes, this" affirmation.
                            Container(
                              width: 28.w,
                              height: 3.h,
                              color: c.action,
                            ),
                            Gap(AppSpacing.md.h),
                            Text(
                              it.label,
                              style: tt.titleLarge!.copyWith(
                                color: c.text1,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Gap(AppSpacing.xs.h),
                            Text(
                              it.body,
                              style: tt.bodyMedium!.copyWith(
                                color: c.text2,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ),
    );
  }

  double _hPad(double w) {
    if (w >= 1100) return AppSpacing.xxl.w;
    if (w >= 720) return AppSpacing.xl.w;
    return AppSpacing.lg.w;
  }
}

class _Value {
  const _Value({required this.label, required this.body});
  final String label;
  final String body;
}
