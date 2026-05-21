import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Owns the phone-OTP flows: SMS sign-in (`signInWithOtp`) plus the
/// add-phone-to-existing-account dance (`updateUser` → `verifyOTP` with
/// `OtpType.phoneChange`).
///
/// Distinct from email auth because:
///   • `signInWithOtp` creates a brand-new user when the phone is unknown
///   • `updateUser(phone: ...)` attaches the phone to the currently signed-in
///     user and sends an SMS challenge that flips
///     `auth.users.phone_confirmed_at` when verified via `type=phoneChange`.
///     The 20260514000002 trigger then mirrors that into
///     `profiles.phone_verified_at`.
class PhoneAuthService {
  PhoneAuthService(this._client);
  final supabase.SupabaseClient _client;

  Future<void> sendOtp(String phone) =>
      _client.auth.signInWithOtp(phone: phone.trim());

  Future<supabase.AuthResponse> verifyOtp({
    required String phone,
    required String token,
  }) => _client.auth.verifyOTP(
    phone: phone,
    token: token.trim(),
    type: supabase.OtpType.sms,
  );

  Future<void> sendPhoneVerification(String phone) =>
      _client.auth.updateUser(supabase.UserAttributes(phone: phone.trim()));

  /// Confirms the SMS code sent by [sendPhoneVerification]. `type=phoneChange`
  /// so Supabase Auth flips `phone_confirmed_at` instead of trying to create a
  /// new session (the existing one stays valid).
  Future<void> confirmPhoneVerification({
    required String phone,
    required String token,
  }) => _client.auth.verifyOTP(
    phone: phone,
    token: token.trim(),
    type: supabase.OtpType.phoneChange,
  );

  Future<void> resendOtp(String phone) =>
      _client.auth.signInWithOtp(phone: phone);
}
