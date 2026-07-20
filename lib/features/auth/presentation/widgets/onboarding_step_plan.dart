enum OnboardingStep { role, name, avatar }

/// Which steps [OnboardingCompletionSheet] shows, decided up front so the
/// sheet renders only what's genuinely missing. Pure so it unit-tests.
///
/// The name step only appears when we truly have no name AND the auth
/// provider doesn't supply one — Apple/Google users are never re-asked
/// (App Review Guideline 4 / Sign in with Apple HIG). Avatar is always
/// offered last and is skippable.
class OnboardingStepPlan {
  const OnboardingStepPlan._();

  static List<OnboardingStep> compute({
    required bool hasRole,
    required String? effectiveName,
    required bool ssoNameProvider,
  }) {
    final needsName = (effectiveName ?? '').trim().isEmpty && !ssoNameProvider;
    return [
      if (!hasRole) OnboardingStep.role,
      if (needsName) OnboardingStep.name,
      OnboardingStep.avatar,
    ];
  }
}
