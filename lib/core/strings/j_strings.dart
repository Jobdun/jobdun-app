// Canonical user-facing string constants. Single source of truth so a copy
// change doesn't drift across screens. AppButton uppercases its label, so
// these are stored in sentence case ("Log in") and render in caps ("LOG IN")
// at the button — never store "LOG IN" directly here.
//
// Design-system P1 will expand this into a proper localisation pipeline.
// For now this is a stub holding the vocab the friction-reduction sprint
// (T1 + T2) locked in. Add constants as they're needed — don't pre-populate.
abstract final class JStrings {
  // ── Auth — primary actions ────────────────────────────────────────────────
  static const logIn = 'Log in';
  static const createAccount = 'Create account';
  static const continueLabel = 'Continue';

  // ── Auth — alternative entry points ───────────────────────────────────────
  static const useEmail = 'Use email';
  static const usePhone = 'Use phone number';
  static const continueWithGoogle = 'Continue with Google';
  static const continueWithApple = 'Continue with Apple';

  // ── Auth — recovery + verification ────────────────────────────────────────
  static const forgotPassword = 'Forgot password?';
  static const iveVerified = "I've verified — continue";
  static const wrongEmail = 'Wrong email?';
  static const changeIt = 'Change it';
  static const resendVerificationEmail = 'Resend verification email';

  // ── Auth — legal ──────────────────────────────────────────────────────────
  // Used by LegalAcceptanceCheckbox + LegalLinkText. AU law: consent must be
  // explicit (not pre-checked), so the checkbox copy includes "Required".
  static const termsOfService = 'Terms of Service';
  static const privacyPolicy = 'Privacy Policy';
  static const agreeToLegalRequired =
      'I agree to the Terms of Service and Privacy Policy. Required.';
  static const agreeToLegalFooter =
      'By continuing, you agree to our Terms of Service and Privacy Policy.';

  // ── Role identity ─────────────────────────────────────────────────────────
  static const roleBuilderLabel = 'Builder';
  static const roleBuilderDescription = 'Post jobs, hire crews';
  static const roleTradeLabel = 'Trades';
  static const roleTradeDescription = 'Find work, get paid';
}
