import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/data/datasources/notification_prefs_remote_datasource.dart';

// Stream C — notification preferences. A MISSING row means "enabled" (default
// on). The datasource maps whatever rows the table returns into a complete
// Map<String,bool> covering every known category so the UI never renders a
// half-populated toggle list.
void main() {
  group('NotificationPrefsRemoteDataSource.categories', () {
    test('exposes the six push-notification categories in order', () {
      expect(NotificationPrefsRemoteDataSource.categories, const [
        'jobs',
        'applications',
        'messages',
        'reviews',
        'verification',
        'announcements',
      ]);
    });
  });

  group('mapRowsWithDefaults', () {
    test('every category defaults to true when no rows exist', () {
      final map = NotificationPrefsRemoteDataSource.mapRowsWithDefaults(
        const [],
      );

      expect(map.keys, NotificationPrefsRemoteDataSource.categories);
      expect(map.values.every((v) => v == true), isTrue);
    });

    test('an explicit false row overrides the default for that category', () {
      final map = NotificationPrefsRemoteDataSource.mapRowsWithDefaults(const [
        {'category': 'messages', 'push_enabled': false},
      ]);

      expect(map['messages'], isFalse);
      // The other five stay on (missing == enabled).
      expect(map['jobs'], isTrue);
      expect(map['applications'], isTrue);
      expect(map['reviews'], isTrue);
      expect(map['verification'], isTrue);
      expect(map['announcements'], isTrue);
    });

    test('an explicit true row keeps the category enabled', () {
      final map = NotificationPrefsRemoteDataSource.mapRowsWithDefaults(const [
        {'category': 'jobs', 'push_enabled': true},
      ]);

      expect(map['jobs'], isTrue);
    });

    test('a null push_enabled value falls back to the enabled default', () {
      final map = NotificationPrefsRemoteDataSource.mapRowsWithDefaults(const [
        {'category': 'reviews', 'push_enabled': null},
      ]);

      expect(map['reviews'], isTrue);
    });

    test('unknown categories in the payload are ignored, not surfaced', () {
      final map = NotificationPrefsRemoteDataSource.mapRowsWithDefaults(const [
        {'category': 'legacy_unknown', 'push_enabled': false},
      ]);

      expect(map.containsKey('legacy_unknown'), isFalse);
      expect(map.keys, NotificationPrefsRemoteDataSource.categories);
    });

    test('the returned map is complete and reflects every explicit row', () {
      final map = NotificationPrefsRemoteDataSource.mapRowsWithDefaults(const [
        {'category': 'announcements', 'push_enabled': false},
        {'category': 'jobs', 'push_enabled': false},
      ]);

      expect(map.length, 6);
      expect(map['announcements'], isFalse);
      expect(map['jobs'], isFalse);
      expect(map['messages'], isTrue);
    });
  });
}
