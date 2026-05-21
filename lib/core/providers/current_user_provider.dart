import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';

/// Streams the current Supabase user ID (`null` when signed out).
///
/// Notifiers should `ref.watch(currentUserIdProvider)` instead of reading
/// `SupabaseConfig.client.auth.currentUser?.id` directly — that direct read
/// can't be overridden in tests and silently desyncs when the auth state
/// changes mid-action.
final currentUserIdProvider = StreamProvider<String?>((ref) async* {
  if (!SupabaseConfig.isInitialized) {
    yield null;
    return;
  }
  final client = SupabaseConfig.client;
  yield client.auth.currentUser?.id;
  yield* client.auth.onAuthStateChange.map((event) => event.session?.user.id);
});

/// Synchronous one-shot read of the current user ID. Use inside controller
/// action methods where awaiting the stream would be ceremony — the
/// underlying value is already cached on the auth client.
String? readCurrentUserId(Ref ref) {
  if (!SupabaseConfig.isInitialized) return null;
  return SupabaseConfig.client.auth.currentUser?.id;
}
