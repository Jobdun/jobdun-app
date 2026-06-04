import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../data/services/messaging_realtime_service.dart';

// Public so tests can override (CLAUDE.md).
final messagingRealtimeServiceProvider = Provider<MessagingRealtimeService>(
  (ref) => MessagingRealtimeService(SupabaseConfig.client),
);

/// Set of currently-online user ids. autoDispose so the presence channel is
/// joined while a presence-aware screen (the thread) is open and removed when
/// it closes. Watching it also tracks the current user as online.
final onlineUserIdsProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final myId = ref.watch(currentUserIdSyncProvider);
  if (myId == null) return Stream.value(const <String>{});
  return ref.watch(messagingRealtimeServiceProvider).onlineUserIds(myId);
});
