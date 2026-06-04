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
}
