import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../data/services/admin_session_service.dart';
import '../../domain/entities/admin_session.dart';

final adminSessionServiceProvider = Provider<AdminSessionService>((ref) {
  return AdminSessionService(SupabaseConfig.client);
});

class AdminSessionNotifier extends AsyncNotifier<AdminSession?> {
  @override
  Future<AdminSession?> build() async {
    final service = ref.watch(adminSessionServiceProvider);
    // Listen to Supabase auth events — sign-out from another tab, JWT refresh
    // resulting in a non-admin role, etc. — and reconcile state.
    final sub = service.authChanges().listen((_) {
      final restored = service.restore();
      state = AsyncData(restored);
    });
    ref.onDispose(sub.cancel);
    return service.restore();
  }

  Future<void> signIn({required String email, required String password}) async {
    final service = ref.read(adminSessionServiceProvider);
    state = const AsyncLoading();
    try {
      final session = await service.signIn(email: email, password: password);
      state = AsyncData(session);
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }

  Future<void> signOut() async {
    await ref.read(adminSessionServiceProvider).signOut();
    state = const AsyncData(null);
  }
}

final adminSessionProvider =
    AsyncNotifierProvider<AdminSessionNotifier, AdminSession?>(
      AdminSessionNotifier.new,
    );
