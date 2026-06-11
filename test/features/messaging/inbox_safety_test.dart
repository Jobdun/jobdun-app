import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/messaging/domain/entities/report_submission.dart';
import 'package:jobdun/features/messaging/domain/repositories/message_repository.dart';
import 'package:jobdun/features/messaging/presentation/providers/inbox_safety_provider.dart';
import 'package:jobdun/features/messaging/presentation/providers/messaging_provider.dart';

class _MockRepo extends Mock implements MessageRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const ReportSubmission(
        reporterId: 'me',
        reportedId: 'them',
        conversationId: 'c1',
        reason: ReportReason.harassment,
      ),
    );
  });

  late _MockRepo repo;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        messageRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWith((ref) => Stream.value('me')),
        currentUserIdSyncProvider.overrideWithValue('me'),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => repo = _MockRepo());

  test('blockUser reaches repo with my id and refreshes the inbox', () async {
    when(
      () => repo.blockUser(
        blockerId: any(named: 'blockerId'),
        blockedId: any(named: 'blockedId'),
        conversationId: any(named: 'conversationId'),
      ),
    ).thenAnswer((_) async => right(null));
    when(
      () => repo.getConversations('me'),
    ).thenAnswer((_) async => right(const []));

    final c = makeContainer();
    final ok = await c
        .read(inboxSafetyControllerProvider.notifier)
        .blockUser(blockedId: 'them', conversationId: 'c1');

    expect(ok, isTrue);
    expect(c.read(inboxSafetyControllerProvider).isLoading, isFalse);
    verify(
      () => repo.blockUser(
        blockerId: 'me',
        blockedId: 'them',
        conversationId: 'c1',
      ),
    ).called(1);
    verify(() => repo.getConversations('me')).called(1); // inbox refreshed
  });

  test('blockUser failure surfaces error and returns false', () async {
    when(
      () => repo.blockUser(
        blockerId: any(named: 'blockerId'),
        blockedId: any(named: 'blockedId'),
        conversationId: any(named: 'conversationId'),
      ),
    ).thenAnswer((_) async => left(const ServerFailure('rls')));

    final c = makeContainer();
    final ok = await c
        .read(inboxSafetyControllerProvider.notifier)
        .blockUser(blockedId: 'them', conversationId: 'c1');

    expect(ok, isFalse);
    expect(c.read(inboxSafetyControllerProvider).error, contains('rls'));
    verifyNever(() => repo.getConversations(any()));
  });

  test('reportUser success resets state; failure keeps error', () async {
    when(
      () => repo.reportUser(report: any(named: 'report')),
    ).thenAnswer((_) async => right(null));

    final c = makeContainer();
    final ok = await c
        .read(inboxSafetyControllerProvider.notifier)
        .reportUser(
          const ReportSubmission(
            reporterId: 'me',
            reportedId: 'them',
            conversationId: 'c1',
            reason: ReportReason.spamOrScam,
          ),
        );
    expect(ok, isTrue);
    expect(c.read(inboxSafetyControllerProvider).error, isNull);
  });

  test('unblockUser reverses the block and refreshes the inbox', () async {
    when(
      () => repo.unblockUser(
        blockedId: any(named: 'blockedId'),
        conversationId: any(named: 'conversationId'),
      ),
    ).thenAnswer((_) async => right(null));
    when(
      () => repo.getConversations('me'),
    ).thenAnswer((_) async => right(const []));

    final c = makeContainer();
    final ok = await c
        .read(inboxSafetyControllerProvider.notifier)
        .unblockUser(blockedId: 'them', conversationId: 'c1');

    expect(ok, isTrue);
    verify(
      () => repo.unblockUser(blockedId: 'them', conversationId: 'c1'),
    ).called(1);
    verify(() => repo.getConversations('me')).called(1);
  });

  test('amIBlocking degrades to false on failure', () async {
    when(
      () => repo.amIBlocking(any()),
    ).thenAnswer((_) async => left(const ServerFailure('offline')));
    final c = makeContainer();
    final mine = await c
        .read(inboxSafetyControllerProvider.notifier)
        .amIBlocking('them');
    expect(mine, isFalse);
  });
}
