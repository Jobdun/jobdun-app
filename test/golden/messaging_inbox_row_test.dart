import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/messaging/presentation/widgets/conversation_row.dart';

import '_harness.dart';

void main() {
  group('Inbox row goldens (light)', () {
    testWidgets('read / unread / blocked stack', (tester) async {
      await pumpGolden(
        tester,
        padding: EdgeInsets.zero,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConversationRow(
              initials: 'KG',
              name: 'Ken Garcia',
              jobTitle: 'Switchboard upgrade + install',
              preview: 'No worries. See you Friday 7am, mate.',
              time: '56m',
              unreadCount: 0,
              onTap: () {},
            ),
            ConversationRow(
              initials: 'SB',
              name: 'Sam Boyd',
              jobTitle: 'Deck rebuild — Marrickville',
              preview: 'Sent the quote through just now.',
              time: '2h',
              unreadCount: 3,
              isPinned: true,
              onTap: () {},
            ),
            ConversationRow(
              initials: 'AT',
              name: 'Ali Tran',
              jobTitle: 'Bathroom reno second fix',
              preview: 'ignored',
              time: '3d',
              unreadCount: 0,
              isMuted: true,
              isBlocked: true,
              onTap: () {},
            ),
          ],
        ),
      );
      await expectLater(
        find.byType(Column).first,
        matchesGoldenFile('goldens/messaging_inbox_rows.png'),
      );
    });
  });
}
