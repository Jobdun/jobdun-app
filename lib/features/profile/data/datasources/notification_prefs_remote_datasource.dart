import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;

import '../../../../core/errors/exceptions.dart';

/// Reads and writes a user's per-category push-notification preferences against
/// `public.notification_preferences` (owner-RLS, PK `(user_id, category)`).
///
/// **Default-on semantics.** A MISSING row means *enabled*. The table only ever
/// stores a row once a user has explicitly toggled a category, so the load path
/// fills in every known category with `true` and lets stored rows override.
/// This keeps the central push trigger (`notifications_push_fanout`) and this UI
/// in agreement: no row ⇒ push allowed.
abstract interface class NotificationPrefsRemoteDataSource {
  /// The user-facing categories, in display order. Mirrors the
  /// `notification_category()` mapper in
  /// `supabase/migrations/20260609000006_notification_preferences.sql`.
  static const List<String> categories = [
    'jobs',
    'applications',
    'messages',
    'reviews',
    'verification',
    'announcements',
  ];

  /// Folds raw `{category, push_enabled}` rows into a complete
  /// `category → bool` map: every entry in [categories] is present, defaulting
  /// to `true`, with any stored row overriding. Unknown categories and null
  /// flags are ignored (fall back to the enabled default). Pure + sync so it's
  /// unit-testable without a Supabase client.
  static Map<String, bool> mapRowsWithDefaults(
    List<Map<String, dynamic>> rows,
  ) {
    final result = <String, bool>{for (final c in categories) c: true};
    for (final row in rows) {
      final category = row['category'];
      final enabled = row['push_enabled'];
      if (category is String &&
          result.containsKey(category) &&
          enabled is bool) {
        result[category] = enabled;
      }
    }
    return result;
  }

  /// The current user's `category → push_enabled` map, always complete across
  /// every entry in [categories] (missing rows default to `true`).
  Future<Map<String, bool>> getPushPreferences(String userId);

  /// Upserts a single `(userId, category)` row's `push_enabled` flag.
  /// Idempotent via `onConflict: 'user_id,category'`.
  Future<void> setPushEnabled({
    required String userId,
    required String category,
    required bool enabled,
  });
}

class NotificationPrefsRemoteDataSourceImpl
    implements NotificationPrefsRemoteDataSource {
  const NotificationPrefsRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  static const _table = 'notification_preferences';

  @override
  Future<Map<String, bool>> getPushPreferences(String userId) async {
    try {
      final rows = await _client
          .from(_table)
          .select('category, push_enabled')
          .eq('user_id', userId);
      return NotificationPrefsRemoteDataSource.mapRowsWithDefaults(rows);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> setPushEnabled({
    required String userId,
    required String category,
    required bool enabled,
  }) async {
    try {
      // Upsert so the first toggle inserts the row and later toggles update it.
      // The PK (user_id, category) drives the conflict target.
      await _client.from(_table).upsert({
        'user_id': userId,
        'category': category,
        'push_enabled': enabled,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,category');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
