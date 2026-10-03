import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jobdun/core/design/widgets/job_card.dart';
import 'package:jobdun/app/app.dart';
import 'package:jobdun/core/config/supabase_config.dart';
import 'package:jobdun/features/auth/presentation/widgets/guest_gate_sheet.dart';

/// E2E for App Review 5.1.1(v): a fresh user browses REAL posted jobs
/// (anon read of jobs_public_browse on the live project) without an account,
/// opens a detail, and only hits the account gate on APPLY. Run with:
///
///   flutter drive --driver=test_driver/integration_driver.dart \
///     --target=integration_test/guest_browse_flow_test.dart -d `device-id`
///
/// Screenshots land in docs/verification/ via the driver.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isNotEmpty) return;
    }
    throw TestFailure('Timed out waiting for $finder');
  }

  testWidgets('guest browses real jobs; APPLY opens the account gate', (
    tester,
  ) async {
    // Exercise real routing and backend without main() replacing the test
    // binding's error handler through Sentry. Native startup is tested separately.
    await dotenv.load(fileName: '.env');
    await SupabaseConfig.initialize();
    expect(SupabaseConfig.client.auth.currentSession, isNull);
    await tester.pumpWidget(const ProviderScope(child: JobdunApp()));

    final loginBrowseLink = find.textContaining(
      'Browse open jobs',
      findRichText: true,
    );
    // Both current FTUE and Login expose this entry. Do not depend on the
    // removed SKIP control or old all-caps presentation copy.
    await pumpUntil(tester, loginBrowseLink);
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('android-guest-01-browse-entry');
    await tester.tap(loginBrowseLink);

    // Public browser: header + real open jobs from the live anon view.
    await pumpUntil(tester, find.text('Open near you'));
    await pumpUntil(
      tester,
      find.byType(JobCard),
      timeout: const Duration(seconds: 40),
    );
    await binding.takeScreenshot('android-guest-02-browse-feed');
    expect(find.text('SAVED'), findsNothing); // account chip hidden
    expect(find.text('LOG IN'), findsWidgets); // guest header CTA

    // Open the first job's detail.
    // Cards are present before their entrance animation accepts pointer hits.
    final firstCard = find.byType(JobCard).first;
    await tester.ensureVisible(firstCard);
    await pumpUntil(tester, firstCard.hitTestable());
    await tester.tap(firstCard.hitTestable());
    final apply = find.textContaining(
      RegExp(r'^(Quote this job|Apply for this job)$'),
    );
    await pumpUntil(tester, apply);
    await binding.takeScreenshot('android-guest-03-job-detail');

    // APPLY is account-based → the gate sheet, not the apply form.
    await tester.tap(apply);
    await pumpUntil(
      tester,
      find.textContaining('CREATE A FREE ACCOUNT', findRichText: true),
    );
    await binding.takeScreenshot('android-guest-04-gate-sheet');
    final gate = find.byType(GuestGateSheet);
    expect(gate, findsOneWidget);
    expect(
      find.descendant(of: gate, matching: find.text('CREATE ACCOUNT')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: gate, matching: find.text('LOG IN')),
      findsOneWidget,
    );
  });
}
