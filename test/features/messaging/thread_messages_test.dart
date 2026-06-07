import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/features/messaging/domain/entities/message.dart';
import 'package:jobdun/features/messaging/presentation/state/thread_messages.dart';

Message _msg({
  required String id,
  required String senderId,
  required DateTime createdAt,
  String body = 'hi',
  String? clientTag,
}) => Message(
  id: id,
  conversationId: 'c1',
  senderId: senderId,
  body: body,
  createdAt: createdAt,
  clientTag: clientTag,
);

PendingMessage _pending({
  required String clientTag,
  required DateTime createdAt,
  String senderId = 'me',
  bool failed = false,
}) => PendingMessage(
  clientTag: clientTag,
  conversationId: 'c1',
  senderId: senderId,
  body: 'hi',
  createdAt: createdAt,
  failed: failed,
);

void main() {
  final t1 = DateTime(2026, 6, 8, 10);
  final t2 = DateTime(2026, 6, 8, 10, 5);

  group('buildThreadEntries', () {
    test('an optimistic outbox message renders as sending', () {
      final entries = buildThreadEntries(
        confirmed: const [],
        outbox: [_pending(clientTag: 'tag-1', createdAt: t1)],
        otherLastReadAt: null,
        me: 'me',
      );

      expect(entries, hasLength(1));
      expect(entries.single.status, MessageStatus.sending);
      expect(entries.single.isPending, isTrue);
      expect(entries.single.clientTag, 'tag-1');
    });

    test('a failed outbox message renders as failed', () {
      final entries = buildThreadEntries(
        confirmed: const [],
        outbox: [_pending(clientTag: 'tag-1', createdAt: t1, failed: true)],
        otherLastReadAt: null,
        me: 'me',
      );

      expect(entries.single.status, MessageStatus.failed);
    });

    test('the server echo dedups the optimistic twin by client_tag', () {
      final entries = buildThreadEntries(
        confirmed: [
          _msg(id: 'm1', senderId: 'me', createdAt: t1, clientTag: 'tag-1'),
        ],
        outbox: [_pending(clientTag: 'tag-1', createdAt: t1)],
        otherLastReadAt: null,
        me: 'me',
      );

      // Only the confirmed server row survives — no duplicate bubble.
      expect(entries, hasLength(1));
      expect(entries.single.isPending, isFalse);
      expect(entries.single.key, 'm1');
      expect(entries.single.status, MessageStatus.sent);
    });

    test('my message is seen once the counterparty has read at/after it', () {
      final entries = buildThreadEntries(
        confirmed: [_msg(id: 'm1', senderId: 'me', createdAt: t1)],
        outbox: const [],
        otherLastReadAt: t1, // exactly at the message time → seen
        me: 'me',
      );

      expect(entries.single.status, MessageStatus.seen);
    });

    test('my message is only sent when the read marker predates it', () {
      final entries = buildThreadEntries(
        confirmed: [_msg(id: 'm1', senderId: 'me', createdAt: t2)],
        outbox: const [],
        otherLastReadAt: t1, // read marker is older than the message
        me: 'me',
      );

      expect(entries.single.status, MessageStatus.sent);
    });

    test('an incoming message never shows as seen', () {
      final entries = buildThreadEntries(
        confirmed: [_msg(id: 'm1', senderId: 'other', createdAt: t1)],
        outbox: const [],
        otherLastReadAt: DateTime(2030), // far in the future
        me: 'me',
      );

      expect(entries.single.status, isNot(MessageStatus.seen));
    });

    test('confirmed rows are deduped by id and ordered oldest→newest', () {
      final entries = buildThreadEntries(
        confirmed: [
          _msg(id: 'm2', senderId: 'me', createdAt: t2),
          _msg(id: 'm1', senderId: 'other', createdAt: t1),
          _msg(id: 'm1', senderId: 'other', createdAt: t1), // duplicate id
        ],
        outbox: const [],
        otherLastReadAt: null,
        me: 'me',
      );

      expect(entries.map((e) => e.key).toList(), ['m1', 'm2']);
    });
  });
}
