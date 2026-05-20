import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/core/design/widgets/bottom_action_bar.dart';
import 'package:jobdun/core/design/widgets/j_button.dart';

import '_harness.dart';

void main() {
  group('BottomActionBar goldens (dark)', () {
    testWidgets('primary only', (tester) async {
      await pumpGolden(
        tester,
        const SizedBox(
          width: 393,
          child: BottomActionBar(
            primary: JButton(label: 'SAVE CHANGES', onPressed: _noop),
          ),
        ),
        padding: EdgeInsets.zero,
      );
      await expectLater(
        find.byType(BottomActionBar),
        matchesGoldenFile('goldens/bottom_action_bar_primary.png'),
      );
    });

    testWidgets('primary + secondary', (tester) async {
      await pumpGolden(
        tester,
        const SizedBox(
          width: 393,
          child: BottomActionBar(
            primary: JButton(label: 'OK', onPressed: _noop),
            secondary: JButton(
              label: 'NO',
              variant: JButtonVariant.secondary,
              onPressed: _noop,
            ),
          ),
        ),
        padding: EdgeInsets.zero,
      );
      await expectLater(
        find.byType(BottomActionBar),
        matchesGoldenFile('goldens/bottom_action_bar_pair.png'),
      );
    });
  });
}

void _noop() {}
