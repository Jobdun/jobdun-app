import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jobdun/core/design/widgets/job_card.dart';
import 'package:jobdun/main.dart' as app;

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
    app.main();
    // Splash (900ms) + FTUE-gate read → first surface.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));

    final loginBrowseLink = find.textContaining(
      'Browse open jobs',
      findRichText: true,
    );
    final onFtue = find.text('SKIP').evaluate().isNotEmpty;

    if (onFtue) {
      // Fresh install: swipe the carousel to slide 3 where the guest entry
      // lives, then take it.
      for (var i = 0; i < 2; i++) {
        await tester.fling(
          find.byType(PageView).first,
          const Offset(-350, 0),
          1200,
        );
        await tester.pump(const Duration(milliseconds: 700));
      }
      await binding.takeScreenshot('2026-07-20-ios-guest-01-ftue-browse-cta');
      await tester.tap(
        find.textContaining('BROWSE OPEN JOBS', findRichText: true),
      );
    } else {
      // Returning install lands on /login — the browse link must be there.
      await pumpUntil(tester, loginBrowseLink);
      await binding.takeScreenshot('2026-07-20-ios-guest-01-login-browse-link');
      await tester.tap(loginBrowseLink);
    }

    // Public browser: header + real open jobs from the live anon view.
    await pumpUntil(tester, find.text('OPEN NEAR YOU'));
    await pumpUntil(
      tester,
      find.byType(JobCard),
      timeout: const Duration(seconds: 40),
    );
    await binding.takeScreenshot('2026-07-20-ios-guest-02-browse-feed');
    expect(find.text('SAVED'), findsNothing); // account chip hidden
    expect(find.text('LOG IN'), findsWidgets); // guest header CTA

    // Open the first job's detail.
    await tester.tap(find.byType(JobCard).first);
    await pumpUntil(tester, find.text('QUOTE THIS JOB'));
    await binding.takeScreenshot('2026-07-20-ios-guest-03-job-detail');

    // APPLY is account-based → the gate sheet, not the apply form.
    await tester.tap(find.text('QUOTE THIS JOB'));
    await pumpUntil(
      tester,
      find.textContaining('CREATE A FREE ACCOUNT', findRichText: true),
    );
    await binding.takeScreenshot('2026-07-20-ios-guest-04-gate-sheet');
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    expect(find.text('LOG IN'), findsWidgets);
  });
}
