import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';

/// One cell of the [DeckStrip]: a value over an uppercase micro-label.
typedef DeckStripCell = ({String value, String label});

/// One-row stats micro-strip shared by both Action Decks (tradie + builder) —
/// the role's three key numbers at a quarter of the old tile height, so the
/// content below stays inside the first screenful. '—' means not-yet-loaded;
/// a real zero renders as 0 (dash ≠ zero).
class DeckStrip extends StatelessWidget {
  const DeckStrip({super.key, required this.cells});

  final List<DeckStripCell> cells;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) Container(width: 1, height: 26.h, color: c.border),
            Expanded(
              child: Column(
                children: [
                  Text(
                    cells[i].value,
                    style: tt.titleLarge!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.text1,
                    ),
                  ),
                  Gap(1.h),
                  Text(
                    cells[i].label,
                    style: tt.labelSmall!.copyWith(
                      letterSpacing: 0.6,
                      color: c.text3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
