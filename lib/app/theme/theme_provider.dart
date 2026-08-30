import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeKey = 'theme_mode_v2';

/// Pre-light-first key. Any value under it was chosen against the OLD palette,
/// so it is retired rather than honoured — see [loadSavedTheme].
const _kLegacyThemeKey = 'theme_mode';

/// Reads the persisted theme before the app starts so there is no
/// dark→light flash on first load for users who chose light mode.
///
/// **One-time reset.** Installs predating the light-first switch carry a
/// `theme_mode` value picked when dark was the app's default face. Honouring
/// it means an upgrade opens dark and the user never sees the canonical light
/// design at all. So the legacy key is dropped on first read: every existing
/// install lands on light exactly once, and the new key persists their choice
/// normally from there — dark stays a real, sticky option, not a per-session
/// preview.
Future<ThemeMode> loadSavedTheme() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey(_kLegacyThemeKey)) {
    await prefs.remove(_kLegacyThemeKey);
  }
  final saved = prefs.getString(_kThemeKey);
  if (saved == 'dark') return ThemeMode.dark;
  if (saved == 'light') return ThemeMode.light;
  // Default for new installs: LIGHT. The design system is light-first — the
  // Figma foundation is authored on a light ground and that is the canonical
  // look, so a first run should show it regardless of the OS setting. Dark is
  // a fully-designed peer (not an inversion) and is one tap away in Settings,
  // where the choice persists above.
  //
  // To go back to honouring the OS on first run, return ThemeMode.system here.
  return ThemeMode.light;
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);

class ThemeNotifier extends Notifier<ThemeMode> {
  ThemeNotifier({ThemeMode initial = ThemeMode.light}) : _initial = initial;

  final ThemeMode _initial;

  @override
  ThemeMode build() => _initial;

  Future<void> toggle() async {
    // Flip relative to what's actually rendering now — important when the
    // current mode is `system`, where "is it dark?" depends on the OS setting.
    final next = isDark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kThemeKey,
      next == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  bool get _systemIsDark =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
      Brightness.dark;

  /// Whether the app is *currently rendering* dark — resolves `system` against
  /// the live OS brightness so the Settings toggle reflects what's on screen.
  bool get isDark =>
      state == ThemeMode.dark || (state == ThemeMode.system && _systemIsDark);
}
