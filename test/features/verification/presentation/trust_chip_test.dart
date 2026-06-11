import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/verification/presentation/widgets/trust_chip.dart';

// U2.1: the one verified-credential pill — verified / expired / placeholder
// states, screen-reader labels baked in, optional tap.
void main() {
  setUpAll(() async {
    await dotenv.load(
      mergeWith: {
        'SUPABASE_URL': 'https://test.supabase.co',
        'SUPABASE_ANON_KEY': 'test_anon_key',
      },
    );
  });

  Widget harness(Widget child) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        theme: AppTheme.dark(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('verified state renders the uppercased label', (tester) async {
    await tester.pumpWidget(
      harness(
        const TrustChip(label: 'White Card', state: TrustChipState.verified),
      ),
    );
    expect(find.text('WHITE CARD'), findsOneWidget);
  });

  testWidgets('expired state appends the suffix — never colour alone', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(const TrustChip(label: 'Insured', state: TrustChipState.expired)),
    );
    expect(find.text('INSURED (EXPIRED)'), findsOneWidget);
  });

  testWidgets('placeholder state renders for the owner preview strip', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const TrustChip(label: 'Licence', state: TrustChipState.placeholder),
      ),
    );
    expect(find.text('LICENCE'), findsOneWidget);
  });

  testWidgets('exposes a semantic label and button-ness when tappable', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      harness(
        TrustChip(
          label: 'White Card',
          state: TrustChipState.verified,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('White Card, verified credential'),
      findsOneWidget,
    );

    await tester.tap(find.text('WHITE CARD'));
    expect(tapped, isTrue);
  });

  testWidgets('expired semantic label says expired', (tester) async {
    await tester.pumpWidget(
      harness(const TrustChip(label: 'Insured', state: TrustChipState.expired)),
    );
    expect(
      find.bySemanticsLabel('Insured, expired credential'),
      findsOneWidget,
    );
  });
}
