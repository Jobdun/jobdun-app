import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/config/supabase_config.dart';
import '../../domain/entities/user_role.dart';

/// Thin wrapper around Supabase's email/password auth flows.
///
/// Owns no UI state — returns the raw [supabase.AuthResponse] (or throws)
/// and lets `AuthController` translate that into [AuthState]. This is the
/// boundary between "Supabase calls" and "presentation state" — see
/// CLAUDE.md → Engineering Standards.
class EmailAuthService {
  EmailAuthService(this._client);
  final supabase.SupabaseClient _client;

  Future<supabase.AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email.trim(), password: password);

  Future<supabase.AuthResponse> register({
    required String email,
    required String password,
    required String fullName,
    UserRole? role,
    String? phone,
  }) => _client.auth.signUp(
    email: email.trim(),
    password: password,
    // Sends the user back into the app: the registered URL scheme on native,
    // the /auth/callback page on web (a browser cannot open a custom scheme).
    // Hosted Supabase Dashboard must allowlist BOTH values.
    emailRedirectTo: SupabaseConfig.effectiveAuthRedirectUrl,
    // 'full_name' + 'role' are read by handle_new_user() trigger to write
    // profiles + user_roles + role-specific stub on auth.users INSERT.
    data: {
      'full_name': fullName.trim(),
      if (role != null) 'role': role.name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    },
  );

  Future<void> resendVerification(String email) => _client.auth.resend(
    type: supabase.OtpType.signup,
    email: email,
    emailRedirectTo: SupabaseConfig.effectiveAuthRedirectUrl,
  );

  /// Sends the "reset your password" email.
  ///
  /// `redirectTo` is what brings the user back *into the app* — a deep link on
  /// native, the /auth/callback page on web. Without it Supabase falls back to
  /// the project's Site URL, which is a marketing host with nothing that
  /// handles a recovery token, so the link dead-ends and the password is never
  /// reset. Both values must stay on the Dashboard's redirect allowlist.
  Future<void> sendPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: SupabaseConfig.effectiveAuthRedirectUrl,
      );

  /// Sets a new password on the recovery session created when the user
  /// followed the reset link. Requires an active session — the recovery link
  /// is what grants it, which is why this is only reachable from
  /// `/reset-password` behind the router's recovery gate.
  Future<void> updatePassword(String newPassword) =>
      _client.auth.updateUser(supabase.UserAttributes(password: newPassword));

  /// Refreshes the current session and reports whether the user's email is
  /// now confirmed. Used by the /verify-email "Continue" affordance to pick
  /// up a verification that completed via the email link without an explicit
  /// deep-link return into the app.
  Future<bool> isEmailVerified() async {
    if (_client.auth.currentSession != null) {
      await _client.auth.refreshSession();
    }
    return _client.auth.currentUser?.emailConfirmedAt != null;
  }

  Future<void> signOut() => _client.auth.signOut();
}
