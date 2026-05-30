import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/verification/data/models/builder_public_verification_model.dart';
import 'package:jobdun/features/verification/domain/entities/verification.dart';

void main() {
  group('BuilderPublicVerificationModel.fromJson', () {
    test('parses an ABN projection row', () {
      final model = BuilderPublicVerificationModel.fromJson({
        'user_id': 'u1',
        'kind': 'abn',
        'verified_legal_name': 'Acme Building Pty Ltd',
        'gst_registered': true,
        'licence_class': null,
        'licence_status': 'current',
        'detail_captured_at': '2026-05-29T03:00:00Z',
      });

      expect(model.userId, 'u1');
      expect(model.kind, VerificationKind.abn);
      expect(model.verifiedLegalName, 'Acme Building Pty Ltd');
      expect(model.gstRegistered, isTrue);
      expect(model.licenceClass, isNull);
      expect(model.licenceStatus, 'current');
      expect(model.detailCapturedAt, DateTime.parse('2026-05-29T03:00:00Z'));
      expect(model.isVerified, isTrue);
    });

    test('parses a licence projection row', () {
      final model = BuilderPublicVerificationModel.fromJson({
        'user_id': 'u2',
        'kind': 'licence',
        'verified_legal_name': null,
        'gst_registered': null,
        'licence_class': 'Carpentry',
        'licence_status': 'expired',
        'detail_captured_at': null,
      });

      expect(model.kind, VerificationKind.licence);
      expect(model.licenceClass, 'Carpentry');
      expect(model.licenceStatus, 'expired');
      expect(model.detailCapturedAt, isNull);
    });
  });
}
