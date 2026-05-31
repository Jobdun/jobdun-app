import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeKey = 'theme_mode';

/// Reads the persisted theme before the app starts so there is no
/// dark→light flash on first load for users who chose light mode.
Future<ThemeMode> loadSavedTheme() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_kThemeKey);
  if (saved == 'dark') return ThemeMode.dark;
  if (saved == 'light') return ThemeMode.light;
  // Default for new installs: follow the OS setting. The brand is dark-first,
  // so dark-mode devices land on the intended #0F172A look; users can still
  // pin an explicit light/dark choice in Settings (which persists above).
  return ThemeMode.system;
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);

class ThemeNotifier extends Notifier<ThemeMode> {
  ThemeNotifier({ThemeMode initial = ThemeMode.system}) : _initial = initial;

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
