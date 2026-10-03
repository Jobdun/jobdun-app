import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/jobs/presentation/pages/job_create_page.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';

void main() {
  testWidgets('apprenticeship keeps details and validates decimal hourly pay', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) =>
              MaterialApp(theme: AppTheme.light(), home: const JobCreatePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Job type'), findsOneWidget);
    await tester.tap(find.text('Apprenticeship'));
    await tester.pumpAndSettle();
    expect(find.text('Open to apprentices'), findsNothing);
    final form = tester.state<FormBuilderState>(find.byType(FormBuilder));
    form.patchValue({
      'title': 'Carpentry apprenticeship',
      'description': 'Training on residential sites, weekday hours.',
      'trade': 'Carpenter',
      'suburb': 'Sydney',
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Hourly pay'), findsOneWidget);
    expect(find.text('Request Quotes'), findsNothing);
    expect(find.textContaining('nearby charge'), findsNothing);
    await tester.enterText(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is FormBuilderTextField && w.name == 'rate',
        ),
        matching: find.byType(TextField),
      ),
      '24.75',
    );
    expect(form.fields['rate']!.value, '24.75');
    expect(form.fields['rate']!.validate(), isTrue);
    form.fields['rate']!.didChange('0');
    expect(form.fields['rate']!.validate(), isFalse);
    form.fields['rate']!.didChange('Infinity');
    expect(form.fields['rate']!.validate(), isFalse);
    form.fields['rate']!.didChange('24.75');
    await tester.tap(find.byTooltip('Back a step'));
    await tester.pumpAndSettle();
    expect(form.fields['title']!.value, 'Carpentry apprenticeship');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(form.fields['rate']!.value, '24.75');
    await tester.tap(find.byTooltip('Back a step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trade job'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(PricingType.requestQuote.label));
    await tester.pumpAndSettle();
    expect(form.fields.containsKey('rate'), isFalse);
    await tester.tap(find.byTooltip('Back a step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apprenticeship'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Hourly pay'), findsOneWidget);
    expect(find.text(PricingType.requestQuote.label), findsNothing);
    expect(form.fields.containsKey('rate'), isTrue);
    expect(form.fields['rate']!.value, '24.75');
  });
}
