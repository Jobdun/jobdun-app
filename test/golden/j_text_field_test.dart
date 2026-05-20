import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:jobdun/core/widgets/inputs/j_text_field.dart';

import '_harness.dart';

void main() {
  group('JTextField goldens (dark)', () {
    testWidgets('default — empty with prefix icon', (tester) async {
      await pumpGolden(
        tester,
        FormBuilder(
          child: const JTextField(
            name: 'email',
            label: 'Email',
            hint: 'you@example.com',
            prefixIcon: AppIcons.email,
          ),
        ),
      );
      await expectLater(
        find.byType(JTextField),
        matchesGoldenFile('goldens/j_text_field_default.png'),
      );
    });

    testWidgets('with initial value', (tester) async {
      await pumpGolden(
        tester,
        FormBuilder(
          child: const JTextField(
            name: 'email',
            label: 'Email',
            initialValue: 'kuya@example.com',
            prefixIcon: AppIcons.email,
          ),
        ),
      );
      await expectLater(
        find.byType(JTextField),
        matchesGoldenFile('goldens/j_text_field_filled.png'),
      );
    });
  });
}
