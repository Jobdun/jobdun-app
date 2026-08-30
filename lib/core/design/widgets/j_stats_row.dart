import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../colors.dart';

/// One figure in [JStatsRow].
class JStat {
  const JStat({required this.value, required this.label, this.valueColor});

  /// Already formatted — the row does no number formatting of its own so a
  /// caller can pass an em dash for "not loaded yet" rather than a misleading
  /// zero.
  final String value;
  final String label;

  /// Overrides the default `c.action`. The builder profile (Figma node
  /// 134:8697) colours its three figures separately — orange / success /
  /// warning — where the home row (node 80:4639) runs all three orange.
  final Color? valueColor;
}

/// The three-up figure row drawn across the Figma refresh — Active /
/// Applicants / Posted on the builder home (node `80:4639`), Jobs Posted /
/// Hires / In-business on the builder profile (node `134:8697`). Equal columns
/// split by hairline rules inside a bordered r16 card.
///
/// The count is `c.action` at 24dp Bold. That is 3.34:1 on the card, which
/// clears WCAG's 3:1 large-text floor because 24dp Bold *is* large text — the
/// one place on this screen where the mock's literal orange survives the
/// contrast pass. Smaller orange text on these screens uses `c.actionInk`.
class JStatsRow extends StatelessWidget {
  const JStatsRow({super.key, required this.stats});

  final List<JStat> stats;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
        border: Border.all(color: c.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, color: c.border, indent: 0),
              Expanded(child: _StatCell(stat: stats[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.stat});

  final JStat stat;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      label: '${stat.value} ${stat.label}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stat.value,
            style: tt.headlineSmall!.copyWith(
              fontSize: 24,
              height: 1.2,
              color: stat.valueColor ?? c.action,
            ),
            maxLines: 1,
          ),
          Gap(4.h),
          Text(
            stat.label,
            style: tt.labelMedium!.copyWith(
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              color: c.text1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
