import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_colors.dart';
import 'package:jobdun/core/design/widgets/j_chip.dart';

import '_harness.dart';

void main() {
  group('JChip goldens (dark)', () {
    testWidgets('default — orange/white identity chip', (tester) async {
      await pumpGolden(tester, const JChip(label: 'URGENT'));
      await expectLater(
        find.byType(JChip),
        matchesGoldenFile('goldens/j_chip_default.png'),
      );
    });

    testWidgets('custom bg/fg — green verified chip', (tester) async {
      await pumpGolden(
        tester,
        Builder(
          builder: (context) => JChip(
            label: 'VERIFIED',
            backgroundColor: context.c.verified,
            foregroundColor: Colors.white,
          ),
        ),
      );
      await expectLater(
        find.byType(JChip),
        matchesGoldenFile('goldens/j_chip_custom.png'),
      );
    });
  });
}
