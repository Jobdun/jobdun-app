import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/profile/data/datasources/notification_prefs_remote_datasource.dart';
import 'package:jobdun/features/profile/presentation/pages/notification_settings_page.dart';
import 'package:jobdun/features/profile/presentation/providers/notification_prefs_provider.dart';

// Fake datasource so the widget test never touches Supabase. Records the last
// setPushEnabled call so we can assert a toggle persists the right value.
class _FakeDs implements NotificationPrefsRemoteDataSource {
  _FakeDs(this._initial);
  final Map<String, bool> _initial;
  ({String category, bool enabled})? lastWrite;

  @override
  Future<Map<String, bool>> getPushPreferences(String userId) async =>
      Map<String, bool>.from(_initial);

  @override
  Future<void> setPushEnabled({
    required String userId,
    required String category,
    required bool enabled,
  }) async {
    lastWrite = (category: category, enabled: enabled);
  }
}

void main() {
  Widget wrap(_FakeDs ds) => ProviderScope(
    overrides: [
      currentUserIdSyncProvider.overrideWithValue('user-1'),
      notificationPrefsDatasourceProvider.overrideWithValue(ds),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        theme: AppTheme.dark(),
        home: const NotificationSettingsPage(),
      ),
    ),
  );

  testWidgets('renders a labelled toggle per category', (tester) async {
    final ds = _FakeDs({
      for (final cat in NotificationPrefsRemoteDataSource.categories) cat: true,
    });
    await tester.pumpWidget(wrap(ds));
    await tester.pumpAndSettle();

    // PageHeader uppercases its title at render time.
    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('PUSH NOTIFICATIONS'), findsOneWidget);
    for (final label in const [
      'Jobs',
      'Applications',
      'Messages',
      'Reviews',
      'Verification',
      'Announcements',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    // Six categories → six switches.
    expect(find.byType(Switch), findsNWidgets(6));
  });

  testWidgets('flipping a toggle persists the new value via setPushEnabled', (
    tester,
  ) async {
    final ds = _FakeDs({
      for (final cat in NotificationPrefsRemoteDataSource.categories) cat: true,
    });
    await tester.pumpWidget(wrap(ds));
    await tester.pumpAndSettle();

    // Tap the first switch (Jobs) → should write push_enabled = false.
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(ds.lastWrite, isNotNull);
    expect(ds.lastWrite!.category, 'jobs');
    expect(ds.lastWrite!.enabled, isFalse);
  });
}
