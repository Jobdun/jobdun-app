import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';

/// Pure mapping from a connectivity snapshot to "is the device online?".
///
/// connectivity_plus reports the active network *interfaces*, not real internet
/// reachability — so this is best-effort: any interface other than `none` (or
/// an empty list) counts as online.
bool isOnlineFromResults(List<ConnectivityResult> results) =>
    results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);

/// Combines radio state with a real reachability probe (Phase 2.5,
/// docs/CACHING_ARCHITECTURE.md §3.3). Radio down → offline. Radio up but the
/// probe says unreachable (captive-portal Wi-Fi / backend down) → offline.
/// Probe not yet run ([reachable] == null) → assume online so the UI is never
/// blocked waiting on the probe.
bool resolveReachableOnline({
  required bool radioOnline,
  required bool? reachable,
}) => radioOnline && (reachable ?? true);

/// A best-effort "can we actually reach the backend?" check. Any HTTP response
/// (even an error status) means the network works; a socket error / timeout
/// means it doesn't. Overridable in tests.
typedef ReachabilityProbe = Future<bool> Function();

final reachabilityProbeProvider = Provider<ReachabilityProbe>(
  (ref) => defaultReachabilityProbe,
);

/// HEAD the Supabase URL with a short timeout. Conservative: returns `true`
/// whenever it can't meaningfully probe (web, or no URL configured) so it never
/// invents a false "offline".
Future<bool> defaultReachabilityProbe() async {
  if (kIsWeb) return true; // dart:io HttpClient is unavailable on web
  final url = AppEnv.supabaseUrl;
  if (url.isEmpty) return true;
  const timeout = Duration(seconds: 3);
  try {
    final client = HttpClient()..connectionTimeout = timeout;
    final request = await client.headUrl(Uri.parse(url)).timeout(timeout);
    final response = await request.close().timeout(timeout);
    await response.drain<void>();
    client.close();
    return true; // got a response → reachable
  } on Exception {
    return false; // socket error / timeout → unreachable
  }
}

/// App-wide reactive online state. Emits the radio status immediately
/// (optimistic), then refines it with the reachability probe. Read as
/// `ref.watch(isOnlineProvider).asData?.value ?? true` — default to online so a
/// not-yet-resolved stream never shows a false "offline" flash.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  final probe = ref.watch(reachabilityProbeProvider);

  Stream<List<ConnectivityResult>> radioStream() async* {
    yield await connectivity.checkConnectivity();
    yield* connectivity.onConnectivityChanged;
  }

  await for (final results in radioStream()) {
    final radioOnline = isOnlineFromResults(results);
    if (!radioOnline) {
      yield false;
      continue;
    }
    yield true; // optimistic — radio is up, paint online without waiting
    final reachable = await probe();
    yield resolveReachableOnline(radioOnline: true, reachable: reachable);
  }
});
