import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../domain/entities/admin_session.dart';

/// Sign-in surface for the admin web. Owns the role gate: any account that
/// is not `user_roles.role = 'admin'` is signed out before the session is
/// returned. The admin role itself is non-self-assignable in DB
/// (see `20260516000002_forbid_self_admin.sql`).
class AdminSessionService {
  AdminSessionService(this._client);
  final supabase.SupabaseClient _client;

  Future<AdminSession> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final session = response.session;
    final user = response.user;
    if (session == null || user == null) {
      throw const AdminSignInException('Invalid email or password.');
    }
    if (!_isAdmin(session.accessToken)) {
      await _client.auth.signOut();
      throw const NotAdminException('This account does not have admin access.');
    }
    return AdminSession(userId: user.id, email: user.email ?? email.trim());
  }

  Future<void> signOut() => _client.auth.signOut();

  /// On app start, reads the existing Supabase session (persisted by
  /// supabase_flutter in `localStorage`) and returns an [AdminSession] only
  /// if the JWT carries `user_role = 'admin'`. Anything else returns null.
  AdminSession? restore() {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    if (!_isAdmin(session.accessToken)) return null;
    final user = session.user;
    return AdminSession(userId: user.id, email: user.email ?? '');
  }

  /// Stream of admin-session state changes derived from Supabase's auth
  /// event stream. Used by the router as a [Listenable] source.
  Stream<supabase.AuthState> authChanges() => _client.auth.onAuthStateChange;

  bool _isAdmin(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload) as Map<String, dynamic>;
      return claims['user_role'] == 'admin';
    } catch (_) {
      return false;
    }
  }
}
