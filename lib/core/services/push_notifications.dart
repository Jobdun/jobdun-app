import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// FCM token lifecycle (#8 push rail — client side). Best-effort throughout:
/// every call is guarded so a denied permission or missing config never
/// disrupts the app. Registers this device's token into `device_tokens` for the
/// signed-in user, refreshes it on rotation, and re-registers on sign-in. The
/// SEND side (a `push-send` edge fn keyed on a Firebase service account) consumes
/// these tokens — see docs/PUSH_NOTIFICATIONS_SETUP.md.
class PushNotifications {
  PushNotifications._();

  static bool _wired = false;

  static Future<void> init() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}

    await _register();

    if (!_wired) {
      _wired = true;
      FirebaseMessaging.instance.onTokenRefresh.listen(_upsert);
      SupabaseConfig.client.auth.onAuthStateChange.listen((s) {
        if (s.event == AuthChangeEvent.signedIn) _register();
      });
    }
  }

  static Future<void> _register() async {
    if (SupabaseConfig.client.auth.currentUser == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _upsert(token);
    } catch (_) {}
  }

  static Future<void> _upsert(String token) async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return;
    try {
      await SupabaseConfig.client.from('device_tokens').upsert({
        'user_id': user.id,
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,token');
    } catch (_) {}
  }
}
