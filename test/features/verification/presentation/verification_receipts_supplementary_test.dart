import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/verification/domain/entities/verification.dart'
    show Verification;
import 'package:jobdun/features/verification/domain/entities/verification_document.dart';
import 'package:jobdun/features/verification/presentation/providers/verification_provider.dart';
import 'package:jobdun/features/verification/presentation/providers/verifications_provider.dart';
import 'package:jobdun/features/verification/presentation/widgets/verification_receipts.dart';

// Owner-path: a tradie sees White Card + public-liability rows on their own
// profile receipts card, each reflecting the document review state.
class _FakeVerificationController extends VerificationController {
  _FakeVerificationController(this._initial);
  final VerificationState _initial;
  @override
  VerificationState build() => _initial;
}

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
    binding.platformDispatcher.views.first.physicalSize = const Size(390, 2400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  VerificationDocument doc(
    DocType type,
    VerificationStatus status, {
    DateTime? expiryDate,
  }) => VerificationDocument(
    id: '${type.dbValue}-1',
    tradeId: 'u1',
    docType: type,
    filePath: 'u1/verification/${type.dbValue}/x.jpg',
    status: status,
    submittedAt: DateTime(2026, 6, 1),
    expiryDate: expiryDate,
  );

  Widget harness(List<VerificationDocument> documents) {
    return ProviderScope(
      overrides: [
        verificationControllerProvider.overrideWith(
          () => _FakeVerificationController(
            VerificationState(documents: documents),
          ),
        ),
        verificationsForUserProvider.overrideWith(
          (ref, userId) async => <Verification>[],
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.dark(),
          debugShowCheckedModeBanner: false,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: VerificationReceipts(
                userId: 'u1',
                isOwner: true,
                showAbnRow: false,
                showLicenceRow: true,
                showWhiteCardRow: true,
                showInsuranceRow: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders White Card + Public liability rows on the owner card', (
    tester,
  ) async {
    await tester.pumpWidget(harness(const []));
    await tester.pumpAndSettle();

    expect(find.text('White Card'), findsOneWidget);
    expect(find.text('Public liability'), findsOneWidget);
  });

  testWidgets('U3: empty owner rows sell the payoff, not a failure state', (
    tester,
  ) async {
    await tester.pumpWidget(harness(const []));
    await tester.pumpAndSettle();

    expect(
      find.text('Shows as INSURED on every application you send'),
      findsOneWidget,
    );
    expect(
      find.text("Proves you're site-ready — shown as a badge to builders"),
      findsOneWidget,
    );
    // The old loss-framed copy is gone from owner empty rows.
    expect(find.text('Not yet verified'), findsNothing);
  });

  testWidgets('a pending White Card shows "Under review"', (tester) async {
    await tester.pumpWidget(
      harness([doc(DocType.whiteCard, VerificationStatus.pending)]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Under review'), findsWidgets);
  });

  testWidgets('an approved public-liability shows document-review verified', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness([doc(DocType.publicLiability, VerificationStatus.approved)]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Verified by document review'), findsWidgets);
  });

  testWidgets(
    'U5: an approved doc past its expiry shows the lapsed row + renewal CTA',
    (tester) async {
      await tester.pumpWidget(
        harness([
          doc(
            DocType.whiteCard,
            VerificationStatus.approved,
            expiryDate: DateTime(2026, 1, 1), // long past
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('builders no longer see this badge'),
        findsOneWidget,
      );
      expect(find.text('Upload a new one →'), findsOneWidget);
    },
  );

  testWidgets(
    'U5: an approved doc inside the 30-day window nudges for a renewal',
    (tester) async {
      await tester.pumpWidget(
        harness([
          doc(
            DocType.publicLiability,
            VerificationStatus.approved,
            expiryDate: DateTime.now().add(const Duration(days: 10)),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('upload a renewal to keep your badge'),
        findsOneWidget,
      );
      expect(find.text('Upload a new one →'), findsOneWidget);
    },
  );

  testWidgets('U5: a status=expired doc keeps the "why" visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness([
        doc(
          DocType.whiteCard,
          VerificationStatus.expired,
          expiryDate: DateTime(2026, 5, 1),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Expired on 1 May 2026 — builders no longer see this badge'),
      findsOneWidget,
    );
  });
}
