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

    final response = await _client.auth.signInWithIdToken(
      provider: supabase.OAuthProvider.google,
      idToken: idToken,
    );

    // Mirror Google profile bits we have on the account object into
    // user_metadata so the handle_new_user trigger's COALESCE catches them
    // even when Supabase Auth's automatic claim mapping changes between
    // SDK versions. Best-effort — failure here doesn't break the signin.
    try {
      final extra = <String, Object>{};
      if (account.displayName != null &&
          account.displayName!.trim().isNotEmpty) {
        extra['full_name'] = account.displayName!.trim();
        extra['name'] = account.displayName!.trim();
      }
      if (account.photoUrl != null && account.photoUrl!.isNotEmpty) {
        extra['avatar_url'] = account.photoUrl!;
        extra['picture'] = account.photoUrl!;
      }
      if (extra.isNotEmpty) {
        await _client.auth.updateUser(supabase.UserAttributes(data: extra));
      }
    } catch (_) {
      // Don't fail the signin if metadata sync hiccups — trigger has its own
      // capture path on next signin, and the completion sheet collects name
      // explicitly if it's still missing.
    }

    return response;
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

    final response = await _client.auth.signInWithIdToken(
      provider: supabase.OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    // Apple returns the name ONLY on the first signin — Apple privacy rule.
    // Capture it into user_metadata immediately so the handle_new_user
    // trigger and the unified completion sheet have something to read on
    // subsequent signins. The trigger's COALESCE looks for full_name first.
    try {
      final first = credential.givenName?.trim();
      final last = credential.familyName?.trim();
      final composed = [
        first,
        last,
      ].where((s) => s != null && s.isNotEmpty).join(' ');
      if (composed.isNotEmpty) {
        await _client.auth.updateUser(
          supabase.UserAttributes(
            data: {'full_name': composed, 'name': composed},
          ),
        );
      }
    } catch (_) {
      // Apple-side name is best-effort. If it fails the completion sheet
      // will ask for the name explicitly on step 2.
    }

    return response;
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
