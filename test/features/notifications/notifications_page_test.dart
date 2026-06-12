import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/notifications/domain/entities/app_notification.dart';
import 'package:jobdun/features/notifications/domain/repositories/notification_repository.dart';
import 'package:jobdun/features/notifications/presentation/pages/notifications_page.dart';
import 'package:jobdun/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

AppNotification _n({
  required String id,
  String type = 'new_job',
  String title = 'New job near you',
  DateTime? readAt,
}) => AppNotification(
  id: id,
  userId: 'user-1',
  type: type,
  title: title,
  body: 'Deck build — Carpenter',
  createdAt: DateTime(2026, 6, 11),
  readAt: readAt,
);

void main() {
  late _MockNotificationRepository repo;

  setUp(() {
    repo = _MockNotificationRepository();
    when(
      () => repo.watchNotifications(any()),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => repo.markAsRead(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => repo.markAllAsRead(any()),
    ).thenAnswer((_) async => const Right(null));
  });

  Widget wrap(List<AppNotification> rows) {
    when(
      () => repo.getNotifications('user-1'),
    ).thenAnswer((_) async => Right(rows));
    return ProviderScope(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repo),
        currentUserIdSyncProvider.overrideWithValue('user-1'),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.dark(),
          home: const NotificationsPage(),
        ),
      ),
    );
  }

  testWidgets('empty feed shows the zero state and no mark-all action', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const []));
    await tester.pumpAndSettle();

    expect(find.text('NO NOTIFICATIONS YET'), findsOneWidget);
    expect(find.text('MARK ALL READ'), findsNothing);
  });

  testWidgets('mixed feed groups into NEW and EARLIER with mark-all action', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap([
        _n(id: 'n-1'),
        _n(id: 'n-2', type: 'message_received', title: 'New message'),
        _n(id: 'n-3', readAt: DateTime(2026, 6, 10), title: 'Shortlisted'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('EARLIER'), findsOneWidget);
    expect(find.text('MARK ALL READ'), findsOneWidget);
    expect(find.text('New job near you'), findsOneWidget);
    expect(find.text('New message'), findsOneWidget);
    expect(find.text('Shortlisted'), findsOneWidget);
  });

  testWidgets('fully-read feed has no NEW section and no mark-all action', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap([_n(id: 'n-1', readAt: DateTime(2026, 6, 10))]),
    );
    await tester.pumpAndSettle();

    expect(find.text('NEW'), findsNothing);
    expect(find.text('EARLIER'), findsOneWidget);
    expect(find.text('MARK ALL READ'), findsNothing);
  });

  testWidgets('tapping an unread row marks it read', (tester) async {
    await tester.pumpWidget(wrap([_n(id: 'n-1')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New job near you'));
    await tester.pumpAndSettle();

    verify(() => repo.markAsRead('n-1')).called(1);
  });
}
