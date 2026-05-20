import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:jobdun/app/theme/app_colors.dart';
import 'package:jobdun/core/design/widgets/j_card.dart';

import '_harness.dart';

void main() {
  group('JCard goldens (dark)', () {
    testWidgets('basic card with eyebrow + rows', (tester) async {
      await pumpGolden(
        tester,
        Builder(
          builder: (context) => JCard(
            title: 'COMPANY DETAILS',
            children: [
              _row(context, 'Company', 'Hammertime'),
              _row(context, 'ABN', '12 345 678 901'),
              _row(context, 'Location', 'Sydney'),
            ],
          ),
        ),
      );
      await expectLater(
        find.byType(JCard),
        matchesGoldenFile('goldens/j_card_basic.png'),
      );
    });

    testWidgets('JStatBadge row', (tester) async {
      await pumpGolden(
        tester,
        Row(
          children: const [
            JStatBadge(
              value: '4.9',
              label: 'Rating',
              icon: AppIcons.starFilled,
              iconColor: Color(0xFFF59E0B),
            ),
            SizedBox(width: 8),
            JStatBadge(
              value: '127',
              label: 'Jobs done',
              icon: AppIcons.briefcase,
              iconColor: Color(0xFFF97316),
            ),
            SizedBox(width: 8),
            JStatBadge(
              value: '8',
              label: 'Yrs exp',
              icon: AppIcons.clock,
              iconColor: Color(0xFF22C55E),
            ),
          ],
        ),
      );
      await expectLater(
        find.byType(Row),
        matchesGoldenFile('goldens/j_stat_badge_row.png'),
      );
    });
  });
}

Widget _row(BuildContext context, String label, String value) {
  final c = context.c;
  final tt = Theme.of(context).textTheme;
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: tt.bodyMedium!.copyWith(color: c.text2)),
        ),
        Text(value, style: tt.bodyMedium!.copyWith(color: c.text1)),
      ],
    ),
  );
}
