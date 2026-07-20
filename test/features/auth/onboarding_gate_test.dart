import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/features/auth/presentation/widgets/onboarding_gate.dart';

void main() {
  group('OnboardingGate.needsCompletion', () {
    test('no loaded profile (still loading OR load failed) never prompts', () {
      // The regression: a failed/offline profile load left profile == null,
      // which the old gate read as "no name" and showed the non-dismissible
      // sheet over a fully-onboarded user. A null profile is never proof.
      expect(
        OnboardingGate.needsCompletion(
          hasProfile: false,
          hasRole: true,
          displayName: 'Ken',
        ),
        isFalse,
      );
      expect(
        OnboardingGate.needsCompletion(
          hasProfile: false,
          hasRole: false,
          displayName: null,
        ),
        isFalse,
      );
    });

    test('loaded profile with role + name does not prompt', () {
      expect(
        OnboardingGate.needsCompletion(
          hasProfile: true,
          hasRole: true,
          displayName: 'Ken',
        ),
        isFalse,
      );
    });

    test('loaded profile missing role prompts', () {
      expect(
        OnboardingGate.needsCompletion(
          hasProfile: true,
          hasRole: false,
          displayName: 'Ken',
        ),
        isTrue,
      );
    });

    test('loaded profile with empty name prompts', () {
      expect(
        OnboardingGate.needsCompletion(
          hasProfile: true,
          hasRole: true,
          displayName: '',
        ),
        isTrue,
      );
    });

    test('whitespace-only name is treated as empty', () {
      expect(
        OnboardingGate.needsCompletion(
          hasProfile: true,
          hasRole: true,
          displayName: '   ',
        ),
        isTrue,
      );
    });

    test('null name on a loaded profile prompts', () {
      expect(
        OnboardingGate.needsCompletion(
          hasProfile: true,
          hasRole: true,
          displayName: null,
        ),
        isTrue,
      );
    });
  });

  group('OnboardingGate.needsCompletion — SSO name providers (G4)', () {
    // App Review Guideline 4: after Sign in with Apple (and Google, whose
    // OIDC token always carries a name) the app must never require the name
    // again — even when nothing was captured, completion is role-only.
    test('apple user with role and no name anywhere does not need completion',
        () {
      expect(
        OnboardingGate.needsCompletion(
          hasProfile: true,
          hasRole: true,
          displayName: null,
          metadataName: null,
          ssoNameProvider: true,
        ),
        isFalse,
      );
    });

    test('apple user without role still needs completion (role step only)',
        () {
      expect(
        OnboardingGate.needsCompletion(
          hasProfile: true,
          hasRole: false,
          displayName: null,
          metadataName: null,
          ssoNameProvider: true,
        ),
        isTrue,
      );
    });

    test('metadata name satisfies the name requirement for email/phone users',
        () {
      expect(
        OnboardingGate.needsCompletion(
          hasProfile: true,
          hasRole: true,
          displayName: null,
          metadataName: 'Kel Tradie',
          ssoNameProvider: false,
        ),
        isFalse,
      );
    });

    test('phone user with role but no name still needs completion', () {
      expect(
        OnboardingGate.needsCompletion(
          hasProfile: true,
          hasRole: true,
          displayName: ' ',
          metadataName: null,
          ssoNameProvider: false,
        ),
        isTrue,
      );
    });
  });
}
