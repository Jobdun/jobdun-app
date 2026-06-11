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

/// Sign-up metadata fallback name (auth.users.user_metadata.full_name) — set
/// by register_page at account creation. Used to prefill name fields for
/// fresh accounts whose profile row is still empty. Overridable in tests so
/// presentation code never touches SupabaseConfig directly.
final signupFullNameProvider = Provider<String?>((ref) {
  if (!SupabaseConfig.isInitialized) return null;
  final raw =
      SupabaseConfig.client.auth.currentUser?.userMetadata?['full_name'];
  if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  return null;
});

/// Overridable provider that returns the current user ID synchronously.
/// In production it watches the stream provider so it always caches the
/// freshest value. In tests, override it.
final currentUserIdSyncProvider = Provider<String?>((ref) {
  if (!SupabaseConfig.isInitialized) return null;
  // Watch the reactive stream so this synchronous provider's cached value
  // stays up-to-date across logouts and account switches.
  final asyncValue = ref.watch(currentUserIdProvider);
  return asyncValue.value ?? SupabaseConfig.client.auth.currentUser?.id;
});
