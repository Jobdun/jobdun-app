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
      expect(model.detailCapturedAt, DateTime.parse('2026-05-29T03:00:00Z'));
    });

    test('missing curated fields parse as null', () {
      final model = VerificationModel.fromJson(baseJson());

      expect(model.gstRegistered, isNull);
      expect(model.registerSource, isNull);
      expect(model.detailCapturedAt, isNull);
    });
  });
}
