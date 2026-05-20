import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/core/design/widgets/j_switch.dart';

import '_harness.dart';

void main() {
  group('JSwitch goldens (dark)', () {
    testWidgets('off', (tester) async {
      await pumpGolden(tester, JSwitch(value: false, onChanged: (_) {}));
      await expectLater(
        find.byType(JSwitch),
        matchesGoldenFile('goldens/j_switch_off.png'),
      );
    });

    testWidgets('on', (tester) async {
      await pumpGolden(tester, JSwitch(value: true, onChanged: (_) {}));
      await expectLater(
        find.byType(JSwitch),
        matchesGoldenFile('goldens/j_switch_on.png'),
      );
    });
  });
}
