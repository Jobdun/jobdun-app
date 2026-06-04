/// Pure decision for the home-page onboarding gate: should the (non-dismissible)
/// [OnboardingCompletionSheet] be shown?
///
/// **Critical invariant:** only ever prompt when we have a *successfully loaded*
/// profile. A null profile means the load is either still in flight OR it
/// **failed** (offline / transient error) — neither is proof the user is
/// incomplete. The previous gate evaluated `displayName` straight off a null
/// profile, so a failed load read as "no name" and trapped fully-onboarded
/// users behind the mandatory sheet (notably on a flaky first load after launch
/// or when offline). The profile `ref.listen` re-runs the gate once the load
/// eventually succeeds, so genuinely-incomplete users still get prompted.
class OnboardingGate {
  const OnboardingGate._();

  static bool needsCompletion({
    required bool hasProfile,
    required bool hasRole,
    required String? displayName,
  }) {
    if (!hasProfile) return false;
    final needsName = (displayName ?? '').trim().isEmpty;
    return !hasRole || needsName;
  }
}
