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

/// Synchronous one-shot read of the current user ID. Backed by
/// [currentUserIdSyncProvider] so tests can override it via
/// `ProviderScope(overrides: [currentUserIdSyncProvider.overrideWithValue('uid')])`.
String? readCurrentUserId(Ref ref) => ref.read(currentUserIdSyncProvider);

/// Overridable provider that returns the current user ID synchronously.
/// In production it reads from the Supabase client; in tests, override it.
final currentUserIdSyncProvider = Provider<String?>((ref) {
  if (!SupabaseConfig.isInitialized) return null;
  return SupabaseConfig.client.auth.currentUser?.id;
});
