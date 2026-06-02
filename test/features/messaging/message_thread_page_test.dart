import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/app/theme/app_colors.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/messaging/domain/entities/message.dart';
import 'package:jobdun/features/messaging/domain/repositories/message_repository.dart';
import 'package:jobdun/features/messaging/presentation/pages/message_thread_page.dart';
import 'package:jobdun/features/messaging/presentation/providers/messaging_provider.dart';

class _MockRepo extends Mock implements MessageRepository {}

// Deterministic theme: JColors extension (what `context.c` reads) + default
// TextTheme — avoids the google_fonts network fetch that AppTheme triggers.
ThemeData _testTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  extensions: const [JColors.dark],
);

void main() {
  _MockRepo buildRepo() {
    final repo = _MockRepo();
    when(() => repo.getMessages(any())).thenAnswer(
      (_) async => right([
        Message(
          id: 'm1',
          conversationId: 'c1',
          senderId: 'other',
          body: 'Hello there',
          createdAt: DateTime(2026, 6, 3, 10),
        ),
      ]),
    );
    when(
      () => repo.watchMessages(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => repo.markConversationRead(
        conversationId: any(named: 'conversationId'),
        userId: any(named: 'userId'),
        isBuilder: any(named: 'isBuilder'),
      ),
    ).thenAnswer((_) async => right(null));
    when(
      () => repo.sendMessage(
        conversationId: any(named: 'conversationId'),
        senderId: any(named: 'senderId'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => right(null));
    return repo;
  }

  Future<void> pumpThread(WidgetTester tester, MessageRepository repo) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
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
            size: Size(390, 844),
            devicePixelRatio: 1.0,
          ),
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            useInheritedMediaQuery: true,
            builder: (_, _) => MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _testTheme(),
              home: const MessageThreadPage(
                args: ConversationArgs(
                  conversationId: 'c1',
                  otherName: 'Marcus',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(); // run the initState microtask
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('loads messages from the controller on open', (tester) async {
    final repo = buildRepo();
    await pumpThread(tester, repo);

    expect(find.text('Hello there'), findsOneWidget);
    verify(() => repo.getMessages('c1')).called(1);
  });

  testWidgets('send routes the typed text through sendMessage', (tester) async {
    final repo = buildRepo();
    await pumpThread(tester, repo);

    await tester.enterText(find.byType(TextField), 'My reply');
    await tester.tap(find.byKey(const Key('thread-send')));
    await tester.pump();

    verify(
      () => repo.sendMessage(
        conversationId: 'c1',
        senderId: 'me',
        body: 'My reply',
      ),
    ).called(1);
  });
}
