part of 'auth_provider.dart';

/// Phone / OTP sub-domain of [AuthController], split into a `part` to keep
/// `auth_provider.dart` under the file-size budget. It stays part of the single
/// [AuthController] (mixed in via `with`) so the public surface — every
/// `authControllerProvider.notifier.signInWithPhone(...)` call site — and the
/// shared [AuthState] are unchanged. The `_`-prefixed members declared abstract
/// below are the controller's own services/helpers; because this is a `part`
/// of the same library, they unify with [AuthController]'s private declarations.
mixin _AuthControllerPhone on Notifier<AuthState> {
  PhoneAuthService get _phone;
  bool _ensureConfigured();
  void _startLoading();
  void _failLoading(Object e);
  Future<void> _loadRoleForCurrentUser();

  Future<bool> signInWithPhone(String phone) async {
    if (!_ensureConfigured()) return false;
    _startLoading();
    try {
      await _phone.sendOtp(phone);
      state = state.copyWith(
        isLoading: false,
        pendingPhoneNumber: phone.trim(),
        infoMessage: 'Code sent — check your SMS.',
      );
      return true;
    } catch (e) {
      _failLoading(e);
      return false;
    }
  }

  Future<bool> verifyPhoneOtp(String token) async {
    final phone = state.pendingPhoneNumber;
    if (phone == null || !_ensureConfigured()) return false;
    _startLoading();
    try {
      final response = await _phone.verifyOtp(phone: phone, token: token);
      await _loadRoleForCurrentUser();
      state = state.copyWith(
        isAuthenticated: response.user != null,
        email: response.user?.email,
        isLoading: false,
        clearPhone: true,
      );
      return state.isAuthenticated;
    } catch (e) {
      _failLoading(e);
      return false;
    }
  }

  Future<bool> sendPhoneVerification(String phone) async {
    if (!_ensureConfigured()) return false;
    _startLoading();
    try {
      await _phone.sendPhoneVerification(phone);
      state = state.copyWith(
        isLoading: false,
        pendingPhoneNumber: phone.trim(),
        infoMessage: 'Code sent — check your SMS.',
      );
      return true;
    } catch (e) {
      _failLoading(e);
      return false;
    }
  }

  Future<bool> confirmPhoneVerification(String token) async {
    final phone = state.pendingPhoneNumber;
    if (phone == null || !_ensureConfigured()) return false;
    _startLoading();
    try {
      await _phone.confirmPhoneVerification(phone: phone, token: token);
      state = state.copyWith(
        isLoading: false,
        clearPhone: true,
        infoMessage: 'Phone verified.',
      );
      return true;
    } catch (e) {
      _failLoading(e);
      return false;
    }
  }

  Future<void> resendPhoneOtp() async {
    final phone = state.pendingPhoneNumber;
    if (phone == null || !_ensureConfigured()) return;
    _startLoading();
    try {
      await _phone.resendOtp(phone);
      state = state.copyWith(isLoading: false, infoMessage: 'New code sent.');
    } catch (e) {
      _failLoading(e);
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
}
