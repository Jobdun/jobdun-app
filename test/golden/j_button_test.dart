import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/core/design/widgets/j_button.dart';

import '_harness.dart';

void main() {
  group('JButton goldens (dark)', () {
    testWidgets('primary default', (tester) async {
      await pumpGolden(
        tester,
        const JButton(label: 'LOG IN', onPressed: _noop),
      );
      await expectLater(
        find.byType(JButton),
        matchesGoldenFile('goldens/j_button_primary_default.png'),
      );
    });

    testWidgets('primary loading', (tester) async {
      await pumpGolden(
        tester,
        const JButton(label: 'LOG IN', isLoading: true),
      );
      await expectLater(
        find.byType(JButton),
        matchesGoldenFile('goldens/j_button_primary_loading.png'),
      );
    });

    testWidgets('primary disabled', (tester) async {
      await pumpGolden(tester, const JButton(label: 'LOG IN'));
      await expectLater(
        find.byType(JButton),
        matchesGoldenFile('goldens/j_button_primary_disabled.png'),
      );
    });

    testWidgets('primary compact', (tester) async {
      await pumpGolden(
        tester,
        const JButton(
          label: 'HIRE',
          size: JButtonSize.compact,
          onPressed: _noop,
        ),
      );
      await expectLater(
        find.byType(JButton),
        matchesGoldenFile('goldens/j_button_primary_compact.png'),
      );
    });

    testWidgets('secondary default', (tester) async {
      await pumpGolden(
        tester,
        const JButton(
          label: 'CANCEL',
          variant: JButtonVariant.secondary,
          onPressed: _noop,
        ),
      );
      await expectLater(
        find.byType(JButton),
        matchesGoldenFile('goldens/j_button_secondary_default.png'),
      );
    });

    testWidgets('text variant', (tester) async {
      await pumpGolden(
        tester,
        const JButton(
          label: 'SKIP',
          variant: JButtonVariant.text,
          onPressed: _noop,
        ),
      );
      await expectLater(
        find.byType(JButton),
        matchesGoldenFile('goldens/j_button_text_default.png'),
      );
    });
  });
}

void _noop() {}
