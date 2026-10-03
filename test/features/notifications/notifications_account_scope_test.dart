import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/notifications/domain/entities/app_notification.dart';
import 'package:jobdun/features/notifications/domain/repositories/notification_repository.dart';
import 'package:jobdun/features/notifications/presentation/providers/notifications_provider.dart';

AppNotification _notification(String user) => AppNotification(
  id: '$user-notification',
  userId: user,
  type: 'new_job',
  title: 'Job for $user',
  body: '',
  createdAt: DateTime(2026, 10, 1),
);

class _Repository implements NotificationRepository {
  final loads = <String>[];
  final watches = <String>[];
  final streams = <String, StreamController<List<AppNotification>>>{};
  final pendingLoads =
      <String, Completer<Either<Failure, List<AppNotification>>>>{};
  Completer<Either<Failure, void>>? pendingMark;

  @override
  Future<Either<Failure, List<AppNotification>>> getNotifications(
    String userId,
  ) async {
    loads.add(userId);
    final pending = pendingLoads[userId];
    return pending == null
        ? Right([_notification(userId)])
        : await pending.future;
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) {
    watches.add(userId);
    return streams
        .putIfAbsent(userId, StreamController<List<AppNotification>>.broadcast)
        .stream;
  }

  @override
  Future<Either<Failure, void>> markAsRead(String notificationId) async =>
      pendingMark == null ? const Right(null) : await pendingMark!.future;

  @override
  Future<Either<Failure, void>> markAllAsRead(String userId) async =>
      pendingMark == null ? const Right(null) : await pendingMark!.future;

  Future<void> close() async {
    for (final stream in streams.values) {
      await stream.close();
    }
  }
}

Future<void> _flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Repository repo;
  late StreamController<String?> accounts;
  late ProviderContainer container;
  var disposed = false;

  setUp(() {
    disposed = false;
    repo = _Repository();
    accounts = StreamController<String?>.broadcast();
    container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWith((ref) => accounts.stream),
        currentUserIdSyncProvider.overrideWith(
          (ref) => ref.watch(currentUserIdProvider).value,
        ),
      ],
    );
    container.listen(currentUserIdProvider, (_, _) {});
  });

  tearDown(() async {
    if (!disposed) container.dispose();
    await accounts.close();
    await repo.close();
  });

  Future<void> start(String? user) async {
    accounts.add(user);
    await _flush();
    container.listen(notificationsControllerProvider, (_, _) {});
    await _flush();
  }

  Future<void> switchTo(String? user) async {
    accounts.add(user);
    await _flush();
  }

  NotificationsState state() => container.read(notificationsControllerProvider);

  test('first sign-in starts notification loading and realtime', () async {
    await start(null);
    await switchTo('b');
    expect(repo.loads, ['b']);
    expect(repo.watches, ['b']);
    expect(state().notifications, [_notification('b')]);
  });

  test('logout then sign-in starts a fresh account subscription', () async {
    await start('a');
    await switchTo(null);
    expect(state().notifications, isEmpty);
    expect(repo.streams['a']!.hasListener, isFalse);
    await switchTo('b');
    expect(repo.loads, ['a', 'b']);
    expect(repo.watches, ['a', 'b']);
    expect(state().notifications, [_notification('b')]);
  });

  test('direct account switch replaces the live notification feed', () async {
    await start('a');
    await switchTo('b');
    repo.streams['a']!.add([_notification('old-a')]);
    repo.streams['b']!.add([_notification('fresh-b')]);
    await _flush();
    expect(state().notifications, [_notification('fresh-b')]);
    expect(repo.streams['a']!.hasListener, isFalse);
    expect(repo.streams['b']!.hasListener, isTrue);
  });

  for (final nextUser in <String?>[null, 'b']) {
    test(
      'late load cannot restore account a after switch to $nextUser',
      () async {
        final pending = Completer<Either<Failure, List<AppNotification>>>();
        repo.pendingLoads['a'] = pending;
        await start('a');
        await switchTo(nextUser);
        pending.complete(Right([_notification('a')]));
        await _flush();
        expect(
          state().notifications,
          nextUser == null ? isEmpty : [_notification('b')],
        );
        expect(repo.watches, nextUser == null ? isEmpty : ['b']);
        if (nextUser != null) {
          expect(repo.streams['b']!.hasListener, isTrue);
        }
      },
    );
  }

  for (final markAll in [false, true]) {
    test(
      'late ${markAll ? 'markAllRead' : 'markRead'} failure cannot restore a',
      () async {
        await start('a');
        repo.pendingMark = Completer<Either<Failure, void>>();
        final controller = container.read(
          notificationsControllerProvider.notifier,
        );
        final operation = markAll
            ? controller.markAllRead()
            : controller.markRead('a-notification');
        await switchTo('b');
        repo.pendingMark!.complete(const Left(ServerFailure('old failure')));
        await operation;
        expect(state().notifications, [_notification('b')]);
        expect(state().unreadCount, 1);
        expect(state().error, isNull);
      },
    );
  }

  test('late load failure cannot replace the new account status', () async {
    final pending = Completer<Either<Failure, List<AppNotification>>>();
    repo.pendingLoads['a'] = pending;
    await start('a');
    await switchTo('b');
    pending.complete(const Left(ServerFailure('old account failure')));
    await _flush();
    expect(state().notifications, [_notification('b')]);
    expect(state().error, isNull);
    expect(repo.watches, ['b']);
  });

  test('an old session result stays stale after signing back into a', () async {
    final pending = Completer<Either<Failure, List<AppNotification>>>();
    repo.pendingLoads['a'] = pending;
    await start('a');
    await switchTo(null);
    repo.pendingLoads.remove('a');
    await switchTo('a');
    pending.complete(Right([_notification('old-a-session')]));
    await _flush();
    expect(state().notifications, [_notification('a')]);
    expect(repo.watches, ['a']);
  });

  test(
    'load completion after disposal does not start a watch or throw',
    () async {
      await start('a');
      final pending = Completer<Either<Failure, List<AppNotification>>>();
      repo.pendingLoads['a'] = pending;
      final operation = container
          .read(notificationsControllerProvider.notifier)
          .load();
      container.dispose();
      disposed = true;
      pending.complete(Right([_notification('a')]));
      await expectLater(operation, completes);
      expect(repo.streams['a']!.hasListener, isFalse);
    },
  );
}
