import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../navigation/notification_routes.dart';

/// FCM lifecycle (#8 push rail — client side). Best-effort throughout: every
/// call is guarded so a denied permission or missing config (e.g. CI without
/// google-services.json) never disrupts the app.
///
/// Responsibilities:
///  • Token registry — upserts this device's token into `device_tokens` on
///    sign-in/rotation; [unregister] removes it on sign-out. The SEND side
///    (`push-send` edge fn) consumes these — see docs/PUSH_NOTIFICATIONS_SETUP.md.
///  • Tap deep-linking — background/cold-start push taps resolve to a route
///    via [resolveNotificationRoute] and navigate through the router hook
///    wired by [attachNavigator]. Cold-start routes are buffered until the
///    app flushes them post-auth ([flushPendingRoute]).
///  • Foreground banners — Android suppresses FCM display notifications while
///    the app is open, so `onMessage` mirrors them as local heads-up
///    notifications whose taps share the same routing.
class PushNotifications {
  PushNotifications._();

  static bool _wired = false;
  static String? _pendingRoute;
  static void Function(String route)? _navigate;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'jobdun_default',
    'Jobdun notifications',
    description: 'Job activity, messages, and application updates.',
    importance: Importance.high,
  );

  static Future<void> init() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}
    try {
      // iOS suppresses banners for pushes arriving while the app is
      // foregrounded unless we opt in. Android instead mirrors foreground
      // pushes as local notifications in [_showBanner].
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    } catch (_) {}

    await _register();
    await _initForegroundBanners();

    if (!_wired) {
      _wired = true;
      FirebaseMessaging.instance.onTokenRefresh.listen(_upsert);
      SupabaseConfig.client.auth.onAuthStateChange.listen((s) {
        if (s.event == AuthChangeEvent.signedIn) _register();
      });
      _wireTapHandlers();
    }
  }

  // ── Tap deep-linking ───────────────────────────────────────────────────────

  /// Hooked by the app root once the router exists. Replays any buffered
  /// cold-start route on [flushPendingRoute] (called when auth is restored).
  static void attachNavigator(void Function(String route) navigate) {
    _navigate = navigate;
  }

  static void flushPendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    if (route != null) _open(route);
  }

  static void _wireTapHandlers() {
    try {
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => _open(resolveNotificationRoute(data: m.data)),
      );
      FirebaseMessaging.instance.getInitialMessage().then((m) {
        if (m != null) {
          _pendingRoute = resolveNotificationRoute(data: m.data);
        }
      });
    } catch (_) {}
  }

  static void _open(String route) {
    final navigate = _navigate;
    if (navigate == null) {
      _pendingRoute = route;
      return;
    }
    try {
      navigate(route);
    } catch (_) {}
  }

  // ── Foreground banners ─────────────────────────────────────────────────────

  static Future<void> _initForegroundBanners() async {
    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: _onBannerTap,
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
      FirebaseMessaging.onMessage.listen(_showBanner);
    } catch (_) {}
  }

  static Future<void> _showBanner(RemoteMessage message) async {
    // Android-only: FCM suppresses its own display notification while the app
    // is open, so we mirror it locally. iOS presents natively via the
    // foreground presentation options set in [init] — mirroring here too
    // would show the banner twice.
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final title = message.notification?.title;
    if (title == null) return;
    try {
      await _local.show(
        id: message.hashCode,
        title: title,
        body: message.notification?.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    } catch (_) {}
  }

  static void _onBannerTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _open(resolveNotificationRoute(data: data));
    } catch (_) {}
  }

  // ── Token registry ─────────────────────────────────────────────────────────

  static Future<void> _register() async {
    if (SupabaseConfig.client.auth.currentUser == null) return;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          await _awaitApnsToken();
        }
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _upsert(token);
          return;
        }
      } catch (e) {
        debugPrint('PushNotifications._register attempt $attempt failed: $e');
      }
      await Future<void>.delayed(Duration(seconds: 2 * attempt));
    }
  }

  /// On iOS [FirebaseMessaging.getToken] throws `apns-token-not-set` when
  /// called before APNs hands the app its device token, which can lag app
  /// launch by several seconds. Poll until it lands (or give up and let the
  /// caller's retry loop handle it).
  static Future<void> _awaitApnsToken() async {
    for (var i = 0; i < 10; i++) {
      final apns = await FirebaseMessaging.instance.getAPNSToken();
      if (apns != null) return;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
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

  /// Deletes this device's token row. Must run BEFORE `auth.signOut()` (RLS
  /// needs the live session); best-effort so sign-out never blocks on it.
  static Future<void> unregister() async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await SupabaseConfig.client
          .from('device_tokens')
          .delete()
          .eq('user_id', user.id)
          .eq('token', token);
    } catch (_) {}
  }
}
