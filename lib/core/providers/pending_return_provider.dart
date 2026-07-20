import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where to send the user after they authenticate from a guest gate — e.g.
/// the job they were reading when they tapped APPLY. The router's auth-page
/// redirect consumes it exactly once; sign-out clears it so a later login
/// never replays a stale destination.
final pendingReturnProvider = NotifierProvider<PendingReturnNotifier, String?>(
  PendingReturnNotifier.new,
);

class PendingReturnNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String location) => state = location;

  void clear() => state = null;

  /// Returns the stored location and clears it in the same call.
  String? consume() {
    final v = state;
    state = null;
    return v;
  }
}
