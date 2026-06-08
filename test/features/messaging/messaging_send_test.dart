import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/messaging/domain/entities/conversation.dart';
import 'package:jobdun/features/messaging/domain/entities/message.dart';
import 'package:jobdun/features/messaging/domain/repositories/message_repository.dart';
import 'package:jobdun/features/messaging/presentation/providers/messaging_provider.dart';
import 'package:jobdun/features/messaging/presentation/state/thread_messages.dart';

class _MockRepo extends Mock implements MessageRepository {}

void main() {
  setUpAll(() => registerFallbackValue(File('fallback')));

  final base = DateTime(2026, 6, 8, 10);

  Message msg({
    required String id,
    String senderId = 'me',
    required DateTime createdAt,
  }) => Message(
    id: id,
    conversationId: 'c1',
    senderId: senderId,
    body: 'hi',
    createdAt: createdAt,
  );

  ProviderContainer makeContainer(MessageRepository repo) {
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

  // Stubs the realtime/stream methods to no-ops so only the path under test runs.
  void stubStreams(_MockRepo repo) {
    when(
      () => repo.watchMessages(any(), tailLimit: any(named: 'tailLimit')),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => repo.watchConversation(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => repo.watchReactions(any()),
    ).thenAnswer((_) => const Stream.empty());
  }

  void stubSend(_MockRepo repo, Either<Failure, void> result) {
    when(
      () => repo.sendMessage(
        conversationId: any(named: 'conversationId'),
        senderId: any(named: 'senderId'),
        body: any(named: 'body'),
        clientTag: any(named: 'clientTag'),
      ),
    ).thenAnswer((_) async => result);
  }

  test(
    'sendMessage shows an optimistic bubble and inserts a client_tag',
    () async {
      final repo = _MockRepo();
      stubStreams(repo);
      stubSend(repo, right(null));
      final container = makeContainer(repo);
      final ctrl = container.read(messagingControllerProvider.notifier);

      await ctrl.sendMessage(conversationId: 'c1', body: 'hi');

      final entries = container
          .read(messagingControllerProvider)
          .entriesFor('c1', 'me');
      expect(entries, hasLength(1));
      expect(entries.single.status, MessageStatus.sending);
      verify(
        () => repo.sendMessage(
          conversationId: 'c1',
          senderId: 'me',
          body: 'hi',
          clientTag: any(named: 'clientTag'),
        ),
      ).called(1);
    },
  );

  test('a failed insert flips the bubble to failed; retry re-sends it', () async {
    final repo = _MockRepo();
    stubStreams(repo);
    stubSend(repo, left(ServerFailure('boom')));
    final container = makeContainer(repo);
    final ctrl = container.read(messagingControllerProvider.notifier);

    await ctrl.sendMessage(conversationId: 'c1', body: 'hi');

    var entry = container
        .read(messagingControllerProvider)
        .entriesFor('c1', 'me')
        .single;
    expect(entry.status, MessageStatus.failed);

    // Retry succeeds this time → back to sending (no echo so it stays pending).
    stubSend(repo, right(null));
    await ctrl.retryMessage(conversationId: 'c1', clientTag: entry.clientTag!);

    entry = container
        .read(messagingControllerProvider)
        .entriesFor('c1', 'me')
        .single;
    expect(entry.status, MessageStatus.sending);
    verify(
      () => repo.sendMessage(
        conversationId: any(named: 'conversationId'),
        senderId: any(named: 'senderId'),
        body: any(named: 'body'),
        clientTag: any(named: 'clientTag'),
      ),
    ).called(2);
  });

  test(
    'pagination: hasMore flips and loadOlder prepends the older page',
    () async {
      final repo = _MockRepo();
      stubStreams(repo);
      when(
        () => repo.getMessages(
          any(),
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer((inv) async {
        final before = inv.namedArguments[#before] as DateTime?;
        if (before == null) {
          // First page: a full 30 → "there may be more".
          return right([
            for (var i = 0; i < 30; i++)
              msg(
                id: 'a$i',
                createdAt: base.add(Duration(minutes: i)),
              ),
          ]);
        }
        // Older page: a partial 10 → end of history.
        return right([
          for (var i = 0; i < 10; i++)
            msg(
              id: 'b$i',
              createdAt: base.subtract(Duration(minutes: i + 1)),
            ),
        ]);
      });
      final container = makeContainer(repo);
      final ctrl = container.read(messagingControllerProvider.notifier);

      await ctrl.loadMessages('c1');
      expect(
        container.read(messagingControllerProvider).hasMoreFor('c1'),
        isTrue,
      );

      await ctrl.loadOlder('c1');
      final state = container.read(messagingControllerProvider);
      expect(state.hasMoreFor('c1'), isFalse);
      expect(state.messagesFor('c1'), hasLength(40));
    },
  );

  test(
    'unsendMessage optimistically tombstones the message + persists',
    () async {
      final repo = _MockRepo();
      stubStreams(repo);
      when(
        () => repo.getMessages(
          any(),
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer((_) async => right([msg(id: 'm1', createdAt: base)]));
      when(
        () => repo.softDeleteMessage(any()),
      ).thenAnswer((_) async => right(null));

      final container = makeContainer(repo);
      final ctrl = container.read(messagingControllerProvider.notifier);

      await ctrl.loadMessages('c1');
      await ctrl.unsendMessage(conversationId: 'c1', messageId: 'm1');

      final entry = container
          .read(messagingControllerProvider)
          .entriesFor('c1', 'me')
          .single;
      expect(entry.isDeleted, isTrue);
      verify(() => repo.softDeleteMessage('m1')).called(1);
    },
  );

  test('toggleReaction optimistically adds my reaction + persists', () async {
    final repo = _MockRepo();
    stubStreams(repo);
    when(
      () => repo.getMessages(
        any(),
        limit: any(named: 'limit'),
        before: any(named: 'before'),
      ),
    ).thenAnswer((_) async => right([msg(id: 'm1', createdAt: base)]));
    when(
      () => repo.setReaction(
        messageId: any(named: 'messageId'),
        conversationId: any(named: 'conversationId'),
        userId: any(named: 'userId'),
        emoji: any(named: 'emoji'),
      ),
    ).thenAnswer((_) async => right(null));

    final container = makeContainer(repo);
    final ctrl = container.read(messagingControllerProvider.notifier);

    await ctrl.loadMessages('c1');
    await ctrl.toggleReaction(
      conversationId: 'c1',
      messageId: 'm1',
      emoji: '❤️',
    );

    final entry = container
        .read(messagingControllerProvider)
        .entriesFor('c1', 'me')
        .single;
    expect(entry.reactions, hasLength(1));
    expect(entry.reactions.single.emoji, '❤️');
    expect(entry.reactions.single.mine, isTrue);
    verify(
      () => repo.setReaction(
        messageId: 'm1',
        conversationId: 'c1',
        userId: 'me',
        emoji: '❤️',
      ),
    ).called(1);
  });

  test('sendImage shows an instant uploading preview + uploads', () async {
    final repo = _MockRepo();
    stubStreams(repo);
    when(
      () => repo.sendImageMessage(
        conversationId: any(named: 'conversationId'),
        senderId: any(named: 'senderId'),
        clientTag: any(named: 'clientTag'),
        file: any(named: 'file'),
        mime: any(named: 'mime'),
        width: any(named: 'width'),
        height: any(named: 'height'),
      ),
    ).thenAnswer((_) async => right(null));

    final tmp = File(
      '${Directory.systemTemp.path}/msg_test_${DateTime.now().microsecondsSinceEpoch}.jpg',
    )..writeAsBytesSync([1, 2, 3]);
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync();
    });

    final container = makeContainer(repo);
    final ctrl = container.read(messagingControllerProvider.notifier);
    await ctrl.sendImage(conversationId: 'c1', file: tmp, mime: 'image/jpeg');

    final entry = container
        .read(messagingControllerProvider)
        .entriesFor('c1', 'me')
        .single;
    expect(entry.hasLocalImage, isTrue);
    verify(
      () => repo.sendImageMessage(
        conversationId: 'c1',
        senderId: 'me',
        clientTag: any(named: 'clientTag'),
        file: any(named: 'file'),
        mime: 'image/jpeg',
        width: any(named: 'width'),
        height: any(named: 'height'),
      ),
    ).called(1);
  });

  test('Seen lights up when the counterparty read marker arrives', () async {
    final repo = _MockRepo();
    when(
      () => repo.watchMessages(any(), tailLimit: any(named: 'tailLimit')),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => repo.watchReactions(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => repo.getMessages(
        any(),
        limit: any(named: 'limit'),
        before: any(named: 'before'),
      ),
    ).thenAnswer((_) async => right([msg(id: 'm1', createdAt: base)]));

    final convCtrl = StreamController<Conversation>();
    addTearDown(convCtrl.close);
    when(
      () => repo.watchConversation(any()),
    ).thenAnswer((_) => convCtrl.stream);

    final container = makeContainer(repo);
    final ctrl = container.read(messagingControllerProvider.notifier);

    await ctrl.loadMessages('c1');
    expect(
      container
          .read(messagingControllerProvider)
          .entriesFor('c1', 'me')
          .single
          .status,
      MessageStatus.sent,
    );

    // The other side (trade) opens the thread at/after my message.
    convCtrl.add(
      Conversation(
        id: 'c1',
        builderId: 'me',
        tradeId: 't',
        status: ConversationStatus.active,
        builderUnreadCount: 0,
        tradeUnreadCount: 0,
        createdAt: base,
        tradeLastReadAt: base,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      container
          .read(messagingControllerProvider)
          .entriesFor('c1', 'me')
          .single
          .status,
      MessageStatus.seen,
    );
  });
}
