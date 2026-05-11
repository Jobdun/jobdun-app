import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeKey = 'theme_mode';

/// Reads the persisted theme before the app starts so there is no
/// dark→light flash on first load for users who chose light mode.
Future<ThemeMode> loadSavedTheme() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kThemeKey) == 'light' ? ThemeMode.light : ThemeMode.dark;
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

class ThemeNotifier extends Notifier<ThemeMode> {
  ThemeNotifier({ThemeMode initial = ThemeMode.dark}) : _initial = initial;

  final ThemeMode _initial;

  @override
  ThemeMode build() => _initial;

  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeKey, state == ThemeMode.dark ? 'dark' : 'light');
  }

  bool get isDark => state == ThemeMode.dark;
}
