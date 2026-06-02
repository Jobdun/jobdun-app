import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/messaging/data/models/conversation_model.dart';
import 'package:jobdun/features/messaging/domain/entities/conversation.dart';

Map<String, dynamic> _row() => {
  'id': 'c1',
  'job_id': 'j1',
  'builder_id': 'b1',
  'trade_id': 't1',
  'last_message_at': '2026-06-03T10:00:00Z',
  'last_message_preview': 'hi there',
  'last_message_sender_id': 't1',
  'status': 'active',
  'created_at': '2026-06-01T00:00:00Z',
  'my_unread_count': 2,
  'other_display_name': 'Marcus Webb',
  'other_avatar_url': null,
  'job_title': 'Switchboard',
};

void main() {
  group('ConversationModel.fromInboxRow', () {
    test('maps counterparty + preview + job for a builder viewer', () {
      final c = ConversationModel.fromInboxRow(_row(), viewerId: 'b1');
      expect(c.id, 'c1');
      expect(c.otherUserDisplayName, 'Marcus Webb');
      expect(c.lastMessagePreview, 'hi there');
      expect(c.jobTitle, 'Switchboard');
      expect(c.status, ConversationStatus.active);
    });

    test(
      'routes my_unread_count to the builder side when viewer is builder',
      () {
        final c = ConversationModel.fromInboxRow(_row(), viewerId: 'b1');
        expect(c.builderUnreadCount, 2);
        expect(c.tradeUnreadCount, 0);
        expect(c.unreadCountFor('b1'), 2);
      },
    );

    test('routes my_unread_count to the trade side when viewer is trade', () {
      final c = ConversationModel.fromInboxRow(_row(), viewerId: 't1');
      expect(c.tradeUnreadCount, 2);
      expect(c.builderUnreadCount, 0);
      expect(c.unreadCountFor('t1'), 2);
    });
  });
}
