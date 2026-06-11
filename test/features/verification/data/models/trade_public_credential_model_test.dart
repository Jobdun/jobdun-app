import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/verification/data/models/trade_public_credential_model.dart';
import 'package:jobdun/features/verification/domain/entities/verification_document.dart';

void main() {
  group('TradePublicCredentialModel.fromJson', () {
    test('parses a current White Card projection row', () {
      final model = TradePublicCredentialModel.fromJson({
        'user_id': 'u1',
        'doc_type': 'white_card',
        'expires_at': '2030-01-01',
        'credential_status': 'current',
        'captured_at': '2026-06-09T03:00:00Z',
      });

      expect(model.userId, 'u1');
      expect(model.docType, DocType.whiteCard);
      expect(model.expiresAt, DateTime.parse('2030-01-01'));
      expect(model.isExpired, isFalse);
      expect(model.capturedAt, DateTime.parse('2026-06-09T03:00:00Z'));
    });

    test('parses an expired public-liability projection row', () {
      final model = TradePublicCredentialModel.fromJson({
        'user_id': 'u2',
        'doc_type': 'public_liability',
        'expires_at': '2025-01-01',
        'credential_status': 'expired',
        'captured_at': null,
      });

      expect(model.docType, DocType.publicLiability);
      expect(model.isExpired, isTrue);
      expect(model.capturedAt, isNull);
    });

    test('tolerates a null expiry (treated as not-expired)', () {
      final model = TradePublicCredentialModel.fromJson({
        'user_id': 'u3',
        'doc_type': 'white_card',
        'expires_at': null,
        'credential_status': 'current',
        'captured_at': null,
      });

      expect(model.expiresAt, isNull);
      expect(model.isExpired, isFalse);
    });
  });
}
