import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/config/env.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_role.dart';

export '../../domain/entities/user_role.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  StreamSubscription<supabase.AuthState>? _authSubscription;

  @override
  AuthState build() {
    if (!SupabaseConfig.isInitialized) {
      return const AuthState();
    }

    final client = SupabaseConfig.client;
    _authSubscription?.cancel();
    _authSubscription = client.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      if (session == null) {
        state = const AuthState();
        return;
      }
      // If the user just landed back via the email-verify deep link, the
      // incoming session's emailConfirmedAt is non-null. Clear the pending
      // gate so the router stops pinning them to /verify-email.
      final verified = session.user.emailConfirmedAt != null;
      state = state.copyWith(
        isAuthenticated: true,
        email: session.user.email,
        isLoading: false,
        errorMessage: null,
        infoMessage: null,
        clearPendingVerification: verified,
        clearRegisterDraft: verified,
      );
      // Critical: load role from JWT after every session change (e.g. when
      // the email-verify deep link returns to the app). Without this, home
      // would race-fire RoleSelectionSheet for users who already picked.
      _loadProfileForCurrentUser();
    });
    ref.onDispose(() => _authSubscription?.cancel());

    final session = client.auth.currentSession;
    final user = client.auth.currentUser;
    if (session == null && user == null) {
      return const AuthState();
    }

    // Session exists → user completed onboarding at some point.
    // Load role from DB in the background so home screen personalises correctly.
    Future.microtask(_loadProfileForCurrentUser);

    return AuthState(
      isAuthenticated: true,
      onboardingComplete: true,
      email: user?.email ?? session?.user.email,
    );
  }

  // ── Profile helper ─────────────────────────────────────────────────────────

  // Role lives in user_roles table, injected into JWT via custom_access_token_hook.
  // Read it from the JWT claim — never from a profiles.role column (doesn't exist).
  UserRole? _roleFromSession() {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session == null) return null;
    try {
      final parts = session.accessToken.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final claims = jsonDecode(decoded) as Map<String, dynamic>;
      final roleStr = claims['user_role'] as String?;
      if (roleStr == null) return null;
      return UserRole.values.firstWhere(
        (r) => r.name == roleStr,
        orElse: () => UserRole.trade,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadProfileForCurrentUser() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) {
      state = state.copyWith(isRoleLoaded: true);
      return;
    }
    try {
      final data = await SupabaseConfig.client
          .from('profiles')
          .select('onboarding_completed_at')
          .eq('id', userId)
          .maybeSingle();

      final onboardingDone = data?['onboarding_completed_at'] != null;
      final role = _roleFromSession();
      state = state.copyWith(
        role: role,
        onboardingComplete: onboardingDone,
        isRoleLoaded: true,
      );
    } catch (e, st) {
      // Best-effort — don't disrupt the session if profile fetch fails.
      // Mark loaded even on failure so the sheet doesn't hang waiting forever.
      assert(() {
        debugPrint('[AuthController] _loadProfileForCurrentUser: $e\n$st');
        return true;
      }());
      state = state.copyWith(isRoleLoaded: true);
    }
  }

  // Returns true if the authenticated user has completed onboarding in the DB.
  Future<bool> _fetchOnboardingStatus(String? userId) async {
    if (userId == null || !SupabaseConfig.isInitialized) {
      state = state.copyWith(isRoleLoaded: true);
      return false;
    }
    try {
      final data = await SupabaseConfig.client
          .from('profiles')
          .select('onboarding_completed_at')
          .eq('id', userId)
          .maybeSingle();

      // Role comes from JWT after sign-in — refresh it from the token.
      final role = _roleFromSession();
      state = state.copyWith(role: role, isRoleLoaded: true);

      return data?['onboarding_completed_at'] != null;
    } catch (e, st) {
      assert(() {
        debugPrint('[AuthController] _fetchOnboardingStatus: $e\n$st');
        return true;
      }());
      state = state.copyWith(isRoleLoaded: true);
      return false;
    }
  }

  // ── Auth methods ───────────────────────────────────────────────────────────

  Future<bool> signIn({required String email, required String password}) async {
    if (!SupabaseConfig.isInitialized) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Fill .env and run with '
            '--dart-define-from-file=.env.',
        isLoading: false,
        infoMessage: null,
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      infoMessage: null,
    );

    try {
      final response = await SupabaseConfig.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final onboardingDone = await _fetchOnboardingStatus(response.user?.id);

      state = state.copyWith(
        isAuthenticated: response.user != null || response.session != null,
        onboardingComplete: onboardingDone,
        email: response.user?.email ?? email.trim(),
        isLoading: false,
      );
      return state.isAuthenticated;
    } on supabase.AuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMessages.from(AuthFailure(error.message)),
        infoMessage: null,
      );
      return false;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMessages.from(ServerFailure(error.toString())),
        infoMessage: null,
      );
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    UserRole? role,
    String? phone,
  }) async {
    if (!SupabaseConfig.isInitialized) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Fill .env and run with '
            '--dart-define-from-file=.env.',
        isLoading: false,
        infoMessage: null,
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      infoMessage: null,
      // Stash the form values so "Wrong email? Change it" on /verify-email
      // can route back to /register step 2 with everything pre-filled.
      registerDraft: RegisterDraft(
        fullName: fullName.trim(),
        email: email.trim(),
        role: role,
      ),
    );

    try {
      final response = await SupabaseConfig.client.auth.signUp(
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

      if (response.session == null) {
        // Email confirmation required → show verify-email screen.
        state = state.copyWith(
          isLoading: false,
          errorMessage: null,
          infoMessage: null,
          pendingVerificationEmail: response.user?.email ?? email.trim(),
        );
        return false;
      }

      // Email confirmation disabled → signed in immediately, send to onboarding.
      state = state.copyWith(
        isAuthenticated: true,
        onboardingComplete: false,
        email: response.user?.email ?? email.trim(),
        isLoading: false,
        errorMessage: null,
        infoMessage: null,
        clearRole: true,
      );
      return true;
    } on supabase.AuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMessages.from(AuthFailure(error.message)),
        infoMessage: null,
      );
      return false;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMessages.from(ServerFailure(error.toString())),
        infoMessage: null,
      );
      return false;
    }
  }

  Future<void> resendVerificationEmail() async {
    final email = state.pendingVerificationEmail;
    if (email == null || !SupabaseConfig.isInitialized) return;

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      infoMessage: null,
    );
    try {
      await SupabaseConfig.client.auth.resend(
        type: supabase.OtpType.signup,
        email: email,
        emailRedirectTo: SupabaseConfig.authRedirectUrl,
      );
      state = state.copyWith(
        isLoading: false,
        infoMessage: 'Verification email resent. Check your inbox.',
      );
    } on supabase.AuthException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  void clearPendingVerification() {
    state = state.copyWith(clearPendingVerification: true);
  }

  void clearRegisterDraft() {
    state = state.copyWith(clearRegisterDraft: true);
  }

  // Manual "I've verified — continue" check from /verify-email. Tries to pull
  // a fresh session token (works if the email-link round-trip already created
  // a session that the app hasn't picked up yet) and confirms email status.
  // Returns true if confirmed — caller can route forward.
  Future<bool> checkEmailVerified() async {
    if (!SupabaseConfig.isInitialized) return false;
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      infoMessage: null,
    );

    try {
      if (SupabaseConfig.client.auth.currentSession != null) {
        await SupabaseConfig.client.auth.refreshSession();
      }
      final user = SupabaseConfig.client.auth.currentUser;
      final verified = user?.emailConfirmedAt != null;

      if (verified) {
        // Clear the verification gate so the router sends them to /home.
        // The onAuthStateChange listener will load role from JWT.
        state = state.copyWith(
          isLoading: false,
          clearPendingVerification: true,
          clearRegisterDraft: true,
        );
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage:
            "We don't see a verification yet. Check your inbox or resend.",
      );
      return false;
    } catch (e, st) {
      assert(() {
        debugPrint('[AuthController] checkEmailVerified: $e\n$st');
        return true;
      }());
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Couldn't check status. Try again in a moment.",
      );
      return false;
    }
  }

  static bool _googleInitialized = false;

  Future<void> signInWithGoogle() async {
    if (!AppEnv.isGoogleConfigured) {
      state = state.copyWith(
        errorMessage:
            'Google Sign-In is not configured yet. '
            'Add GOOGLE_WEB_CLIENT_ID to your .env file.',
        isLoading: false,
        infoMessage: null,
      );
      return;
    }

    if (!SupabaseConfig.isInitialized) {
      state = state.copyWith(
        errorMessage: 'Supabase is not configured.',
        isLoading: false,
        infoMessage: null,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      infoMessage: null,
    );

    try {
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
        throw Exception('Google sign-in failed: no ID token received.');
      }

      final response = await SupabaseConfig.client.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.google,
        idToken: idToken,
      );

      final onboardingDone = await _fetchOnboardingStatus(response.user?.id);

      // Role stays whatever the JWT says (set in _fetchOnboardingStatus).
      // Null role + authenticated → RoleSelectionSheet handles it on home.
      state = state.copyWith(
        isAuthenticated: response.user != null,
        onboardingComplete: onboardingDone,
        email: response.user?.email,
        isLoading: false,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        state = state.copyWith(isLoading: false);
        return;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
        infoMessage: null,
      );
    } on supabase.AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
        infoMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
        infoMessage: null,
      );
    }
  }

  Future<void> signInWithApple() async {
    if (!SupabaseConfig.isInitialized) {
      state = state.copyWith(
        errorMessage: 'Supabase is not configured.',
        isLoading: false,
        infoMessage: null,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      infoMessage: null,
    );

    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw Exception('Apple sign-in failed: no identity token received.');
      }

      final response = await SupabaseConfig.client.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      final onboardingDone = await _fetchOnboardingStatus(response.user?.id);

      // Role stays whatever the JWT says (set in _fetchOnboardingStatus).
      // Null role + authenticated → RoleSelectionSheet handles it on home.
      state = state.copyWith(
        isAuthenticated: response.user != null,
        onboardingComplete: onboardingDone,
        email: response.user?.email,
        isLoading: false,
      );
    } on supabase.AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
        infoMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
        infoMessage: null,
      );
    }
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

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  Future<void> completeOnboarding(
    UserRole role, {
    String? location,
    String? companyName,
    String? businessType,
    String? tradeCategory,
    String? yearsExperience,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      if (SupabaseConfig.isInitialized) {
        final userId = SupabaseConfig.client.auth.currentUser?.id;
        if (userId != null) {
          // Mark onboarding complete via onboarding_completed_at (schema column).
          await SupabaseConfig.client
              .from('profiles')
              .update({
                'onboarding_completed_at': DateTime.now().toIso8601String(),
              })
              .eq('id', userId);

          // Assign role in user_roles (drives JWT claim via custom_access_token_hook).
          await SupabaseConfig.client.from('user_roles').upsert({
            'user_id': userId,
            'role': role.name,
          }, onConflict: 'user_id');

          if (role == UserRole.builder) {
            // builder_profiles.id is PK = profiles.id (not profile_id)
            final builderData = <String, dynamic>{'id': userId};
            if (companyName != null) builderData['company_name'] = companyName;
            if (builderData.length > 1) {
              await SupabaseConfig.client
                  .from('builder_profiles')
                  .upsert(builderData, onConflict: 'id');
            }
          } else if (role == UserRole.trade) {
            // trade_profiles.id is PK = profiles.id (not profile_id)
            final tradeData = <String, dynamic>{'id': userId};
            if (tradeCategory != null) {
              tradeData['primary_trade'] = tradeCategory;
            }
            if (yearsExperience != null) {
              tradeData['years_experience'] =
                  int.tryParse(yearsExperience) ?? 0;
            }
            if (tradeData.length > 1) {
              await SupabaseConfig.client
                  .from('trade_profiles')
                  .upsert(tradeData, onConflict: 'id');
            }
          }
        }
      }
    } catch (e, st) {
      // Best-effort — don't block the user from progressing, but surface the error.
      assert(() {
        debugPrint('[AuthController] completeOnboarding: $e\n$st');
        return true;
      }());
      state = state.copyWith(
        infoMessage: 'Profile saved locally. Some details may sync later.',
      );
    }

    state = state.copyWith(
      role: role,
      onboardingComplete: true,
      isLoading: false,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    if (!SupabaseConfig.isInitialized) {
      state = state.copyWith(
        errorMessage: 'Supabase is not configured.',
        isLoading: false,
        infoMessage: null,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      infoMessage: null,
    );

    try {
      await SupabaseConfig.client.auth.resetPasswordForEmail(email.trim());
      state = state.copyWith(
        isLoading: false,
        infoMessage: 'Check your email for a reset link.',
      );
    } on supabase.AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMessages.from(AuthFailure(e.message)),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMessages.from(ServerFailure(e.toString())),
      );
    }
  }

  // ── Phone / OTP ────────────────────────────────────────────────────────────

  Future<bool> signInWithPhone(String phone) async {
    if (!SupabaseConfig.isInitialized) {
      state = state.copyWith(
        errorMessage: 'Supabase is not configured.',
        isLoading: false,
        infoMessage: null,
      );
      return false;
    }
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      infoMessage: null,
    );
    try {
      await SupabaseConfig.client.auth.signInWithOtp(phone: phone.trim());
      state = state.copyWith(
        isLoading: false,
        pendingPhoneNumber: phone.trim(),
        infoMessage: 'Code sent — check your SMS.',
      );
      return true;
    } on supabase.AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMessages.from(AuthFailure(e.message)),
        infoMessage: null,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMessages.from(ServerFailure(e.toString())),
        infoMessage: null,
      );
      return false;
    }
  }

  Future<bool> verifyPhoneOtp(String token) async {
    final phone = state.pendingPhoneNumber;
    if (phone == null || !SupabaseConfig.isInitialized) return false;

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      infoMessage: null,
    );
    try {
      final response = await SupabaseConfig.client.auth.verifyOTP(
        phone: phone,
        token: token.trim(),
        type: supabase.OtpType.sms,
      );
      final onboardingDone = await _fetchOnboardingStatus(response.user?.id);
      state = state.copyWith(
        isAuthenticated: response.user != null,
        onboardingComplete: onboardingDone,
        email: response.user?.email,
        isLoading: false,
        clearPhone: true,
      );
      return state.isAuthenticated;
    } on supabase.AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMessages.from(AuthFailure(e.message)),
        infoMessage: null,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMessages.from(ServerFailure(e.toString())),
        infoMessage: null,
      );
      return false;
    }
  }

  Future<void> resendPhoneOtp() async {
    final phone = state.pendingPhoneNumber;
    if (phone == null || !SupabaseConfig.isInitialized) return;
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      infoMessage: null,
    );
    try {
      await SupabaseConfig.client.auth.signInWithOtp(phone: phone);
      state = state.copyWith(isLoading: false, infoMessage: 'New code sent.');
    } on supabase.AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMessages.from(AuthFailure(e.message)),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMessages.from(ServerFailure(e.toString())),
      );
    }
  }

  void clearPendingPhone() {
    state = state.copyWith(clearPhone: true);
  }

  // Used by the phone-auth restore flow: rehydrates the pending phone from
  // SharedPreferences without sending another SMS (Supabase imposes a 60s
  // resend cooldown, so re-sending would just error out the user).
  void setPendingPhone(String e164) {
    state = state.copyWith(pendingPhoneNumber: e164);
  }

  // ── Role assignment for SSO / fallback ─────────────────────────────────────
  //
  // Called from RoleSelectionSheet when an authenticated user lands on home
  // without a role (typically SSO sign-ups, who don't pass role in metadata).
  // Writes user_roles, creates the role-specific stub profile, refreshes the
  // JWT so the new claim is live, and updates local state.
  Future<bool> setRoleAndStubProfile(UserRole role) async {
    if (!SupabaseConfig.isInitialized) return false;
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Ensure profiles row exists before inserting role-specific child table.
      // The handle_new_user trigger normally creates this, but may race on SSO.
      await SupabaseConfig.client.from('profiles').upsert({
        'id': userId,
      }, onConflict: 'id');

      await SupabaseConfig.client.from('user_roles').upsert({
        'user_id': userId,
        'role': role.name,
      }, onConflict: 'user_id');

      if (role == UserRole.builder) {
        await SupabaseConfig.client.from('builder_profiles').upsert({
          'id': userId,
        }, onConflict: 'id');
      } else if (role == UserRole.trade) {
        await SupabaseConfig.client.from('trade_profiles').upsert({
          'id': userId,
        }, onConflict: 'id');
      }

      // Force a JWT refresh so the new user_role claim is in the session.
      await SupabaseConfig.client.auth.refreshSession();

      state = state.copyWith(role: role, isLoading: false);
      return true;
    } catch (e, st) {
      assert(() {
        debugPrint('[AuthController] setRoleAndStubProfile: $e\n$st');
        return true;
      }());
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMessages.from(ServerFailure(e.toString())),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    if (SupabaseConfig.isInitialized) {
      await SupabaseConfig.client.auth.signOut();
    }
    state = const AuthState();
  }
}

// Snapshot of what the user entered at /register — held in AuthState so the
// "Wrong email? Change it" affordance on /verify-email can return them to
// step 2 of /register with the form pre-filled instead of starting over.
class RegisterDraft {
  const RegisterDraft({required this.fullName, required this.email, this.role});

  final String fullName;
  final String email;
  final UserRole? role;
}

class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.onboardingComplete = false,
    this.isLoading = false,
    // Goes true once we've actually tried to read role from the JWT/DB.
    // Distinguishes "role is null because user hasn't picked" from "role is
    // null because the load hasn't finished yet" — drives RoleSelectionSheet.
    this.isRoleLoaded = false,
    this.role,
    this.email,
    this.pendingVerificationEmail,
    this.pendingPhoneNumber,
    this.registerDraft,
    this.errorMessage,
    this.infoMessage,
  });

  final bool isAuthenticated;
  final bool onboardingComplete;
  final bool isLoading;
  final bool isRoleLoaded;
  final UserRole? role;
  final String? email;
  final String? pendingVerificationEmail;
  final String? pendingPhoneNumber;
  final RegisterDraft? registerDraft;
  final String? errorMessage;
  final String? infoMessage;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? onboardingComplete,
    bool? isLoading,
    bool? isRoleLoaded,
    UserRole? role,
    String? email,
    String? pendingVerificationEmail,
    String? pendingPhoneNumber,
    RegisterDraft? registerDraft,
    String? errorMessage,
    String? infoMessage,
    bool clearRole = false,
    bool clearPendingVerification = false,
    bool clearPhone = false,
    bool clearRegisterDraft = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      isLoading: isLoading ?? this.isLoading,
      isRoleLoaded: isRoleLoaded ?? this.isRoleLoaded,
      role: clearRole ? null : role ?? this.role,
      email: email ?? this.email,
      pendingVerificationEmail: clearPendingVerification
          ? null
          : pendingVerificationEmail ?? this.pendingVerificationEmail,
      pendingPhoneNumber: clearPhone
          ? null
          : pendingPhoneNumber ?? this.pendingPhoneNumber,
      registerDraft: clearRegisterDraft
          ? null
          : registerDraft ?? this.registerDraft,
      errorMessage: errorMessage,
      infoMessage: infoMessage,
    );
  }
}
