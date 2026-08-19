import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/verification/data/models/verification_model.dart';

void main() {
  Map<String, dynamic> baseJson() => {
    'id': 'v1',
    'user_id': 'u1',
    'kind': 'abn',
    'status': 'verified',
    'manual_fallback_allowed': false,
    'created_at': '2026-05-30T00:00:00Z',
    'updated_at': '2026-05-30T00:00:00Z',
  };

  group('VerificationModel.fromJson — curated display fields', () {
    test('parses gst_registered, register_source, detail_captured_at', () {
      final json = baseJson()
        ..addAll({
          'gst_registered': true,
          'register_source': 'ABR',
          'detail_captured_at': '2026-05-29T03:00:00Z',
        });

      final model = VerificationModel.fromJson(json);

      expect(model.gstRegistered, isTrue);
      expect(model.registerSource, 'ABR');
      // 2026-08-18 audit: timestamps convert to local at the parse boundary
      // so calendar-date rendering shows the viewer's day, not the UTC day.
      final captured = model.detailCapturedAt!;
      expect(captured.isUtc, isFalse);
      expect(captured, DateTime.parse('2026-05-29T03:00:00Z').toLocal());
    });

    test('missing curated fields parse as null', () {
      final model = VerificationModel.fromJson(baseJson());

      expect(model.gstRegistered, isNull);
      expect(model.registerSource, isNull);
      expect(model.detailCapturedAt, isNull);
    });
  });
}
