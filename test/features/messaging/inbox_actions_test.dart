import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/messaging/domain/entities/conversation.dart';
import 'package:jobdun/features/messaging/domain/repositories/message_repository.dart';
import 'package:jobdun/features/messaging/presentation/providers/messaging_provider.dart';
import 'package:jobdun/features/messaging/presentation/state/messaging_state.dart';

class _MockRepo extends Mock implements MessageRepository {}

Conversation _conv({
  required String id,
  DateTime? lastMessageAt,
  DateTime? tradePinnedAt,
  String? name,
  String? preview,
}) => Conversation(
  id: id,
  builderId: 'b',
  tradeId: 'me', // viewer (role unresolved in tests → trade side)
  status: ConversationStatus.active,
  builderUnreadCount: 0,
  tradeUnreadCount: 0,
  createdAt: DateTime(2026, 6, 1),
  lastMessageAt: lastMessageAt,
  tradePinnedAt: tradePinnedAt,
  otherUserDisplayName: name,
  lastMessagePreview: preview,
);

void main() {
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

  /// Seeds the inbox through the public refresh hook.
  Future<MessagingController> seeded(
    ProviderContainer c,
    List<Conversation> convs,
  ) async {
    when(
      () => repo.getConversations('me'),
    ).thenAnswer((_) async => right(convs));
    final ctrl = c.read(messagingControllerProvider.notifier);
    await ctrl.refreshInbox();
    return ctrl;
  }

  group('filteredConversations (search)', () {
    test('matches name or preview, case-insensitive; empty query = all', () {
      final state = MessagingState(
        conversations: [
          _conv(id: '1', name: 'Pinnacle Construct', preview: 'see you at 7'),
          _conv(id: '2', name: 'Tom Sparkie', preview: 'Quote attached'),
        ],
        searchQuery: 'pinn',
      );
      expect(state.filteredConversations.map((c) => c.id), ['1']);
      expect(
        state
            .copyWith(searchQuery: 'QUOTE')
            .filteredConversations
            .map((c) => c.id),
        ['2'],
      );
      expect(state.copyWith(searchQuery: '').filteredConversations.length, 2);
    });
  });

  group('pinConversation', () {
    test('optimistically pins + floats to top; server call made', () async {
      when(
        () => repo.pinConversation(
          conversationId: any(named: 'conversationId'),
          isBuilder: any(named: 'isBuilder'),
          pin: any(named: 'pin'),
        ),
      ).thenAnswer((_) async => right(null));

      final c = makeContainer();
      final ctrl = await seeded(c, [
        _conv(id: 'new', lastMessageAt: DateTime(2026, 6, 10)),
        _conv(id: 'old', lastMessageAt: DateTime(2026, 6, 5)),
      ]);

      await ctrl.pinConversation('old', pin: true);

      final convs = c.read(messagingControllerProvider).conversations;
      expect(convs.first.id, 'old');
      expect(convs.first.isPinnedFor('me'), isTrue);
      verify(
        () => repo.pinConversation(
          conversationId: 'old',
          isBuilder: false,
          pin: true,
        ),
      ).called(1);
    });

    test('failure rolls back via refresh and surfaces error', () async {
      when(
        () => repo.pinConversation(
          conversationId: any(named: 'conversationId'),
          isBuilder: any(named: 'isBuilder'),
          pin: any(named: 'pin'),
        ),
      ).thenAnswer((_) async => left(const ServerFailure('nope')));

      final c = makeContainer();
      final ctrl = await seeded(c, [_conv(id: 'a')]);

      await ctrl.pinConversation('a', pin: true);
      // Error is surfaced synchronously on failure…
      expect(c.read(messagingControllerProvider).error, contains('nope'));

      // …then the rollback refresh re-fetches server truth (and, per the
      // house copyWith semantics, clears the transient error).
      await Future<void>.delayed(Duration.zero);
      final state = c.read(messagingControllerProvider);
      expect(state.conversations.single.isPinnedFor('me'), isFalse);
    });
  });

  group('muteConversation', () {
    test('optimistically flips the viewer-side mute flag', () async {
      when(
        () => repo.muteConversation(
          conversationId: any(named: 'conversationId'),
          isBuilder: any(named: 'isBuilder'),
          mute: any(named: 'mute'),
        ),
      ).thenAnswer((_) async => right(null));

      final c = makeContainer();
      final ctrl = await seeded(c, [_conv(id: 'a')]);

      await ctrl.muteConversation('a', mute: true);
      expect(
        c
            .read(messagingControllerProvider)
            .conversations
            .single
            .isMutedFor('me'),
        isTrue,
      );
    });
  });

  group('markConversationUnread', () {
    test('sets the sentinel badge and bumps totalUnread', () async {
      when(
        () => repo.markConversationUnread(
          conversationId: any(named: 'conversationId'),
          isBuilder: any(named: 'isBuilder'),
        ),
      ).thenAnswer((_) async => right(null));

      final c = makeContainer();
      final ctrl = await seeded(c, [_conv(id: 'a')]);

      await ctrl.markConversationUnread('a');

      final state = c.read(messagingControllerProvider);
      expect(state.conversations.single.unreadCountFor('me'), 1);
      expect(state.totalUnread, 1);
      verify(
        () =>
            repo.markConversationUnread(conversationId: 'a', isBuilder: false),
      ).called(1);
    });
  });
}
