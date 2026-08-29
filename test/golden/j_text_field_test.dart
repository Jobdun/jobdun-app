import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:jobdun/core/widgets/inputs/j_text_field.dart';

import '_harness.dart';

void main() {
  group('JTextField goldens (light)', () {
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

    // The states the Figma auth screens introduced. Error is the one worth a
    // pixel guard: it is a four-part treatment (fill, border, label, value)
    // driven off one WidgetStatesController, so a regression in any single
    // part is easy to ship unnoticed.
    testWidgets('error — server-rejected value', (tester) async {
      await pumpGolden(
        tester,
        FormBuilder(
          child: const JTextField(
            name: 'password',
            label: 'Password',
            initialValue: 'hunter2',
            obscureText: true,
            forcedErrorText: 'Wrong password *',
          ),
        ),
      );
      await expectLater(
        find.byType(JTextField),
        matchesGoldenFile('goldens/j_text_field_error.png'),
      );
    });

    testWidgets('disabled', (tester) async {
      await pumpGolden(
        tester,
        FormBuilder(
          child: const JTextField(
            name: 'email',
            label: 'Email',
            initialValue: 'kuya@example.com',
            enabled: false,
          ),
        ),
      );
      await expectLater(
        find.byType(JTextField),
        matchesGoldenFile('goldens/j_text_field_disabled.png'),
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
