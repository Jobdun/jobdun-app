import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jobdun/core/config/supabase_config.dart';
import 'package:jobdun/app/app.dart';
import 'package:jobdun/core/design/widgets/job_card.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';
import 'package:jobdun/features/jobs/presentation/pages/jobs_page.dart';
import 'package:jobdun/features/jobs/presentation/providers/jobs_provider.dart';

/// Read-only smoke test against the configured backend using the actual app.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 160; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isNotEmpty) return;
    }
    throw TestFailure('Timed out waiting for $finder');
  }

  testWidgets('live guest browse filters apprenticeships and clears filters', (
    tester,
  ) async {
    await dotenv.load(fileName: '.env');
    await SupabaseConfig.initialize();
    expect(SupabaseConfig.client.auth.currentSession, isNull);
    await tester.pumpWidget(const ProviderScope(child: JobdunApp()));
    // Enter through the visible control after startup finishes. Forcing a route
    // while the splash auth check is pending can be overwritten by its redirect.
    final browse = find.textContaining('Browse open jobs', findRichText: true);
    await waitFor(tester, browse.hitTestable());
    await tester.tap(browse.hitTestable());
    await waitFor(tester, find.byType(JobCard).hitTestable());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(JobdunApp)),
    );
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 300));
      if (find.byType(JobsPage).evaluate().isNotEmpty &&
          find.byType(JobCard).evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.byType(JobsPage), findsOneWidget);
    expect(find.byType(JobCard), findsWidgets);
    await binding.convertFlutterSurfaceToImage();
    await tester.pump(const Duration(seconds: 1));
    await binding.takeScreenshot('2026-09-15-emulator-live-01-jobs');
    await tester.tap(find.text('APPRENTICESHIPS'));
    await tester.pump(const Duration(seconds: 2));
    final controller = container.read(jobsControllerProvider.notifier);
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (controller.pagingController.itemList != null) break;
    }
    expect(controller.pagingController.error, isNull);
    expect(
      container.read(jobsControllerProvider).filter?.jobKind,
      JobKind.apprenticeship,
    );
    expect(controller.pagingController.itemList, isNotNull);
    expect(
      controller.pagingController.itemList!.every((j) => j.isApprenticeship),
      isTrue,
    );
    await tester.pump(const Duration(seconds: 1));
    await binding.takeScreenshot('2026-09-15-emulator-live-02-apprenticeships');
    if (find.text('CLEAR FILTERS').evaluate().isNotEmpty) {
      await tester.tap(find.text('CLEAR FILTERS'));
    } else {
      await tester.tap(find.text('ALL JOBS'));
    }
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(jobsControllerProvider).filter, isNull);
    await waitFor(tester, find.byType(JobCard).hitTestable());
    await tester.tap(find.byType(JobCard).first.hitTestable());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Job Details'), findsOneWidget);
    await binding.takeScreenshot('2026-09-15-emulator-live-03-job-detail');
  });
}
