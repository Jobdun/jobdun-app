/// How far through an apprenticeship someone is.
///
/// [dbValue] is pinned to the CHECK constraint in
/// `20260831000001_apprentice_columns.sql`. Adding a value here without adding
/// it there writes a row Postgres rejects, so `apprenticeship_stage_test.dart`
/// asserts the exact list — keep both in lockstep.
enum ApprenticeshipStage { preApprentice, year1, year2, year3, year4 }

extension ApprenticeshipStageX on ApprenticeshipStage {
  String get dbValue => switch (this) {
    ApprenticeshipStage.preApprentice => 'pre_apprentice',
    ApprenticeshipStage.year1 => 'year_1',
    ApprenticeshipStage.year2 => 'year_2',
    ApprenticeshipStage.year3 => 'year_3',
    ApprenticeshipStage.year4 => 'year_4',
  };

  String get label => switch (this) {
    ApprenticeshipStage.preApprentice => 'Pre-apprentice',
    ApprenticeshipStage.year1 => '1st year',
    ApprenticeshipStage.year2 => '2nd year',
    ApprenticeshipStage.year3 => '3rd year',
    ApprenticeshipStage.year4 => '4th year',
  };

  /// Profile chip text: "2ND-YEAR CARPENTRY APPRENTICE".
  ///
  /// Pre-apprentice carries no year, so it reads "PRE-APPRENTICE CARPENTRY" —
  /// calling someone a "0th-year apprentice" would be wrong, and in AU a
  /// pre-apprentice has not signed an indenture yet.
  String headline(String trade) {
    final t = trade.trim().toUpperCase();
    return switch (this) {
      ApprenticeshipStage.preApprentice => 'PRE-APPRENTICE $t',
      ApprenticeshipStage.year1 => '1ST-YEAR $t APPRENTICE',
      ApprenticeshipStage.year2 => '2ND-YEAR $t APPRENTICE',
      ApprenticeshipStage.year3 => '3RD-YEAR $t APPRENTICE',
      ApprenticeshipStage.year4 => '4TH-YEAR $t APPRENTICE',
    };
  }

  /// Tolerant parse: an unrecognised value degrades to null rather than
  /// throwing, so a row written by a newer build can never crash an older one.
  static ApprenticeshipStage? fromDb(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final s in ApprenticeshipStage.values) {
      if (s.dbValue == value) return s;
    }
    return null;
  }
}
