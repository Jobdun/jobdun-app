import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/data/models/trade_profile_model.dart';
import 'package:jobdun/features/profile/domain/entities/apprenticeship_stage.dart';

Map<String, dynamic> _base() => {
  'id': 'u1',
  'full_name': 'Jake M',
  'primary_trade': 'carpenter',
};

void main() {
  group('TradeProfileModel apprentice fields', () {
    test('defaults are non-apprentice, no tickets, no resume', () {
      final tp = TradeProfileModel.fromJson(_base());
      expect(tp.isApprentice, isFalse);
      expect(tp.apprenticeshipStage, isNull);
      expect(tp.siteTickets, isEmpty);
      expect(tp.resumePath, isNull);
      expect(tp.hasResume, isFalse);
      expect(tp.ticketCount, 0);
      expect(tp.resumeFileName, isNull);
    });

    test('parses a full apprentice row', () {
      final tp = TradeProfileModel.fromJson({
        ..._base(),
        'is_apprentice': true,
        'apprenticeship_stage': 'year_2',
        'site_tickets': ['white_card', 'first_aid'],
        'resume_path': 'u1/resume/1756600000.pdf',
        'resume_uploaded_at': '2026-08-31T02:00:00.000Z',
      });
      expect(tp.isApprentice, isTrue);
      expect(tp.apprenticeshipStage, ApprenticeshipStage.year2);
      expect(tp.siteTickets, ['white_card', 'first_aid']);
      expect(tp.ticketCount, 2);
      expect(tp.hasResume, isTrue);
      expect(tp.resumeFileName, '1756600000.pdf');
    });

    test('an invalid stage degrades to null rather than throwing', () {
      final tp = TradeProfileModel.fromJson({
        ..._base(),
        'is_apprentice': true,
        'apprenticeship_stage': 'year_9',
      });
      expect(tp.apprenticeshipStage, isNull);
    });

    test('apprenticeHeadline reads off the trade slug', () {
      final tp = TradeProfileModel.fromJson({
        ..._base(),
        'is_apprentice': true,
        'apprenticeship_stage': 'year_2',
      });
      expect(tp.apprenticeHeadline, '2ND-YEAR CARPENTER APPRENTICE');
    });

    test('apprenticeHeadline uses the free-text trade when slug is other', () {
      final tp = TradeProfileModel.fromJson({
        ..._base(),
        'primary_trade': 'other',
        'trade_other': 'Scaffolder',
        'is_apprentice': true,
        'apprenticeship_stage': 'year_1',
      });
      expect(tp.apprenticeHeadline, '1ST-YEAR SCAFFOLDER APPRENTICE');
    });

    test('apprenticeHeadline is null without apprentice mode or a stage', () {
      expect(TradeProfileModel.fromJson(_base()).apprenticeHeadline, isNull);
      expect(
        TradeProfileModel.fromJson({
          ..._base(),
          'is_apprentice': true,
        }).apprenticeHeadline,
        isNull,
        reason: 'apprentice with no stage picked yet has no chip text',
      );
    });

    test('toCacheMap round-trips every apprentice field', () {
      final tp = TradeProfileModel.fromJson({
        ..._base(),
        'is_apprentice': true,
        'apprenticeship_stage': 'year_3',
        'site_tickets': ['dogging'],
        'resume_path': 'u1/resume/9.pdf',
        'resume_uploaded_at': '2026-08-31T02:00:00.000Z',
      });
      final back = TradeProfileModel.fromJson(tp.toCacheMap());
      expect(back.isApprentice, isTrue);
      expect(back.apprenticeshipStage, ApprenticeshipStage.year3);
      expect(back.siteTickets, ['dogging']);
      expect(back.resumePath, 'u1/resume/9.pdf');
      expect(back.resumeUploadedAt, isNotNull);
    });

    test('toJson stays a write projection with no apprentice keys', () {
      // Apprentice fields are written through TradeProfilePatch only. If they
      // leaked into toJson, the legacy full-row save would null-wipe them.
      final json = TradeProfileModel.fromJson({
        ..._base(),
        'is_apprentice': true,
        'site_tickets': ['white_card'],
      }).toJson();
      expect(json.containsKey('is_apprentice'), isFalse);
      expect(json.containsKey('site_tickets'), isFalse);
      expect(json.containsKey('resume_path'), isFalse);
    });

    test('props include the new fields so select() sees a change', () {
      final a = TradeProfileModel.fromJson(_base());
      final b = TradeProfileModel.fromJson({
        ..._base(),
        'site_tickets': ['first_aid'],
      });
      expect(a == b, isFalse);
    });
  });
}
