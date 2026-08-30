import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('loadSavedTheme', () {
    test('a fresh install opens light', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await loadSavedTheme(), ThemeMode.light);
    });

    test('a pre-light-first dark choice is retired, not honoured', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      expect(await loadSavedTheme(), ThemeMode.light);
      // …and the legacy key is gone, so the reset happens exactly once.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('theme_mode'), isFalse);
    });

    test('a choice made since the reset still sticks', () async {
      SharedPreferences.setMockInitialValues({'theme_mode_v2': 'dark'});
      expect(await loadSavedTheme(), ThemeMode.dark);
    });

    test('a legacy key never overrides a current choice', () async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'light',
        'theme_mode_v2': 'dark',
      });
      expect(await loadSavedTheme(), ThemeMode.dark);
    });
  });
}
