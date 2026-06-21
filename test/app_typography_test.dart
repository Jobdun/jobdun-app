import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_typography.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String appTypographySource() =>
      File('lib/app/theme/app_typography.dart').readAsStringSync();

  String appThemeSource() =>
      File('lib/app/theme/app_theme.dart').readAsStringSync();

  String applicationsCardSource() => File(
    'lib/features/applications/presentation/pages/applications_page_card.dart',
  ).readAsStringSync();

  String applicantDetailWidgetsSource() => File(
    'lib/features/applications/presentation/pages/applicant_detail_widgets.dart',
  ).readAsStringSync();

  String appTypographyBlock() {
    final source = appTypographySource();
    return source.substring(
      source.indexOf('abstract final class AppTypography'),
      source.indexOf('/// Admin-console type scale.'),
    );
  }

  group('AppTypography', () {
    test('uses Archivo for display, headings, titleLarge, and buttons', () {
      final source = appTypographyBlock();

      expect(source, contains('GoogleFonts.archivo'));
      expect(source, isNot(contains('GoogleFonts.oswald')));
    });

    test('uses Inter for body, dense titles, and small UI labels', () {
      final source = appTypographyBlock();

      expect(source, contains('GoogleFonts.inter'));
      expect(source, isNot(contains('GoogleFonts.openSans')));
    });

    test('keeps tabular figures available for money, counts, and ratings', () {
      final numeric = AppTypography.numeric(
        const TextStyle(fontFeatures: <FontFeature>[]),
      );

      expect(
        numeric.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });

  group('AppTheme typography surfaces', () {
    test('uses Archivo for brand and PIN entry surfaces', () {
      final source = appThemeSource();

      expect(source, contains('static TextStyle brandDisplay'));
      expect(source, contains('GoogleFonts.archivo'));
      expect(source, isNot(contains('GoogleFonts.oswald')));
    });

    test('uses Inter for Material input labels, hints, and errors', () {
      final source = appThemeSource();

      expect(source, contains('labelStyle: GoogleFonts.inter'));
      expect(source, contains('floatingLabelStyle: GoogleFonts.inter'));
      expect(source, contains('hintStyle: GoogleFonts.inter'));
      expect(source, contains('errorStyle: GoogleFonts.inter'));
      expect(source, isNot(contains('GoogleFonts.openSans')));
    });
  });

  group('Applications typography', () {
    test('uses tabular figures for pricing and stats', () {
      expect(applicationsCardSource(), contains('AppTypography.numeric'));
      expect(applicantDetailWidgetsSource(), contains('AppTypography.numeric'));
    });
  });
}
