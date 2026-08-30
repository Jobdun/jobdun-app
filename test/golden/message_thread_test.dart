import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/app/theme/app_colors.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/messaging/data/services/messaging_realtime_service.dart';
import 'package:jobdun/features/messaging/domain/entities/conversation_typing.dart';
import 'package:jobdun/features/messaging/domain/entities/message.dart';
import 'package:jobdun/features/messaging/domain/repositories/message_repository.dart';
import 'package:jobdun/features/messaging/presentation/pages/message_thread_page.dart';
import 'package:jobdun/features/messaging/presentation/providers/messaging_provider.dart';
import 'package:jobdun/features/messaging/presentation/providers/messaging_realtime_provider.dart';

import '_harness.dart';

class _MockRepo extends Mock implements MessageRepository {}

class _FakeRealtime implements MessagingRealtimeService {
  @override
  Stream<Set<String>> onlineUserIds(String myUserId) => const Stream.empty();

  @override
  ConversationTyping joinTyping({
    required String conversationId,
    required String myUserId,
  }) => ConversationTyping(
    otherIsTyping: const Stream.empty(),
    setTyping: (_) {},
    dispose: () async {},
  );
}

// Mirrors `_harness.dart`'s golden theme (light tokens, stock TextTheme so no
// google_fonts fetch) — reproduced here because the thread page needs its own
// ProviderScope + full-screen `home`, which `pumpGolden` doesn't provide.
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

Message _msg(String id, String sender, String body, DateTime at) => Message(
  id: id,
  conversationId: 'c1',
  senderId: sender,
  body: body,
  createdAt: at,
);

void main() {
  testWidgets('thread page golden (light)', (tester) async {
    final repo = _MockRepo();
    // Anchor to TODAY at a fixed clock time: the transcript's day separator
    // reads off DateTime.now(), so a hard-coded calendar date flips the label
    // from "TODAY" to "YESTERDAY" the next morning and the golden goes red.
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day, 11, 10);
    when(
      () => repo.getMessages(
        any(),
        limit: any(named: 'limit'),
        before: any(named: 'before'),
      ),
    ).thenAnswer(
      (_) async => right([
        _msg(
          'm1',
          'other',
          'For every switchboard upgrade, we recommend using approximately 2 '
              'units of wiring for each circuit. This ensures optimal '
              'performance and safety.',
          base,
        ),
        _msg(
          'm2',
          'me',
          "What's the best way to install the new switchboard?",
          base.add(const Duration(minutes: 5)),
        ),
        _msg(
          'm3',
          'other',
          'Kill the main, pull the old board, then land the new one on the '
              'existing mounts. I will bring the RCBOs.',
          base.add(const Duration(minutes: 13)),
        ),
        _msg(
          'm4',
          'me',
          'Beauty. See you Friday 7am.',
          base.add(const Duration(minutes: 20)),
        ),
      ]),
    );
    when(
      () => repo.watchMessages(any(), tailLimit: any(named: 'tailLimit')),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => repo.watchConversation(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => repo.watchReactions(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => repo.markConversationRead(
        conversationId: any(named: 'conversationId'),
        userId: any(named: 'userId'),
        isBuilder: any(named: 'isBuilder'),
      ),
    ).thenAnswer((_) async => right(null));

    await tester.binding.setSurfaceSize(kGoldenSurface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messageRepositoryProvider.overrideWithValue(repo),
          messagingRealtimeServiceProvider.overrideWithValue(_FakeRealtime()),
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
              home: const MessageThreadPage(
                args: ConversationArgs(
                  conversationId: 'c1',
                  otherName: 'Ken Garcia',
                  jobTitle: 'Switchboard upgrade + install',
                  otherInitials: 'KG',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await expectLater(
      find.byType(MessageThreadPage),
      matchesGoldenFile('goldens/message_thread.png'),
    );
  });
}
