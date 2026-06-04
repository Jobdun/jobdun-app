import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pure mapping from a connectivity snapshot to "is the device online?".
///
/// connectivity_plus reports the active network *interfaces*, not real internet
/// reachability — so this is best-effort: any interface other than `none` (or
/// an empty list) counts as online. Actual request failures are still caught as
/// [NetworkFailure] in the data layer; this drives the lightweight UI guardrails
/// (offline banner, map "OFFLINE" chip) only.
bool isOnlineFromResults(List<ConnectivityResult> results) =>
    results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);

/// App-wide reactive online state. Emits the initial status, then updates on
/// every connectivity change. Read as `ref.watch(isOnlineProvider).asData?.value
/// ?? true` — default to online so a not-yet-resolved stream never shows a false
/// "offline" flash.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield isOnlineFromResults(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(isOnlineFromResults);
});
