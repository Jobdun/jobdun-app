// ProfileController.savePatches — quick-edit sheets section save.
//
// Pattern: ProviderContainer + mocktail-mocked repo + an override of
// currentUserIdSyncProvider (same harness as state_mgmt_refactor_test.dart).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/profile/data/models/trade_profile_model.dart';
import 'package:jobdun/features/profile/domain/entities/profile_patches.dart';
import 'package:jobdun/features/profile/domain/repositories/profile_repository.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';

class _MockRepo extends Mock implements ProfileRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const UserProfilePatch());
    registerFallbackValue(const TradeProfilePatch());
    registerFallbackValue(const BuilderProfilePatch());
  });

  late _MockRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _MockRepo();
    container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        currentUserIdSyncProvider.overrideWithValue('u1'),
      ],
    );
    addTearDown(container.dispose);
  });

  test('savePatches patches trade table then refreshes only it', () async {
    when(
      () => repo.patchTradeProfile('u1', any()),
    ).thenAnswer((_) async => right(null));
    when(() => repo.getTradeProfile('u1')).thenAnswer(
      (_) async => right(
        const TradeProfileModel(
          id: 'u1',
          fullName: 'Ken',
          primaryTrade: 'carpenter',
          about: 'Brickie, 10 yrs',
        ),
      ),
    );

    final ok = await container
        .read(profileControllerProvider.notifier)
        .savePatches(
          trade: const TradeProfilePatch(about: Some('Brickie, 10 yrs')),
        );

    expect(ok, isTrue);
    expect(
      container.read(profileControllerProvider).tradeProfile?.about,
      'Brickie, 10 yrs',
    );
    final captured = verify(
      () => repo.patchTradeProfile('u1', captureAny()),
    ).captured;
    expect(
      (captured.single as TradeProfilePatch).about,
      const Some('Brickie, 10 yrs'),
    );
    verifyNever(() => repo.getBuilderProfile(any()));
    verifyNever(() => repo.getProfile(any()));
  });

  test('savePatches surfaces failure and returns false', () async {
    when(
      () => repo.patchTradeProfile('u1', any()),
    ).thenAnswer((_) async => left(const ServerFailure('offline')));

    final ok = await container
        .read(profileControllerProvider.notifier)
        .savePatches(trade: const TradeProfilePatch(about: Some('x')));

    expect(ok, isFalse);
    expect(
      container.read(profileControllerProvider).error,
      contains('offline'),
    );
    verifyNever(() => repo.getTradeProfile(any()));
  });
}
