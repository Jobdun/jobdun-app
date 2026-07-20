import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/features/auth/presentation/widgets/onboarding_step_plan.dart';

void main() {
  group('OnboardingStepPlan.compute', () {
    test('apple user with no role and no name gets role + avatar only', () {
      // G4: Sign in with Apple must never lead to a required name screen.
      expect(
        OnboardingStepPlan.compute(
          hasRole: false,
          effectiveName: null,
          ssoNameProvider: true,
        ),
        [OnboardingStep.role, OnboardingStep.avatar],
      );
    });

    test('phone user with no role and no name gets all three steps', () {
      expect(
        OnboardingStepPlan.compute(
          hasRole: false,
          effectiveName: null,
          ssoNameProvider: false,
        ),
        [OnboardingStep.role, OnboardingStep.name, OnboardingStep.avatar],
      );
    });

    test('email user with role but no name gets name + avatar', () {
      expect(
        OnboardingStepPlan.compute(
          hasRole: true,
          effectiveName: '  ',
          ssoNameProvider: false,
        ),
        [OnboardingStep.name, OnboardingStep.avatar],
      );
    });

    test('user with role and name gets avatar only', () {
      expect(
        OnboardingStepPlan.compute(
          hasRole: true,
          effectiveName: 'Kel Tradie',
          ssoNameProvider: false,
        ),
        [OnboardingStep.avatar],
      );
    });

    test('sso user with a captured name and no role gets role + avatar', () {
      expect(
        OnboardingStepPlan.compute(
          hasRole: false,
          effectiveName: 'Kel Tradie',
          ssoNameProvider: true,
        ),
        [OnboardingStep.role, OnboardingStep.avatar],
      );
    });
  });
}
