import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/domain/entities/apprenticeship_stage.dart';

void main() {
  group('ApprenticeshipStage', () {
    test('every value round-trips through dbValue', () {
      for (final s in ApprenticeshipStage.values) {
        expect(ApprenticeshipStageX.fromDb(s.dbValue), s);
      }
    });

    test('unknown / null db values resolve to null', () {
      expect(ApprenticeshipStageX.fromDb(null), isNull);
      expect(ApprenticeshipStageX.fromDb('year_9'), isNull);
      expect(ApprenticeshipStageX.fromDb(''), isNull);
    });

    test('db values match the CHECK constraint exactly', () {
      // Pinned to trade_profiles_apprenticeship_stage_valid in
      // 20260831000001_apprentice_columns.sql. Drift here writes rows Postgres
      // rejects at runtime.
      expect(ApprenticeshipStage.values.map((s) => s.dbValue).toList(), [
        'pre_apprentice',
        'year_1',
        'year_2',
        'year_3',
        'year_4',
      ]);
    });

    test('labels are human-readable and non-empty', () {
      expect(ApprenticeshipStage.preApprentice.label, 'Pre-apprentice');
      expect(ApprenticeshipStage.year2.label, '2nd year');
      for (final s in ApprenticeshipStage.values) {
        expect(s.label, isNotEmpty);
      }
    });

    test('headline renders the profile chip text', () {
      expect(
        ApprenticeshipStage.year2.headline('Carpentry'),
        '2ND-YEAR CARPENTRY APPRENTICE',
      );
      expect(
        ApprenticeshipStage.year1.headline('Plumbing'),
        '1ST-YEAR PLUMBING APPRENTICE',
      );
      expect(
        ApprenticeshipStage.year3.headline('Tiling'),
        '3RD-YEAR TILING APPRENTICE',
      );
      expect(
        ApprenticeshipStage.year4.headline('Welding'),
        '4TH-YEAR WELDING APPRENTICE',
      );
    });

    test('pre-apprentice has no year ordinal', () {
      expect(
        ApprenticeshipStage.preApprentice.headline('Electrical'),
        'PRE-APPRENTICE ELECTRICAL',
      );
    });

    test('headline trims and upper-cases whatever trade it is handed', () {
      expect(
        ApprenticeshipStage.year1.headline('  floor tiler  '),
        '1ST-YEAR FLOOR TILER APPRENTICE',
      );
    });
  });
}
