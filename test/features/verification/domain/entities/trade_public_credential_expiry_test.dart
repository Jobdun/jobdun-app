import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/features/verification/domain/entities/trade_public_credential.dart';
import 'package:jobdun/features/verification/domain/entities/verification_document.dart';

// U5.1: expiresSoonAt boundaries — the 30-day renewal window.
void main() {
  final now = DateTime(2026, 6, 10);

  TradePublicCredential cred({DateTime? expiresAt, bool isExpired = false}) =>
      TradePublicCredential(
        userId: 't1',
        docType: DocType.whiteCard,
        expiresAt: expiresAt,
        isExpired: isExpired,
      );

  test('29 days out is soon', () {
    expect(cred(expiresAt: DateTime(2026, 7, 9)).expiresSoonAt(now), isTrue);
  });

  test('exactly 30 days out is soon (inclusive boundary)', () {
    expect(cred(expiresAt: DateTime(2026, 7, 10)).expiresSoonAt(now), isTrue);
  });

  test('31 days out is not soon', () {
    expect(cred(expiresAt: DateTime(2026, 7, 11)).expiresSoonAt(now), isFalse);
  });

  test('no expiry date is never soon', () {
    expect(cred().expiresSoonAt(now), isFalse);
  });

  test('an already-expired credential is not "soon" — it is expired', () {
    expect(
      cred(expiresAt: DateTime(2026, 6, 1), isExpired: true).expiresSoonAt(now),
      isFalse,
    );
  });

  test('a past date without the server flag still does not count as soon', () {
    expect(cred(expiresAt: DateTime(2026, 6, 9)).expiresSoonAt(now), isFalse);
  });
}
