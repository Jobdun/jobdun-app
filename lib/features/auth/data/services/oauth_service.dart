import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/config/env.dart';

/// Owns Google + Apple SSO. Returns the [supabase.AuthResponse] on success.
/// The controller catches [GoogleSignInException] separately so it can
/// distinguish "user cancelled" from a real failure.
class OAuthService {
  OAuthService(this._client);
  final supabase.SupabaseClient _client;

  static bool _googleInitialized = false;

  /// Throws if `GOOGLE_WEB_CLIENT_ID` isn't configured. The controller surfaces
  /// that as a user-facing error before falling through to the sign-in step.
  Future<supabase.AuthResponse> signInWithGoogle() async {
    if (!AppEnv.isGoogleConfigured) {
      throw StateError(
        'Google Sign-In is not configured yet. '
        'Add GOOGLE_WEB_CLIENT_ID to your .env file.',
      );
    }
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize(
        clientId: AppEnv.googleIosClientId.isEmpty
            ? null
            : AppEnv.googleIosClientId,
        serverClientId: AppEnv.googleWebClientId,
      );
      _googleInitialized = true;
    }

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google sign-in failed: no ID token received.');
    }

    return _client.auth.signInWithIdToken(
      provider: supabase.OAuthProvider.google,
      idToken: idToken,
    );
  }

  Future<supabase.AuthResponse> signInWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256ofString(rawNonce);

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw StateError('Apple sign-in failed: no identity token received.');
    }

    return _client.auth.signInWithIdToken(
      provider: supabase.OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  String _generateNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final rng = Random.secure();
    return List.generate(
      length,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
  }

  String _sha256ofString(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}
