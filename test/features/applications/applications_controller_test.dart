import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/applications/domain/entities/job_application.dart';
import 'package:jobdun/features/applications/domain/repositories/application_repository.dart';
import 'package:jobdun/features/applications/presentation/providers/applications_provider.dart';

class MockApplicationRepository extends Mock implements ApplicationRepository {}

void main() {
  late MockApplicationRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockApplicationRepository();
    // SupabaseConfig is NOT initialized in tests, so currentUserIdSyncProvider
    // resolves to null: the controller skips its auto-load and post-mutation
    // reloads, leaving the use-case call as the only repo interaction.
    container = ProviderContainer(
      overrides: [applicationRepositoryProvider.overrideWithValue(mockRepo)],
    );
    addTearDown(container.dispose);
  });

  // 2026-08-18 audit (#4): updateStatus used to return void and swallow
  // failures into state.error — a failed HIRE popped the applicant page as if
  // it had succeeded. It now returns Future<bool> so callers pop ONLY on
  // success.
  group('ApplicationsController.updateStatus result (2026-08-18 audit #4)', () {
    test('returns true when the write succeeds', () async {
      when(
        () => mockRepo.updateStatus('app-1', ApplicationStatus.hired),
      ).thenAnswer((_) async => const Right(null));

      final ok = await container
          .read(applicationsControllerProvider.notifier)
          .updateStatus('app-1', ApplicationStatus.hired);

      expect(ok, isTrue);
      expect(container.read(applicationsControllerProvider).error, isNull);
    });

    test('returns false and sets state.error when the write fails', () async {
      when(
        () => mockRepo.updateStatus('app-1', ApplicationStatus.hired),
      ).thenAnswer((_) async => const Left(ServerFailure('Update failed')));

      final ok = await container
          .read(applicationsControllerProvider.notifier)
          .updateStatus('app-1', ApplicationStatus.hired);

      expect(ok, isFalse);
      expect(
        container.read(applicationsControllerProvider).error,
        'Update failed',
      );
    });
  });

  // 2026-08-18 audit (#3): withdraw was fire-and-forget from the page; it now
  // reports success so the page can surface a SnackBar on failure.
  group('ApplicationsController.withdraw result (2026-08-18 audit #3)', () {
    test('returns true when the write succeeds', () async {
      when(
        () => mockRepo.withdraw('app-1'),
      ).thenAnswer((_) async => const Right(null));

      final ok = await container
          .read(applicationsControllerProvider.notifier)
          .withdraw('app-1');

      expect(ok, isTrue);
      expect(container.read(applicationsControllerProvider).error, isNull);
    });

    test('returns false and sets state.error when the write fails', () async {
      when(
        () => mockRepo.withdraw('app-1'),
      ).thenAnswer((_) async => const Left(ServerFailure('Withdraw failed')));

      final ok = await container
          .read(applicationsControllerProvider.notifier)
          .withdraw('app-1');

      expect(ok, isFalse);
      expect(
        container.read(applicationsControllerProvider).error,
        'Withdraw failed',
      );
    });
  });
}
