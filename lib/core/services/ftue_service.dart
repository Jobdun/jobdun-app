import 'package:shared_preferences/shared_preferences.dart';

// First-time user experience gate. The carousel sits between splash and login
// and only renders once per device — set by every exit path (CTA tap, SKIP,
// login link) and also as a safety net the first time an upgraded user
// authenticates (so they never see the FTUE retroactively).
//
// Note on the second key: `has_seen_splash_animation` is reserved for the
// Lottie splash work in the next sprint. Plumbing it now so the next PR is
// router-only — do not read it yet.
class FtueService {
  FtueService._();

  static const _kFtueCompleteKey = 'ftue.has_completed';
  static const _kSplashSeenKey = 'ftue.has_seen_splash_animation';
  // First-home welcome toast. Per-device (not per-process) so we don't
  // re-toast the user every cold start. Fires once after email verification.
  static const _kFirstHomeToastSeenKey = 'ftue.has_seen_first_home_toast';

  static Future<bool> hasCompletedFtue() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kFtueCompleteKey) ?? false;
  }

  static Future<void> markFtueComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFtueCompleteKey, true);
  }

  // Dev-only: surfaced from a debug menu so QA can re-test the carousel
  // without reinstalling the app. Clears every onboarding flag including
  // the first-home toast.
  static Future<void> resetFtue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFtueCompleteKey);
    await prefs.remove(_kSplashSeenKey);
    await prefs.remove(_kFirstHomeToastSeenKey);
  }

  static Future<bool> hasSeenFirstHomeToast() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kFirstHomeToastSeenKey) ?? false;
  }

  static Future<void> markFirstHomeToastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFirstHomeToastSeenKey, true);
  }

  // Reserved — splash Lottie ships next sprint. Kept here so the contract is
  // discoverable but not yet read by any caller.
  static Future<bool> hasSeenSplashAnimation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSplashSeenKey) ?? false;
  }

  static Future<void> markSplashAnimationSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSplashSeenKey, true);
  }
}
