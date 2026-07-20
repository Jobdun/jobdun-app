/// Guest-browsable locations (App Review 5.1.1(v)): the public job browser
/// and single job details. Everything account-based stays login-gated —
/// /jobs itself (the tab shell), create, map, and applicants are excluded.
///
/// Kept separate from the router so the policy is unit-testable and the
/// router file stays inside the size budget.
bool isGuestBrowsableLocation(String location) {
  if (location == '/browse') return true;
  if (location.startsWith('/jobs/')) {
    final rest = location.substring('/jobs/'.length);
    return rest.isNotEmpty &&
        !rest.contains('/') &&
        rest != 'create' &&
        rest != 'map';
  }
  return false;
}
