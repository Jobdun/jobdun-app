import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/errors/sentry_reporter.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../data/datasources/notification_prefs_remote_datasource.dart';

/// DI seam — the single file in `presentation/` allowed to import `data/`.
/// Public so tests can override it via `ProviderScope(overrides: [...])`.
final notificationPrefsDatasourceProvider =
    Provider<NotificationPrefsRemoteDataSource>(
      (ref) => NotificationPrefsRemoteDataSourceImpl(SupabaseConfig.client),
    );

/// Per-category push-notification toggles for the current user, as an
/// `AsyncValue<category → push_enabled>`. Loads on build; `setPushEnabled`
/// flips optimistically then persists, rolling back the flip on failure.
final notificationPrefsControllerProvider =
    NotifierProvider<
      NotificationPrefsController,
      AsyncValue<Map<String, bool>>
    >(NotificationPrefsController.new);

class NotificationPrefsController
    extends Notifier<AsyncValue<Map<String, bool>>> {
  late NotificationPrefsRemoteDataSource _datasource;

  @override
  AsyncValue<Map<String, bool>> build() {
    _datasource = ref.read(notificationPrefsDatasourceProvider);
    // Initial-load trigger lives in build() per the canonical pattern
    // (ftue_gate_provider) — no addPostFrameCallback in the page.
    Future.microtask(_load);
    return const AsyncValue.loading();
  }

  Future<void> _load() async {
    final userId = readCurrentUserId(ref);
    if (userId == null) {
      // Signed out — fall back to all-enabled defaults rather than an error so
      // the screen still renders sensibly.
      state = AsyncValue.data(
        NotificationPrefsRemoteDataSource.mapRowsWithDefaults(const []),
      );
      return;
    }
    state = const AsyncValue.loading();
    try {
      final prefs = await _datasource.getPushPreferences(userId);
      state = AsyncValue.data(prefs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Re-fetch from the server (e.g. pull-to-retry from an error state).
  Future<void> refresh() => _load();

  /// Toggle a single category's push flag. Optimistic: the switch reflects the
  /// new value immediately; on a persist failure we revert and surface nothing
  /// destructive (the prior value is restored). Returns true on success.
  Future<bool> setPushEnabled(String category, bool enabled) async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return false;

    final current = state.value;
    if (current == null) return false;

    // Optimistic flip.
    final optimistic = Map<String, bool>.from(current)..[category] = enabled;
    state = AsyncValue.data(optimistic);

    try {
      await _datasource.setPushEnabled(
        userId: userId,
        category: category,
        enabled: enabled,
      );
      return true;
    } catch (e, st) {
      // Roll back to the pre-toggle map so the switch snaps back.
      state = AsyncValue.data(current);
      assert(() {
        debugPrint('[NotificationPrefsController] setPushEnabled: $e\n$st');
        return true;
      }());
      unawaited(
        SentryReporter.reportError(
          e,
          stackTrace: st,
          tags: {'feature': 'profile', 'action': 'setPushEnabled'},
        ),
      );
      return false;
    }
  }
}
