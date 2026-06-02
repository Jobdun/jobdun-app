import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../data/datasources/notification_remote_datasource.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/usecases/get_notifications.dart';
import '../../domain/usecases/mark_all_as_read.dart';
import '../../domain/usecases/mark_as_read.dart';

// ── Data layer providers (public so tests can override) ───────────────────────
final notificationDatasourceProvider = Provider<NotificationRemoteDataSource>(
  (ref) => NotificationRemoteDataSourceImpl(SupabaseConfig.client),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepositoryImpl(ref.read(notificationDatasourceProvider)),
);

// ── Use cases ─────────────────────────────────────────────────────────────────
final getNotificationsUseCaseProvider = Provider(
  (ref) => GetNotifications(ref.read(notificationRepositoryProvider)),
);

final markAsReadUseCaseProvider = Provider(
  (ref) => MarkAsRead(ref.read(notificationRepositoryProvider)),
);

final markAllAsReadUseCaseProvider = Provider(
  (ref) => MarkAllAsRead(ref.read(notificationRepositoryProvider)),
);

// ── Controller ────────────────────────────────────────────────────────────────
final notificationsControllerProvider =
    NotifierProvider<NotificationsController, NotificationsState>(
      NotificationsController.new,
    );

class NotificationsController extends Notifier<NotificationsState> {
  late NotificationRepository _repo;
  StreamSubscription<List<AppNotification>>? _sub;

  @override
  NotificationsState build() {
    _repo = ref.read(notificationRepositoryProvider);
    
    // Clear state on logout or account switch to prevent stale data
    ref.listen(currentUserIdProvider, (previous, next) {
      if (next.value == null || (previous?.value != null && previous?.value != next.value)) {
        _sub?.cancel();
        state = const NotificationsState();
        if (next.value != null) Future.microtask(_loadAndWatch);
      }
    });

    ref.onDispose(() => _sub?.cancel());
    // First-load triggers belong here — CLAUDE.md → Engineering Standards.
    Future.microtask(_loadAndWatch);
    return const NotificationsState();
  }

  Future<void> _loadAndWatch() async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return;
    await load();
    _sub?.cancel();
    _sub = _repo
        .watchNotifications(userId)
        .listen(
          (rows) => state = state.copyWith(
            notifications: rows,
            unreadCount: rows.where((n) => !n.isRead).length,
          ),
          onError: (Object e) => state = state.copyWith(error: e.toString()),
        );
  }

  Future<void> load() async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return;
    state = state.copyWith(isLoading: true, error: null);
    final result = await ref.read(getNotificationsUseCaseProvider).call(userId);
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (rows) => state = state.copyWith(
        isLoading: false,
        notifications: rows,
        unreadCount: rows.where((n) => !n.isRead).length,
      ),
    );
  }

  Future<void> markRead(String notificationId) async {
    // Optimistic — stamp readAt locally, roll back on failure.
    final now = DateTime.now();
    final next = state.notifications
        .map(
          (n) => n.id == notificationId && n.readAt == null
              ? AppNotification(
                  id: n.id,
                  userId: n.userId,
                  type: n.type,
                  title: n.title,
                  body: n.body,
                  createdAt: n.createdAt,
                  readAt: now,
                  data: n.data,
                )
              : n,
        )
        .toList();
    state = state.copyWith(
      notifications: next,
      unreadCount: next.where((n) => !n.isRead).length,
    );
    final result = await ref
        .read(markAsReadUseCaseProvider)
        .call(notificationId);
    result.fold((f) => state = state.copyWith(error: f.message), (_) {});
  }

  Future<void> markAllRead() async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return;
    final now = DateTime.now();
    final next = state.notifications
        .map(
          (n) => n.readAt != null
              ? n
              : AppNotification(
                  id: n.id,
                  userId: n.userId,
                  type: n.type,
                  title: n.title,
                  body: n.body,
                  createdAt: n.createdAt,
                  readAt: now,
                  data: n.data,
                ),
        )
        .toList();
    state = state.copyWith(notifications: next, unreadCount: 0);
    final result = await ref.read(markAllAsReadUseCaseProvider).call(userId);
    result.fold((f) => state = state.copyWith(error: f.message), (_) {});
  }
}

class NotificationsState {
  const NotificationsState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) => NotificationsState(
    notifications: notifications ?? this.notifications,
    unreadCount: unreadCount ?? this.unreadCount,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}
