import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/admin/app/placeholders/admin_placeholder_action.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/design/widgets/j_button.dart';
import 'package:jobdun/core/theme/app_icons.dart';

Widget _wrap(Widget child) => ScreenUtilInit(
  designSize: const Size(1440, 900),
  builder: (_, _) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('renders a disabled button with the label, lock, and tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const AdminPlaceholderAction(
          label: 'SUSPEND',
          tooltip: 'Wiring in Phase 2 — moderation',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('SUSPEND'), findsOneWidget);
    expect(find.byIcon(AppIcons.lock), findsOneWidget);

    // The whole point: the action is NOT wired — the button must be disabled.
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('danger variant is also disabled', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AdminPlaceholderAction(
          label: 'BAN',
          tooltip: 'Wiring in Phase 2 — moderation',
          variant: JButtonVariant.danger,
        ),
      ),
    );
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
