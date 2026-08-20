/// Password rules shared by sign-up (`register_page_form_step`) and password
/// reset (`reset_password_page`).
///
/// These live in one place on purpose. When the rules were inlined as a
/// file-private validator on the sign-up form, nothing stopped the reset form
/// from drifting to a different standard — and a password the app accepted at
/// sign-up but rejected on reset (or the reverse) reads to the user as a
/// broken app, with no way to tell which screen is wrong.
class PasswordRules {
  const PasswordRules._();

  /// Composable validator block: ≥1 digit, ≥1 uppercase, ≥1 symbol. Surfaces
  /// one rule at a time so the user gets actionable copy instead of a
  /// "must contain X, Y, and Z" wall of text. The ≥8-char check is the
  /// `FormBuilderValidators.minLength` entry one step up the chain, and
  /// emptiness is `FormBuilderValidators.required`'s job — hence the null
  /// pass-through here rather than a second "required" message.
  static String? strong(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Include at least 1 number.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Include at least 1 uppercase letter.';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-=+]').hasMatch(value)) {
      return 'Include at least 1 symbol (! @ # \$ % etc.).';
    }
    return null;
  }

  /// Cross-field check for a "confirm password" input. Empty defers to the
  /// required validator so the user isn't told "doesn't match" before they've
  /// typed anything.
  static String? confirmationError(String? password, String? confirmation) {
    if (confirmation == null || confirmation.isEmpty) return null;
    return confirmation == password ? null : "Passwords don't match.";
  }
}
