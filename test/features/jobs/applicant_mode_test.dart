import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';
import 'package:jobdun/features/profile/domain/repositories/profile_repository.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';
import 'package:jobdun/features/jobs/presentation/providers/job_applicant_mode_provider.dart';

class _Repo extends Mock implements ProfileRepository {}

void main() {
  test(
    'cold job entry fetches apprentice identity without Home/Profile mount',
    () async {
      final repo = _Repo();
      when(() => repo.getTradeProfile('a')).thenAnswer(
        (_) async => const Right(
          TradeProfile(
            id: 'a',
            fullName: 'Alex',
            primaryTrade: 'Carpenter',
            isApprentice: true,
          ),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentUserIdSyncProvider.overrideWithValue('a'),
          profileRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      expect(
        await container.read(jobApplicantIsApprenticeProvider.future),
        isTrue,
      );
      verify(() => repo.getTradeProfile('a')).called(1);
    },
  );
  test(
    'profile failures remain errors instead of contractor identity',
    () async {
      final repo = _Repo();
      when(
        () => repo.getTradeProfile('a'),
      ).thenAnswer((_) async => const Left(ServerFailure('Offline')));
      final container = ProviderContainer(
        overrides: [
          currentUserIdSyncProvider.overrideWithValue('a'),
          profileRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(jobApplicantIsApprenticeProvider.future),
        throwsStateError,
      );
    },
  );
}
