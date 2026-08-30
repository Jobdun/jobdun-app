import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/app_typography.dart';
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
    // Figma `JobDun-Screens` → Homepage (node 140:13679): a bordered 16dp card,
    // three equal columns split by 35dp rules, the number in orange at 24 over
    // a 12px label. The old strip ran the numbers in primary ink at 18 — these
    // ARE the screen's headline, so the mock gives them the brand colour.
    return Container(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
        border: Border.all(color: c.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0)
                Center(
                  child: Container(width: 1, height: 35.h, color: c.border),
                ),
              Expanded(child: _DeckCell(cell: cells[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeckCell extends StatelessWidget {
  const _DeckCell({required this.cell});

  final DeckStripCell cell;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          cell.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.numeric(tt.titleMedium!).copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.2,
            // Orange as ink on the card ground → actionInk, not the fill token.
            color: c.actionInk,
          ),
        ),
        Gap(AppSpacing.xs.h),
        Text(
          cell.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: tt.bodySmall!.copyWith(
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
            height: 1.0,
            color: c.text1,
          ),
        ),
      ],
    );
  }
}
