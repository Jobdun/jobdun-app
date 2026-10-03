import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/messaging/domain/entities/conversation.dart';
import 'package:jobdun/features/messaging/domain/entities/message.dart';
import 'package:jobdun/features/messaging/domain/entities/message_reaction.dart';
import 'package:jobdun/features/messaging/domain/repositories/message_repository.dart';
import 'package:jobdun/features/messaging/presentation/providers/messaging_provider.dart';

class _Repo extends Mock implements MessageRepository {}

Conversation _conversation(String user) => Conversation(
  id: user,
  builderId: 'builder',
  tradeId: user,
  status: ConversationStatus.active,
  builderUnreadCount: 0,
  tradeUnreadCount: 1,
  createdAt: DateTime(2026),
);
Message _message(String id) => Message(
  id: id,
  conversationId: 'thread',
  senderId: 'a',
  body: id,
  createdAt: DateTime(2026),
);

Future<void> _flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Repo repo;
  late StreamController<String?> accounts;
  late ProviderContainer container;
  late MessagingController controller;
  var disposed = false;

  Future<void> switchTo(String? user) async {
    accounts.add(user);
    await _flush();
  }

  setUp(() async {
    disposed = false;
    repo = _Repo();
    accounts = StreamController<String?>.broadcast();
    when(() => repo.getConversations(any())).thenAnswer(
      (call) async =>
          Right([_conversation(call.positionalArguments.first as String)]),
    );
    when(
      () => repo.watchConversations(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => repo.watchMessages(any(), tailLimit: any(named: 'tailLimit')),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => repo.watchConversation(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => repo.watchReactions(any()),
    ).thenAnswer((_) => const Stream<List<MessageReaction>>.empty());
    when(() => repo.getMessages('thread', limit: 30)).thenAnswer(
      (_) async => Right(List.generate(30, (i) => _message('message-$i'))),
    );
    container = ProviderContainer(
      overrides: [
        messageRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWith((ref) => accounts.stream),
        currentUserIdSyncProvider.overrideWith(
          (ref) => ref.watch(currentUserIdProvider).value,
        ),
      ],
    );
    container.listen(currentUserIdProvider, (_, _) {});
    await switchTo('a');
    controller = container.read(messagingControllerProvider.notifier);
  });

  tearDown(() async {
    if (!disposed) container.dispose();
    await accounts.close();
  });

  for (final next in <String?>[null, 'b', 'a']) {
    test('late inbox load is discarded after switching to $next', () async {
      final pending = Completer<Either<Failure, List<Conversation>>>();
      when(() => repo.getConversations('a')).thenAnswer((_) => pending.future);
      final operation = controller.loadConversations();
      await switchTo(null);
      if (next != null) await switchTo(next);
      pending.complete(Right([_conversation('a')]));
      await operation;
      expect(
        container.read(messagingControllerProvider).conversations,
        isEmpty,
      );
      verifyNever(() => repo.watchConversations('a'));
    });

    test(
      'late history load cannot restore messages or streams for $next',
      () async {
        final pending = Completer<Either<Failure, List<Message>>>();
        when(
          () => repo.getMessages('thread', limit: 30),
        ).thenAnswer((_) => pending.future);
        final operation = controller.loadMessages('thread');
        await switchTo(next == 'a' ? null : next);
        if (next == 'a') await switchTo('a');
        pending.complete(Right([_message('old')]));
        await operation;
        expect(
          container.read(messagingControllerProvider).messagesByConvId,
          isEmpty,
        );
        verifyNever(
          () => repo.watchMessages(any(), tailLimit: any(named: 'tailLimit')),
        );
        verifyNever(() => repo.watchConversation(any()));
        verifyNever(() => repo.watchReactions(any()));
      },
    );
  }

  test('late history failure cannot overwrite account b status', () async {
    final pending = Completer<Either<Failure, List<Message>>>();
    when(
      () => repo.getMessages('thread', limit: 30),
    ).thenAnswer((_) => pending.future);
    final operation = controller.loadMessages('thread');
    await switchTo('b');
    pending.complete(const Left(ServerFailure('old error')));
    await operation;
    expect(container.read(messagingControllerProvider).error, isNull);
  });

  test('in-flight realtime inbox refresh cannot restore account a', () async {
    final stream = StreamController<List<Conversation>>.broadcast();
    addTearDown(stream.close);
    when(() => repo.watchConversations('a')).thenAnswer((_) => stream.stream);
    await controller.loadConversations();
    final pending = Completer<Either<Failure, List<Conversation>>>();
    when(() => repo.getConversations('a')).thenAnswer((_) => pending.future);
    stream.add([]);
    await _flush();
    await switchTo('b');
    await controller.loadConversations();
    pending.complete(Right([_conversation('a')]));
    await _flush();
    expect(
      container.read(messagingControllerProvider).conversations.single.id,
      'b',
    );
    expect(stream.hasListener, isFalse);
  });

  test(
    'old pagination cannot block or overwrite new account pagination',
    () async {
      await controller.loadMessages('thread');
      final oldPage = Completer<Either<Failure, List<Message>>>();
      final newPage = Completer<Either<Failure, List<Message>>>();
      var calls = 0;
      when(
        () => repo.getMessages('thread', limit: 30, before: DateTime(2026)),
      ).thenAnswer((_) => ++calls == 1 ? oldPage.future : newPage.future);
      final oldOperation = controller.loadOlder('thread');
      await switchTo('b');
      await controller.loadMessages('thread');
      final newOperation = controller.loadOlder('thread');
      expect(calls, 2);
      oldPage.complete(Right([_message('old-page')]));
      await oldOperation;
      await controller.loadOlder('thread');
      expect(calls, 2);
      newPage.complete(Right([_message('new-page')]));
      await newOperation;
      final ids = container
          .read(messagingControllerProvider)
          .messagesFor('thread')
          .map((m) => m.id);
      expect(ids, contains('new-page'));
      expect(ids, isNot(contains('old-page')));
    },
  );

  for (final action in [
    'pin',
    'mute',
    'unread',
    'reaction',
    'archive',
    'unsend',
  ]) {
    test('late $action failure leaves account b untouched', () async {
      await controller.loadMessages('thread');
      final pending = Completer<Either<Failure, void>>();
      when(
        () => repo.pinConversation(
          conversationId: 'thread',
          isBuilder: false,
          pin: true,
        ),
      ).thenAnswer((_) => pending.future);
      when(
        () => repo.muteConversation(
          conversationId: 'thread',
          isBuilder: false,
          mute: true,
        ),
      ).thenAnswer((_) => pending.future);
      when(
        () => repo.markConversationUnread(
          conversationId: 'thread',
          isBuilder: false,
        ),
      ).thenAnswer((_) => pending.future);
      when(
        () => repo.archiveConversation(
          conversationId: 'thread',
          isBuilder: false,
        ),
      ).thenAnswer((_) => pending.future);
      when(
        () => repo.softDeleteMessage('message-0'),
      ).thenAnswer((_) => pending.future);
      when(
        () => repo.setReaction(
          conversationId: 'thread',
          messageId: 'message-0',
          userId: 'a',
          emoji: '👍',
        ),
      ).thenAnswer((_) => pending.future);
      final operation = switch (action) {
        'pin' => controller.pinConversation('thread', pin: true),
        'mute' => controller.muteConversation('thread', mute: true),
        'unread' => controller.markConversationUnread('thread'),
        'archive' => controller.archiveConversation('thread'),
        'unsend' => controller.unsendMessage(
          conversationId: 'thread',
          messageId: 'message-0',
        ),
        _ => controller.toggleReaction(
          conversationId: 'thread',
          messageId: 'message-0',
          emoji: '👍',
        ),
      };
      await switchTo('b');
      pending.complete(const Left(ServerFailure('old error')));
      await operation;
      await _flush();
      expect(container.read(messagingControllerProvider).error, isNull);
      expect(
        container.read(messagingControllerProvider).conversations,
        isEmpty,
      );
      verifyNever(() => repo.getConversations('a'));
    });
  }

  test(
    'history completion after disposal does not mutate or subscribe',
    () async {
      final pending = Completer<Either<Failure, List<Message>>>();
      when(
        () => repo.getMessages('thread', limit: 30),
      ).thenAnswer((_) => pending.future);
      final operation = controller.loadMessages('thread');
      container.dispose();
      disposed = true;
      pending.complete(Right([_message('old')]));
      await expectLater(operation, completes);
      verifyNever(() => repo.watchReactions(any()));
    },
  );

  test(
    'conversation creation from an old session cannot navigate a new user',
    () async {
      final pending = Completer<Either<Failure, String>>();
      when(
        () => repo.getOrCreateConversation(
          builderId: 'builder',
          tradeId: 'a',
          jobId: null,
        ),
      ).thenAnswer((_) => pending.future);
      final operation = controller.getOrCreateConversation(
        builderId: 'builder',
        tradeId: 'a',
      );
      await switchTo('b');
      pending.complete(const Right('old-thread'));
      expect(await operation, isNull);
    },
  );
}
