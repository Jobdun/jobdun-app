import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/config/supabase_config.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/sentry_reporter.dart';
import '../../data/services/email_auth_service.dart';
import '../../data/services/oauth_service.dart';
import '../../data/services/phone_auth_service.dart';
import '../../data/services/role_resolver.dart';
import '../../domain/entities/user_role.dart';
import 'auth_state.dart';

export '../../domain/entities/user_role.dart';
export 'auth_state.dart';

part 'auth_provider_phone.dart';

// ── Service providers (public so tests can override) ──────────────────────────
final emailAuthServiceProvider = Provider<EmailAuthService>(
  (ref) => EmailAuthService(SupabaseConfig.client),
);

final oauthServiceProvider = Provider<OAuthService>(
  (ref) => OAuthService(SupabaseConfig.client),
);

final phoneAuthServiceProvider = Provider<PhoneAuthService>(
  (ref) => PhoneAuthService(SupabaseConfig.client),
);

final roleResolverProvider = Provider<RoleResolver>(
  (ref) => RoleResolver(SupabaseConfig.client),
);

// ── Controller ────────────────────────────────────────────────────────────────
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Owns [AuthState]. Delegates all Supabase access to the four service
/// classes in `data/services/`. Keeping the orchestration here means
/// every state transition lives in one file — easier to reason about role
/// hydration, error mapping, and the "pending verification" gate without
/// chasing through SDK calls.
class AuthController extends Notifier<AuthState> with _AuthControllerPhone {
  late EmailAuthService _email;
  late OAuthService _oauth;
  @override
  late PhoneAuthService _phone;
  late RoleResolver _roles;
  StreamSubscription<supabase.AuthState>? _authSubscription;

  @override
  AuthState build() {
    if (!SupabaseConfig.isInitialized) {
      return const AuthState();
    }
    _email = ref.read(emailAuthServiceProvider);
    _oauth = ref.read(oauthServiceProvider);
    _phone = ref.read(phoneAuthServiceProvider);
    _roles = ref.read(roleResolverProvider);

    final client = SupabaseConfig.client;
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
      // Load role from JWT/DB after every session change — without this,
      // home would race-fire OnboardingCompletionSheet for users who already picked.
      _loadRoleForCurrentUser();
    });
    ref.onDispose(() => _authSubscription?.cancel());

    final session = client.auth.currentSession;
    final user = client.auth.currentUser;
    if (session == null && user == null) {
      return const AuthState();
    }
    // Session exists → user got past sign-in at some point. Hydrate role in
    // the background so home personalises correctly on cold start.
    Future.microtask(_loadRoleForCurrentUser);
    return AuthState(
      isAuthenticated: true,
      email: user?.email ?? session?.user.email,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _mapAuthError(Object e) => e is supabase.AuthException
      ? ErrorMessages.from(AuthFailure(e.message))
      : ErrorMessages.from(ServerFailure(e.toString()));

  @override
  void _startLoading() {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      infoMessage: null,
    );
  }

  @override
  void _failLoading(Object e, {StackTrace? stackTrace, String? action}) {
    state = state.copyWith(
      isLoading: false,
      errorMessage: _mapAuthError(e),
      infoMessage: null,
    );
    // Every auth catch block funnels through here, so reporting once means
    // every login / register / OAuth / OTP failure reaches Sentry without
    // touching individual call sites. AuthException is mapped to plain
    // English upstream — Sentry sees the original message + the action tag
    // (e.g. action: signIn) so it's filterable in the dashboard.
    final tags = <String, String>{'feature': 'auth'};
    if (action != null) tags['action'] = action;
    unawaited(
      SentryReporter.reportError(e, stackTrace: stackTrace, tags: tags),
    );
  }

  @override
  bool _ensureConfigured() {
    if (SupabaseConfig.isInitialized) return true;
    state = state.copyWith(
      isLoading: false,
      errorMessage:
          'Supabase is not configured. Fill .env and run with '
          '--dart-define-from-file=.env.',
      infoMessage: null,
    );
    return false;
  }

  @override
  Future<void> _loadRoleForCurrentUser() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) {
      state = state.copyWith(isRoleLoaded: true);
      return;
    }
    try {
      final role = await _roles.resolveRole(userId);
      state = state.copyWith(role: role, isRoleLoaded: true);
    } catch (e, st) {
      assert(() {
        debugPrint('[AuthController] _loadRoleForCurrentUser: $e\n$st');
        return true;
      }());
      // Mark loaded even on failure so the sheet doesn't hang forever.
      state = state.copyWith(isRoleLoaded: true);
    }
  }

  // ── Email / password ───────────────────────────────────────────────────────

  Future<bool> signIn({required String email, required String password}) async {
    if (!_ensureConfigured()) return false;
    _startLoading();
    try {
      final response = await _email.signIn(email: email, password: password);
      await _loadRoleForCurrentUser();
      state = state.copyWith(
        isAuthenticated: response.user != null || response.session != null,
        email: response.user?.email ?? email.trim(),
        isLoading: false,
      );
      return state.isAuthenticated;
    } catch (e) {
      _failLoading(e);
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
    if (!_ensureConfigured()) return false;
    // Stash the form values so "Wrong email? Change it" on /verify-email
    // can route back to /register step 2 with everything pre-filled.
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      infoMessage: null,
      registerDraft: RegisterDraft(
        fullName: fullName.trim(),
        email: email.trim(),
        role: role,
      ),
    );
    try {
      final response = await _email.register(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        phone: phone,
      );
      if (response.session == null) {
        // Email confirmation required → show verify-email screen.
        state = state.copyWith(
          isLoading: false,
          pendingVerificationEmail: response.user?.email ?? email.trim(),
        );
        return false;
      }
      // Email confirmation disabled → signed in immediately.
      state = state.copyWith(
        isAuthenticated: true,
        email: response.user?.email ?? email.trim(),
        isLoading: false,
        clearRole: true,
      );
      return true;
    } catch (e) {
      _failLoading(e);
      return false;
    }
  }

  Future<void> resendVerificationEmail() async {
    final email = state.pendingVerificationEmail;
    if (email == null || !_ensureConfigured()) return;
    _startLoading();
    try {
      await _email.resendVerification(email);
      state = state.copyWith(
        isLoading: false,
        infoMessage: 'Verification email resent. Check your inbox.',
      );
    } catch (e) {
      _failLoading(e);
    }
  }

  // Manual "I've verified — continue" check from /verify-email. Tries to pull
  // a fresh session token and confirms email status. Returns true if confirmed.
  Future<bool> checkEmailVerified() async {
    if (!_ensureConfigured()) return false;
    _startLoading();
    try {
      final verified = await _email.isEmailVerified();
      if (verified) {
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

  Future<void> sendPasswordReset(String email) async {
    if (!_ensureConfigured()) return;
    _startLoading();
    try {
      await _email.sendPasswordReset(email);
      state = state.copyWith(
        isLoading: false,
        infoMessage: 'Check your email for a reset link.',
      );
    } catch (e) {
      _failLoading(e);
    }
  }

  // ── OAuth ──────────────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    if (!_ensureConfigured()) return;
    _startLoading();
    try {
      final response = await _oauth.signInWithGoogle();
      await _loadRoleForCurrentUser();
      state = state.copyWith(
        isAuthenticated: response.user != null,
        email: response.user?.email,
        isLoading: false,
      );
    } on GoogleSignInException catch (e) {
      // User cancelled → silently drop the spinner, no error toast.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        state = state.copyWith(isLoading: false);
        return;
      }
      _failLoading(e);
    } catch (e) {
      _failLoading(e);
    }
  }

  Future<void> signInWithApple() async {
    if (!_ensureConfigured()) return;
    _startLoading();
    try {
      final response = await _oauth.signInWithApple();
      await _loadRoleForCurrentUser();
      state = state.copyWith(
        isAuthenticated: response.user != null,
        email: response.user?.email,
        isLoading: false,
      );
    } catch (e) {
      _failLoading(e);
    }
  }

  // ── Verification / draft resets ──────────────────────────────────────────

  void clearPendingVerification() {
    state = state.copyWith(clearPendingVerification: true);
  }

  void clearRegisterDraft() {
    state = state.copyWith(clearRegisterDraft: true);
  }

  // Phone / OTP flows live in `_AuthControllerPhone` (auth_provider_phone.dart),
  // mixed in above to keep this file under the size budget.

  // ── Role hydration & assignment ────────────────────────────────────────────

  // Last-chance role hydration before HomePage shows the role-selection sheet.
  // Returns true if a user_roles row exists; false if there's genuinely no
  // role yet. The JWT-claim path can lag behind reality when the
  // custom_access_token hook isn't wired in the Supabase Dashboard, or when
  // the session was refreshed but the new token hasn't propagated yet.
  Future<bool> hydrateRoleFromDb() async {
    if (!SupabaseConfig.isInitialized) return false;
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return false;
    final role = await _roles.roleFromDb(userId);
    if (role == null) return false;
    if (state.role != role) {
      state = state.copyWith(role: role, isRoleLoaded: true);
    }
    return true;
  }

  Future<bool> setRoleAndStubProfile(UserRole role) async {
    if (!_ensureConfigured()) return false;
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return false;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final effective = await _roles.setRoleAndStubProfile(
        userId: userId,
        requestedRole: role,
      );
      state = state.copyWith(role: effective, isLoading: false);
      return true;
    } catch (e, st) {
      assert(() {
        debugPrint('[AuthController] setRoleAndStubProfile: $e\n$st');
        return true;
      }());
      _failLoading(e);
      return false;
    }
  }

  /// Single atomic-from-the-user-view commit of the post-auth onboarding
  /// state — role + display_name. Used by [OnboardingCompletionSheet] for
  /// SSO and phone signups that arrive on /home with partial state.
  ///
  /// Avatar upload (if any) is a separate concern handled by
  /// ProfileController.uploadAvatar in the sheet — keeps the controller
  /// boundaries clean (auth owns identity, profile owns appearance).
  Future<bool> completeOnboarding({
    required UserRole role,
    required String displayName,
  }) async {
    if (!_ensureConfigured()) return false;
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return false;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final effective = await _roles.setRoleAndStubProfile(
        userId: userId,
        requestedRole: role,
        displayName: displayName,
      );
      state = state.copyWith(
        role: effective,
        isRoleLoaded: true,
        isLoading: false,
      );
      return true;
    } catch (e, st) {
      assert(() {
        debugPrint('[AuthController] completeOnboarding: $e\n$st');
        return true;
      }());
      _failLoading(e);
      return false;
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    if (SupabaseConfig.isInitialized) {
      await _email.signOut();
    }
    state = const AuthState();
  }
}
