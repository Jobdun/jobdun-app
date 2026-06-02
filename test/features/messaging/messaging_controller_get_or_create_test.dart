import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/messaging/domain/repositories/message_repository.dart';
import 'package:jobdun/features/messaging/presentation/providers/messaging_provider.dart';

class _MockRepo extends Mock implements MessageRepository {}

void main() {
  ProviderContainer makeContainer(MessageRepository repo) {
    final container = ProviderContainer(
      overrides: [
        messageRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWith((ref) => Stream.value('b')),
        currentUserIdSyncProvider.overrideWithValue('b'),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('returns the conversation id on success', () async {
    final repo = _MockRepo();
    when(
      () => repo.getOrCreateConversation(
        builderId: any(named: 'builderId'),
        tradeId: any(named: 'tradeId'),
        jobId: any(named: 'jobId'),
      ),
    ).thenAnswer((_) async => right('conv-9'));

    final container = makeContainer(repo);
    final controller = container.read(messagingControllerProvider.notifier);

    final id = await controller.getOrCreateConversation(
      builderId: 'b',
      tradeId: 't',
      jobId: 'j',
    );

    expect(id, 'conv-9');
  });

  test('returns null and records error on failure', () async {
    final repo = _MockRepo();
    when(
      () => repo.getOrCreateConversation(
        builderId: any(named: 'builderId'),
        tradeId: any(named: 'tradeId'),
        jobId: any(named: 'jobId'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('nope')));

    final container = makeContainer(repo);
    final controller = container.read(messagingControllerProvider.notifier);

    final id = await controller.getOrCreateConversation(
      builderId: 'b',
      tradeId: 't',
    );

    expect(id, isNull);
    expect(container.read(messagingControllerProvider).error, 'nope');
  });
}
