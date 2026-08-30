import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/features/profile/data/models/profile_patch_mappers.dart';
import 'package:jobdun/features/profile/domain/entities/apprenticeship_stage.dart';
import 'package:jobdun/features/profile/domain/entities/profile_patches.dart';

void main() {
  group('TradeProfilePatch apprentice columns', () {
    test('an untouched patch writes no apprentice columns', () {
      final cols = tradeProfilePatchColumns(const TradeProfilePatch());
      for (final k in [
        'is_apprentice',
        'apprenticeship_stage',
        'site_tickets',
        'resume_path',
        'resume_uploaded_at',
      ]) {
        expect(cols.containsKey(k), isFalse, reason: k);
      }
    });

    test('turning apprentice mode on writes the flag and the db stage', () {
      final cols = tradeProfilePatchColumns(
        const TradeProfilePatch(
          isApprentice: Some(true),
          apprenticeshipStage: Some(ApprenticeshipStage.year2),
        ),
      );
      expect(cols['is_apprentice'], true);
      expect(cols['apprenticeship_stage'], 'year_2');
    });

    test('Some(null) stage clears the column instead of skipping it', () {
      final cols = tradeProfilePatchColumns(
        const TradeProfilePatch(
          isApprentice: Some(false),
          apprenticeshipStage: Some(null),
        ),
      );
      expect(cols['is_apprentice'], false);
      expect(cols.containsKey('apprenticeship_stage'), isTrue);
      expect(cols['apprenticeship_stage'], isNull);
    });

    test('tickets write as a list, and an empty list still writes', () {
      final set = tradeProfilePatchColumns(
        const TradeProfilePatch(siteTickets: Some(['white_card', 'dogging'])),
      );
      expect(set['site_tickets'], ['white_card', 'dogging']);

      final cleared = tradeProfilePatchColumns(
        const TradeProfilePatch(siteTickets: Some([])),
      );
      expect(cleared.containsKey('site_tickets'), isTrue);
      expect(cleared['site_tickets'], isEmpty);
    });

    test('resume path and timestamp write together and clear together', () {
      final set = tradeProfilePatchColumns(
        TradeProfilePatch(
          resumePath: const Some('u1/resume/9.pdf'),
          resumeUploadedAt: Some(DateTime.utc(2026, 8, 31, 2)),
        ),
      );
      expect(set['resume_path'], 'u1/resume/9.pdf');
      expect(set['resume_uploaded_at'], '2026-08-31T02:00:00.000Z');

      final cleared = tradeProfilePatchColumns(
        const TradeProfilePatch(
          resumePath: Some(null),
          resumeUploadedAt: Some(null),
        ),
      );
      expect(cleared.containsKey('resume_path'), isTrue);
      expect(cleared['resume_path'], isNull);
      expect(cleared['resume_uploaded_at'], isNull);
    });

    test('setting an apprentice field alone still writes nothing else', () {
      // The null-wipe guard: a tickets save must not touch rates or location.
      final cols = tradeProfilePatchColumns(
        const TradeProfilePatch(siteTickets: Some(['first_aid'])),
      );
      expect(cols.keys, ['site_tickets']);
    });

    test('isEmpty is false as soon as any apprentice field is set', () {
      expect(const TradeProfilePatch().isEmpty, isTrue);
      expect(
        const TradeProfilePatch(isApprentice: Some(true)).isEmpty,
        isFalse,
      );
      expect(const TradeProfilePatch(siteTickets: Some([])).isEmpty, isFalse);
      expect(const TradeProfilePatch(resumePath: Some(null)).isEmpty, isFalse);
      expect(
        const TradeProfilePatch(apprenticeshipStage: Some(null)).isEmpty,
        isFalse,
      );
    });
  });
}
