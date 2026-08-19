import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';
import 'package:jobdun/features/jobs/domain/repositories/job_repository.dart';
import 'package:jobdun/features/jobs/presentation/pages/builder_listings_view.dart';
import 'package:jobdun/features/jobs/presentation/providers/jobs_provider.dart';

class MockJobRepository extends Mock implements JobRepository {}

// P6, 2026-08-18 audit: a failed listings load used to fold into an empty
// list and render "NO LISTINGS YET." — it must surface as an error + RETRY.
void main() {
  test(
    'builderListingsProvider propagates a failed load as AsyncError',
    () async {
      final repo = MockJobRepository();
      when(() => repo.getBuilderJobs(any())).thenAnswer(
        (_) async => left<Failure, List<Job>>(ServerFailure('down')),
      );

      final container = ProviderContainer(
        // Riverpod 3 auto-retries failed providers with backoff; disable it so
        // the error surfaces deterministically in this test.
        retry: (retryCount, error) => null,
        overrides: [
          currentUserIdSyncProvider.overrideWithValue('builder-1'),
          jobRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      container.listen(builderListingsProvider, (_, _) {});
      await expectLater(
        container.read(builderListingsProvider.future),
        throwsA(isA<Exception>()),
      );
      expect(container.read(builderListingsProvider).hasError, isTrue);
    },
  );

  testWidgets('a failed load shows the error state with RETRY', (tester) async {
    final repo = MockJobRepository();
    when(
      () => repo.getBuilderJobs(any()),
    ).thenAnswer((_) async => left<Failure, List<Job>>(ServerFailure('down')));

    await tester.pumpWidget(
      ProviderScope(
        // Disable Riverpod 3 auto-retry so the error state is deterministic.
        retry: (retryCount, error) => null,
        overrides: [
          currentUserIdSyncProvider.overrideWithValue('builder-1'),
          jobRepositoryProvider.overrideWithValue(repo),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            theme: AppTheme.dark(),
            home: const BuilderListingsView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your listings."), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);
    expect(find.text('NO LISTINGS YET.'), findsNothing);
  });
}
