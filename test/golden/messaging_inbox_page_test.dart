import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/app/theme/app_colors.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/messaging/domain/entities/conversation.dart';
import 'package:jobdun/features/messaging/domain/repositories/message_repository.dart';
import 'package:jobdun/features/messaging/presentation/pages/messages_page.dart';
import 'package:jobdun/features/messaging/presentation/providers/messaging_provider.dart';

import '_harness.dart';

class _MockRepo extends Mock implements MessageRepository {}

// Mirrors `_harness.dart`'s golden theme — reproduced here because the inbox
// needs its own ProviderScope + a full-screen `home`.
ThemeData _goldenTheme() {
  const c = JColors.light;
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: c.background,
    colorScheme: ColorScheme.light(
      primary: c.action,
      onPrimary: c.onAction,
      secondary: c.surfaceRaised,
      onSecondary: c.text1,
      surface: c.surface,
      onSurface: c.text1,
      error: c.urgent,
    ),
    extensions: const [c],
  );
}

Conversation _conv({
  required String id,
  required String name,
  required String job,
  required String preview,
  required int minutesAgo,
  int unread = 0,
}) => Conversation(
  id: id,
  builderId: 'other',
  tradeId: 'me',
  status: ConversationStatus.active,
  builderUnreadCount: 0,
  tradeUnreadCount: unread,
  createdAt: DateTime(2026, 8, 29),
  lastMessageAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
  lastMessagePreview: preview,
  otherUserDisplayName: name,
  jobTitle: job,
);

void main() {
  testWidgets('inbox page golden (light)', (tester) async {
    final repo = _MockRepo();
    when(() => repo.getConversations(any())).thenAnswer(
      (_) async => right([
        _conv(
          id: 'c1',
          name: 'Ken Garcia',
          job: 'Switchboard upgrade + install',
          preview: 'No worries. See you Friday 7am, mate.',
          minutesAgo: 56,
        ),
        _conv(
          id: 'c2',
          name: 'Sam Boyd',
          job: 'Deck rebuild — Marrickville',
          preview: 'Sent the quote through just now.',
          minutesAgo: 190,
          unread: 3,
        ),
        _conv(
          id: 'c3',
          name: 'Ali Tran',
          job: 'Bathroom reno second fix',
          preview: 'Can you do Tuesday instead?',
          minutesAgo: 1500,
        ),
      ]),
    );
    when(
      () => repo.watchConversations(any()),
    ).thenAnswer((_) => const Stream.empty());

    await tester.binding.setSurfaceSize(kGoldenSurface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messageRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWith((ref) => Stream.value('me')),
          currentUserIdSyncProvider.overrideWithValue('me'),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            size: kGoldenSurface,
            devicePixelRatio: 1.0,
          ),
          child: ScreenUtilInit(
            designSize: kGoldenSurface,
            useInheritedMediaQuery: true,
            builder: (_, _) => MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _goldenTheme(),
              home: const MessagesPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // JStaggeredList fades each row in on a per-index delay — advance past the
    // whole cascade so the golden captures settled rows, not mid-entrance ones.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await expectLater(
      find.byType(MessagesPage),
      matchesGoldenFile('goldens/messaging_inbox_page.png'),
    );
  });
}
