import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'current_user_provider.dart';

/// Mixin for [Notifier]s that hold per-user data.
///
/// Call [resetOnAccountChange] once in `build()` to clear (and optionally
/// reload) state whenever the signed-in account changes — on logout AND on a
/// switch to a different user. Centralises the listener that was previously
/// hand-copied into every controller (and occasionally forgotten), so a fresh
/// sign-in never inherits the previous account's cache.
///
/// The callback receives the new user id (null on logout) for controllers that
/// need to kick off a reload for the incoming user.
mixin AccountScoped<T> on Notifier<T> {
  void resetOnAccountChange(void Function(String? userId) onChange) {
    ref.listen(currentUserIdProvider, (previous, next) {
      final loggedOut = next.value == null;
      final switched = previous?.value != null && previous?.value != next.value;
      if (loggedOut || switched) onChange(next.value);
    });
  }
}
