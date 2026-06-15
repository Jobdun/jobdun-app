import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns the marketing site's light/dark choice.
///
/// First visit follows the visitor's OS preference ([ThemeMode.system]); a
/// `localStorage`-backed override (via `shared_preferences`) wins once the
/// visitor taps the nav toggle. The saved value is loaded inside [build] with
/// the canonical `Future.microtask` trigger (see CLAUDE.md Riverpod rules), so
/// the first frame paints with `system` and then snaps to the saved override.
///
/// Web-only surface: `shared_preferences` persists to `window.localStorage`,
/// so the choice survives reloads without any backend.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'jobdun.website.themeMode';

  @override
  ThemeMode build() {
    Future.microtask(_load);
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    state = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  /// Flip between light and dark. From [ThemeMode.system] we resolve the
  /// current platform brightness first, then flip to the *opposite* of what
  /// the visitor is seeing — so one tap always visibly changes the page.
  Future<void> toggle(Brightness platformBrightness) async {
    final showingDark = switch (state) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };
    final next = showingDark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next == ThemeMode.dark ? 'dark' : 'light');
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// True when the page is currently rendering dark, resolving [ThemeMode.system]
/// against the platform brightness. Read by the nav toggle to pick its glyph.
bool isShowingDark(ThemeMode mode, Brightness platformBrightness) =>
    switch (mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };
