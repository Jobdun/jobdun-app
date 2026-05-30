import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_colors.dart';
import 'package:jobdun/features/verification/domain/entities/builder_public_verification.dart';
import 'package:jobdun/features/verification/domain/entities/verification.dart';
import 'package:jobdun/features/verification/presentation/providers/verifications_provider.dart';
import 'package:jobdun/features/verification/presentation/widgets/builder_verified_badge.dart';

Future<void> _pump(WidgetTester tester, ProviderScope app) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump();
}

ProviderScope _badgeScope(List<BuilderPublicVerification> rows) {
  return ProviderScope(
    overrides: [
      builderPublicVerificationProvider.overrideWith((ref, userId) async => rows),
    ],
    child: ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          extensions: const [JColors.dark],
        ),
        home: const Scaffold(body: BuilderVerifiedBadge(userId: 'b1')),
      ),
    ),
  );
}

void main() {
  testWidgets('shows "Verified business · GST" for a GST-registered ABN', (
    tester,
  ) async {
    await _pump(
      tester,
      _badgeScope(const [
        BuilderPublicVerification(
          userId: 'b1',
          kind: VerificationKind.abn,
          verifiedLegalName: 'Acme Building Pty Ltd',
          gstRegistered: true,
        ),
      ]),
    );

    expect(find.textContaining('Verified business'), findsOneWidget);
    expect(find.textContaining('GST'), findsOneWidget);
  });

  testWidgets('renders nothing when there is no verification', (tester) async {
    await _pump(tester, _badgeScope(const []));

    expect(find.textContaining('Verified business'), findsNothing);
  });
}
