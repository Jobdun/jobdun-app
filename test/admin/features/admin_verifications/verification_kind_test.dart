import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/admin/features/admin_verifications/data/verification_kind.dart';

void main() {
  group('docTypeToVerificationKind', () {
    test('maps trade_licence to licence', () {
      expect(docTypeToVerificationKind('trade_licence'), 'licence');
    });

    test('maps abn_certificate to abn', () {
      expect(docTypeToVerificationKind('abn_certificate'), 'abn');
    });

    test('returns null for non-identity doc types', () {
      for (final t in [
        'white_card',
        'photo_id',
        'public_liability',
        'workers_compensation',
        'other',
        '',
      ]) {
        expect(
          docTypeToVerificationKind(t),
          isNull,
          reason: '$t should not map',
        );
      }
    });
  });

  group('canRevokeVerification', () {
    test('true only when a revocable kind is currently verified', () {
      expect(
        canRevokeVerification(
          docType: 'trade_licence',
          lastVerificationStatus: 'verified',
        ),
        isTrue,
      );
      expect(
        canRevokeVerification(
          docType: 'abn_certificate',
          lastVerificationStatus: 'verified',
        ),
        isTrue,
      );
    });

    test('false when the latest row is not verified', () {
      for (final s in [
        'pending',
        'rejected',
        'expired',
        'manual_review',
        null,
      ]) {
        expect(
          canRevokeVerification(
            docType: 'trade_licence',
            lastVerificationStatus: s,
          ),
          isFalse,
          reason: 'status=$s should not be revocable',
        );
      }
    });

    test('false for a non-revocable doc type even when verified', () {
      expect(
        canRevokeVerification(
          docType: 'white_card',
          lastVerificationStatus: 'verified',
        ),
        isFalse,
      );
    });
  });
}
