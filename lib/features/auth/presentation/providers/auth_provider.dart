import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/config/supabase_config.dart';

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

    return AuthState(
      isAuthenticated: true,
      onboardingComplete: true,
      email: user?.email ?? session?.user.email,
    );
  }

  Future<bool> signIn({
    required String email,
    required String password,
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
    );

    try {
      final response = await SupabaseConfig.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      state = state.copyWith(
        isAuthenticated: response.user != null || response.session != null,
        onboardingComplete: false,
        email: response.user?.email ?? email.trim(),
        isLoading: false,
        clearRole: true,
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
      final response = await SupabaseConfig.client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim()},
      );

      if (response.session == null) {
        state = state.copyWith(
          isAuthenticated: false,
          onboardingComplete: false,
          email: response.user?.email ?? email.trim(),
          isLoading: false,
          infoMessage:
              'Account created. Confirm your email, then sign in to continue.',
          errorMessage: null,
          clearRole: true,
        );
        return false;
      }

      state = state.copyWith(
        isAuthenticated: true,
        onboardingComplete: false,
        email: response.user?.email ?? email.trim(),
        isLoading: false,
        errorMessage: null,
        infoMessage: 'Account created successfully.',
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

  void completeOnboarding(UserRole role) {
    state = state.copyWith(role: role, onboardingComplete: true);
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
    this.errorMessage,
    this.infoMessage,
  });

  final bool isAuthenticated;
  final bool onboardingComplete;
  final bool isLoading;
  final UserRole? role;
  final String? email;
  final String? errorMessage;
  final String? infoMessage;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? onboardingComplete,
    bool? isLoading,
    UserRole? role,
    String? email,
    String? errorMessage,
    String? infoMessage,
    bool clearRole = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      isLoading: isLoading ?? this.isLoading,
      role: clearRole ? null : role ?? this.role,
      email: email ?? this.email,
      errorMessage: errorMessage,
      infoMessage: infoMessage,
    );
  }
}

enum UserRole { builder, trade, admin }

extension UserRoleX on UserRole {
  String get label => switch (this) {
    UserRole.builder => 'Builder',
    UserRole.trade => 'Trade / Crew',
    UserRole.admin => 'Admin',
  };

  String get description => switch (this) {
    UserRole.builder =>
      'Post work, review applicants, and manage project progress.',
    UserRole.trade =>
      'Find work, apply quickly, and maintain verification documents.',
    UserRole.admin =>
      'Review verifications, moderate activity, and monitor the platform.',
  };
}
