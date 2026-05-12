import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:iconsax/iconsax.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/widgets/inputs/j_text_field.dart';

void main() {
  Widget wrap(Widget child, {GlobalKey<FormBuilderState>? formKey}) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, child2) => MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: FormBuilder(
            key: formKey ?? GlobalKey<FormBuilderState>(),
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('renders the label text above the field', (tester) async {
    await tester.pumpWidget(
      wrap(const JTextField(name: 'email', label: 'Email')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.byType(FormBuilderTextField), findsOneWidget);
  });

  testWidgets('validator triggers and error state shows', (tester) async {
    final formKey = GlobalKey<FormBuilderState>();
    await tester.pumpWidget(
      wrap(
        JTextField(
          name: 'email',
          label: 'Email',
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(errorText: 'Email is required.'),
          ]),
        ),
        formKey: formKey,
      ),
    );
    await tester.pumpAndSettle();

    // Empty save → validation fails → error renders.
    final ok = formKey.currentState!.saveAndValidate();
    expect(ok, isFalse);
    await tester.pumpAndSettle();

    expect(find.text('Email is required.'), findsOneWidget);
  });

  testWidgets('password toggle reveals and hides the value', (tester) async {
    await tester.pumpWidget(
      wrap(
        const JTextField(
          name: 'password',
          label: 'Password',
          obscureText: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Default obscured: eye_slash icon visible.
    expect(find.byIcon(Iconsax.eye_slash), findsOneWidget);
    expect(find.byIcon(Iconsax.eye), findsNothing);

    await tester.tap(find.byIcon(Iconsax.eye_slash));
    await tester.pumpAndSettle();

    // After tap: eye icon visible (value now revealed).
    expect(find.byIcon(Iconsax.eye), findsOneWidget);
    expect(find.byIcon(Iconsax.eye_slash), findsNothing);
  });

  testWidgets('non-password field does not show a password toggle', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const JTextField(name: 'email', label: 'Email')),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Iconsax.eye), findsNothing);
    expect(find.byIcon(Iconsax.eye_slash), findsNothing);
  });
}
