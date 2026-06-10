import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/verification/domain/entities/trade_public_credential.dart';
import 'package:jobdun/features/verification/domain/entities/verification_document.dart';
import 'package:jobdun/features/verification/presentation/providers/verifications_provider.dart';
import 'package:jobdun/features/verification/presentation/widgets/trade_credential_badges.dart';

void main() {
  setUpAll(() async {
    await dotenv.load(
      mergeWith: {
        'SUPABASE_URL': 'https://test.supabase.co',
        'SUPABASE_ANON_KEY': 'test_anon_key',
      },
    );
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.physicalSize = const Size(800, 600);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  Widget harness(List<TradePublicCredential> creds) {
    return ProviderScope(
      overrides: [
        tradePublicCredentialsProvider('t1').overrideWith((ref) async => creds),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.dark(),
          debugShowCheckedModeBanner: false,
          home: const Scaffold(
            body: Center(child: TradeCredentialBadges(userId: 't1')),
          ),
        ),
      ),
    );
  }

  testWidgets('renders a White Card and Insured chip for approved creds', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(const [
        TradePublicCredential(userId: 't1', docType: DocType.whiteCard),
        TradePublicCredential(userId: 't1', docType: DocType.publicLiability),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('WHITE CARD'), findsOneWidget);
    expect(find.text('INSURED'), findsOneWidget);
  });

  testWidgets('marks an expired credential', (tester) async {
    await tester.pumpWidget(
      harness(const [
        TradePublicCredential(
          userId: 't1',
          docType: DocType.publicLiability,
          isExpired: true,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('EXPIRED'), findsOneWidget);
  });

  testWidgets('renders nothing when there are no approved creds', (
    tester,
  ) async {
    await tester.pumpWidget(harness(const []));
    await tester.pumpAndSettle();

    expect(find.text('WHITE CARD'), findsNothing);
    expect(find.text('INSURED'), findsNothing);
  });

  testWidgets('tapping a chip opens the credential detail sheet (U2)', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness([
        TradePublicCredential(
          userId: 't1',
          docType: DocType.whiteCard,
          expiresAt: DateTime(2027, 3, 12),
          capturedAt: DateTime(2026, 6, 1),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('WHITE CARD'));
    await tester.pumpAndSettle();

    expect(find.text('White Card (construction induction)'), findsOneWidget);
    expect(find.text('Verified by document review'), findsOneWidget);
    expect(find.text('Expires 12 Mar 2027'), findsOneWidget);
    expect(find.text('Approved 1 Jun 2026'), findsOneWidget);
  });
}
