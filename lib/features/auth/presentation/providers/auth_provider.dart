import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/config/env.dart';
import '../../../../core/config/supabase_config.dart';
import '../../domain/entities/user_role.dart';

export '../../domain/entities/user_role.dart';

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

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
      // Only update auth flag — role / onboarding status loaded separately.
      state = state.copyWith(
        isAuthenticated: true,
        email: session.user.email,
        isLoading: false,
        errorMessage: null,
        infoMessage: null,
      );
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

  Future<void> _loadProfileForCurrentUser() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await SupabaseConfig.client
          .from('profiles')
          .select('role, is_onboarding_complete')
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return;

      final roleStr = data['role'] as String?;
      final onboardingDone = data['is_onboarding_complete'] as bool? ?? true;
      UserRole? role;
      if (roleStr != null) {
        role = UserRole.values.firstWhere(
          (r) => r.name == roleStr,
          orElse: () => UserRole.trade,
        );
      }
      state = state.copyWith(role: role, onboardingComplete: onboardingDone);
    } catch (_) {
      // Best-effort — don't disrupt the session if profile fetch fails.
    }
  }

  // Returns true if the authenticated user has completed onboarding in the DB.
  Future<bool> _fetchOnboardingStatus(String? userId) async {
    if (userId == null || !SupabaseConfig.isInitialized) return false;
    try {
      final data = await SupabaseConfig.client
          .from('profiles')
          .select('is_onboarding_complete, role')
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return false;

      final roleStr = data['role'] as String?;
      if (roleStr != null) {
        final role = UserRole.values.firstWhere(
          (r) => r.name == roleStr,
          orElse: () => UserRole.trade,
        );
        state = state.copyWith(role: role);
      }
      return data['is_onboarding_complete'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Auth methods ───────────────────────────────────────────────────────────

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    if (!SupabaseConfig.isInitialized) {
      state = state.copyWith(
        errorMessage: 'Supabase is not configured. Fill .env and run with '
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

      final onboardingDone =
          await _fetchOnboardingStatus(response.user?.id);

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
        errorMessage: error.message,
        infoMessage: null,
      );
      return false;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
        infoMessage: null,
      );
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (!SupabaseConfig.isInitialized) {
      state = state.copyWith(
        errorMessage: 'Supabase is not configured. Fill .env and run with '
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
      final response = await SupabaseConfig.client.auth.signUp(
        email: email.trim(),
        password: password,
        // Use 'full_name' — matches the DB trigger and UserModel.fromJson key.
        data: {'full_name': fullName.trim()},
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
        errorMessage: error.message,
        infoMessage: null,
      );
      return false;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
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

  static bool _googleInitialized = false;

  Future<void> signInWithGoogle() async {
    if (!AppEnv.isGoogleConfigured) {
      state = state.copyWith(
        errorMessage: 'Google Sign-In is not configured yet. '
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

      final onboardingDone =
          await _fetchOnboardingStatus(response.user?.id);

      state = state.copyWith(
        isAuthenticated: response.user != null,
        onboardingComplete: onboardingDone,
        email: response.user?.email,
        isLoading: false,
        clearRole: !onboardingDone,
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
      state =
          state.copyWith(isLoading: false, errorMessage: e.message, infoMessage: null);
    } catch (e) {
      state =
          state.copyWith(isLoading: false, errorMessage: e.toString(), infoMessage: null);
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

      final onboardingDone =
          await _fetchOnboardingStatus(response.user?.id);

      state = state.copyWith(
        isAuthenticated: response.user != null,
        onboardingComplete: onboardingDone,
        email: response.user?.email,
        isLoading: false,
        clearRole: !onboardingDone,
      );
    } on supabase.AuthException catch (e) {
      state =
          state.copyWith(isLoading: false, errorMessage: e.message, infoMessage: null);
    } catch (e) {
      state =
          state.copyWith(isLoading: false, errorMessage: e.toString(), infoMessage: null);
    }
  }

  String _generateNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
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
          // Always write role + completion flag so re-login knows onboarding is done.
          final profileUpdate = <String, dynamic>{
            'id': userId,
            'role': role.name,
            'is_onboarding_complete': true,
          };
          if (location != null) profileUpdate['location'] = location;
          await SupabaseConfig.client.from('profiles').upsert(profileUpdate);

          if (role == UserRole.builder) {
            final builderData = <String, dynamic>{'profile_id': userId};
            if (companyName != null) builderData['company_name'] = companyName;
            if (businessType != null) builderData['business_type'] = businessType;
            if (builderData.length > 1) {
              await SupabaseConfig.client
                  .from('builder_profiles')
                  .upsert(builderData);
            }
          } else if (role == UserRole.trade) {
            final tradeData = <String, dynamic>{'profile_id': userId};
            if (tradeCategory != null) tradeData['trade_category'] = tradeCategory;
            if (yearsExperience != null) {
              tradeData['years_experience'] = yearsExperience;
            }
            if (tradeData.length > 1) {
              await SupabaseConfig.client
                  .from('trade_profiles')
                  .upsert(tradeData);
            }
          }
        }
      }
    } catch (_) {
      // Best-effort — don't block the user from progressing.
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
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> signOut() async {
    if (SupabaseConfig.isInitialized) {
      await SupabaseConfig.client.auth.signOut();
    }
    state = const AuthState();
  }
}

class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.onboardingComplete = false,
    this.isLoading = false,
    this.role,
    this.email,
    this.pendingVerificationEmail,
    this.errorMessage,
    this.infoMessage,
  });

  final bool isAuthenticated;
  final bool onboardingComplete;
  final bool isLoading;
  final UserRole? role;
  final String? email;
  final String? pendingVerificationEmail;
  final String? errorMessage;
  final String? infoMessage;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? onboardingComplete,
    bool? isLoading,
    UserRole? role,
    String? email,
    String? pendingVerificationEmail,
    String? errorMessage,
    String? infoMessage,
    bool clearRole = false,
    bool clearPendingVerification = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      isLoading: isLoading ?? this.isLoading,
      role: clearRole ? null : role ?? this.role,
      email: email ?? this.email,
      pendingVerificationEmail: clearPendingVerification
          ? null
          : pendingVerificationEmail ?? this.pendingVerificationEmail,
      errorMessage: errorMessage,
      infoMessage: infoMessage,
    );
  }
}
