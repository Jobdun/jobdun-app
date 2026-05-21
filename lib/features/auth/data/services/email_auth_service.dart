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
    // Sends the user back into the app via the registered URL scheme.
    // Hosted Supabase Dashboard must allowlist SupabaseConfig.authRedirectUrl.
    emailRedirectTo: SupabaseConfig.authRedirectUrl,
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
    emailRedirectTo: SupabaseConfig.authRedirectUrl,
  );

  Future<void> sendPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(email.trim());

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
