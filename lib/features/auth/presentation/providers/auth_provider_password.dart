part of 'auth_provider.dart';

/// Password-reset sub-domain of [AuthController], split into a `part` to keep
/// `auth_provider.dart` under the file-size budget. Same arrangement as
/// [_AuthControllerPhone]: it stays part of the single [AuthController] (mixed
/// in via `with`) so call sites and the shared [AuthState] are unchanged. The
/// `_`-prefixed members declared abstract below are the controller's own
/// services/helpers; because this is a `part` of the same library they unify
/// with [AuthController]'s private declarations.
///
/// The three methods here are the full lifecycle of a reset:
/// request → (email link, handled by gotrue) → set new password / cancel.
mixin _AuthControllerPassword on Notifier<AuthState> {
  EmailAuthService get _email;
  bool _ensureConfigured();
  void _startLoading();
  void _failLoading(Object e, {String? action});

  /// Step 1 — send the email. The link's destination is set by
  /// [EmailAuthService.sendPasswordReset]; see that method for why it matters.
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
      _failLoading(e, action: 'sendPasswordReset');
    }
  }

  /// Step 2 — the user is back in the app on a recovery session and has typed
  /// a new password. Clearing `isPasswordRecovery` is what releases the
  /// router's gate; the session stays valid, so they land straight on /home
  /// already signed in rather than being bounced back to /login to re-enter
  /// the password they just set.
  Future<bool> updatePassword(String newPassword) async {
    if (!_ensureConfigured()) return false;
    _startLoading();
    try {
      await _email.updatePassword(newPassword);
      state = state.copyWith(
        isLoading: false,
        isPasswordRecovery: false,
        infoMessage: 'Password updated. You are signed in.',
      );
      return true;
    } catch (e) {
      _failLoading(e, action: 'updatePassword');
      return false;
    }
  }

  /// Escape hatch — without it the recovery gate is a trap. A user who opens
  /// the link but changes their mind would otherwise be pinned to
  /// /reset-password with no way out, because the recovery session keeps them
  /// "authenticated". Signing out drops the session and the flag together.
  Future<void> cancelPasswordRecovery() async {
    state = state.copyWith(isPasswordRecovery: false);
    try {
      await _email.signOut();
    } catch (e) {
      _failLoading(e, action: 'cancelPasswordRecovery');
    }
  }
}
