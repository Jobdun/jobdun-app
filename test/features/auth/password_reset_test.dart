import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:jobdun/core/config/supabase_config.dart';
import 'package:jobdun/features/auth/data/services/email_auth_service.dart';
import 'package:jobdun/features/auth/presentation/validators/password_rules.dart';

class MockSupabaseClient extends Mock implements supabase.SupabaseClient {}

class MockGoTrueClient extends Mock implements supabase.GoTrueClient {}

class MockUserResponse extends Mock implements supabase.UserResponse {}

void main() {
  setUpAll(() {
    registerFallbackValue(supabase.UserAttributes());
  });

  late MockSupabaseClient client;
  late MockGoTrueClient auth;
  late EmailAuthService service;

  setUp(() {
    client = MockSupabaseClient();
    auth = MockGoTrueClient();
    when(() => client.auth).thenReturn(auth);
    service = EmailAuthService(client);
  });

  // ── The actual production bug ───────────────────────────────────────────────
  // resetPasswordForEmail was called with no `redirectTo`, so Supabase fell
  // back to the project's Site URL — a stale marketing host with nothing that
  // handles a recovery token. The link dead-ended and no password was ever
  // reset, on mobile or web. Every sibling call (register, resendVerification)
  // already passed effectiveAuthRedirectUrl; this one silently didn't.
  group('EmailAuthService.sendPasswordReset', () {
    test('sends the reset link back to the app, not the Site URL', () async {
      when(
        () => auth.resetPasswordForEmail(
          any(),
          redirectTo: any(named: 'redirectTo'),
        ),
      ).thenAnswer((_) async {});

      await service.sendPasswordReset('tradie@example.com');

      verify(
        () => auth.resetPasswordForEmail(
          'tradie@example.com',
          redirectTo: SupabaseConfig.effectiveAuthRedirectUrl,
        ),
      ).called(1);
    });

    test('trims the email before sending', () async {
      when(
        () => auth.resetPasswordForEmail(
          any(),
          redirectTo: any(named: 'redirectTo'),
        ),
      ).thenAnswer((_) async {});

      await service.sendPasswordReset('  tradie@example.com  ');

      verify(
        () => auth.resetPasswordForEmail(
          'tradie@example.com',
          redirectTo: any(named: 'redirectTo'),
        ),
      ).called(1);
    });
  });

  // The other half of the bug: nothing in the app ever called updateUser, so
  // even a working link had nowhere to actually set a new password.
  group('EmailAuthService.updatePassword', () {
    test('writes the new password onto the recovery session', () async {
      when(
        () => auth.updateUser(any()),
      ).thenAnswer((_) async => MockUserResponse());

      await service.updatePassword('N3wPassw0rd!');

      final captured =
          verify(() => auth.updateUser(captureAny())).captured.single
              as supabase.UserAttributes;
      expect(captured.password, 'N3wPassw0rd!');
    });
  });

  // Extracted from register_page_form_step so sign-up and reset enforce the
  // *same* rule. Divergence here is a real trap: a password accepted at
  // sign-up that the reset form rejects (or vice versa) reads as a broken app.
  group('PasswordRules.strong', () {
    test('accepts a password meeting every rule', () {
      expect(PasswordRules.strong('N3wPassw0rd!'), isNull);
    });

    test('defers empty to the required validator', () {
      expect(PasswordRules.strong(''), isNull);
      expect(PasswordRules.strong(null), isNull);
    });

    test('requires a digit', () {
      expect(
        PasswordRules.strong('NoDigitsHere!'),
        'Include at least 1 number.',
      );
    });

    test('requires an uppercase letter', () {
      expect(
        PasswordRules.strong('n0uppercase!'),
        'Include at least 1 uppercase letter.',
      );
    });

    test('requires a symbol', () {
      expect(
        PasswordRules.strong('NoSymbol123'),
        contains('Include at least 1 symbol'),
      );
    });
  });

  // Confirm-field logic lives as a pure rule so it is testable without
  // standing up the whole form.
  group('PasswordRules.confirmationError', () {
    test('passes when both fields match', () {
      expect(
        PasswordRules.confirmationError('N3wPassw0rd!', 'N3wPassw0rd!'),
        isNull,
      );
    });

    test('flags a mismatch', () {
      expect(
        PasswordRules.confirmationError('N3wPassw0rd!', 'N3wPassw0rd'),
        "Passwords don't match.",
      );
    });

    test('defers an empty confirmation to the required validator', () {
      expect(PasswordRules.confirmationError('N3wPassw0rd!', ''), isNull);
      expect(PasswordRules.confirmationError('N3wPassw0rd!', null), isNull);
    });
  });
}
