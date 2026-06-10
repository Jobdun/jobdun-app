import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/features/verification/domain/entities/verification_document.dart';
import 'package:jobdun/features/verification/presentation/widgets/manual_doc_kind.dart';

// Pure-logic matrix for the manual-upload credential kinds. Drives the
// trade trust-layer: licence + white card + public liability are all
// uploadable; each kind declares which fields the sheet must capture.
void main() {
  group('ManualDocKind.docType maps each kind to its DocType', () {
    test('abnCertificate → DocType.abnCertificate', () {
      expect(ManualDocKind.abnCertificate.docType, DocType.abnCertificate);
    });
    test('tradeLicence → DocType.tradeLicence', () {
      expect(ManualDocKind.tradeLicence.docType, DocType.tradeLicence);
    });
    test('whiteCard → DocType.whiteCard', () {
      expect(ManualDocKind.whiteCard.docType, DocType.whiteCard);
    });
    test('publicLiability → DocType.publicLiability', () {
      expect(ManualDocKind.publicLiability.docType, DocType.publicLiability);
    });
  });

  group('requiresState — only credentials issued per-state', () {
    test('trade licence requires a state', () {
      expect(ManualDocKind.tradeLicence.requiresState, isTrue);
    });
    test('white card requires a state (issued per-jurisdiction)', () {
      expect(ManualDocKind.whiteCard.requiresState, isTrue);
    });
    test('ABN is national — no state', () {
      expect(ManualDocKind.abnCertificate.requiresState, isFalse);
    });
    test('public liability is insurer-issued — no state', () {
      expect(ManualDocKind.publicLiability.requiresState, isFalse);
    });
  });

  group('requiresExpiry — credentials that lapse', () {
    test('trade licence expires', () {
      expect(ManualDocKind.tradeLicence.requiresExpiry, isTrue);
    });
    test('white card expires', () {
      expect(ManualDocKind.whiteCard.requiresExpiry, isTrue);
    });
    test('public liability policy expires', () {
      expect(ManualDocKind.publicLiability.requiresExpiry, isTrue);
    });
    test('ABN does not expire', () {
      expect(ManualDocKind.abnCertificate.requiresExpiry, isFalse);
    });
  });

  group(
    'requiresTradeClass — only a trade licence files under a trade class',
    () {
      test('trade licence requires a trade class', () {
        expect(ManualDocKind.tradeLicence.requiresTradeClass, isTrue);
      });
      test('white card has a state but NO trade class', () {
        expect(ManualDocKind.whiteCard.requiresState, isTrue);
        expect(ManualDocKind.whiteCard.requiresTradeClass, isFalse);
      });
      test('ABN has no trade class', () {
        expect(ManualDocKind.abnCertificate.requiresTradeClass, isFalse);
      });
      test('public liability has no trade class', () {
        expect(ManualDocKind.publicLiability.requiresTradeClass, isFalse);
      });
    },
  );

  group(
    'requiresIssuer — only public liability captures a free-text insurer',
    () {
      test('public liability requires an issuer name', () {
        expect(ManualDocKind.publicLiability.requiresIssuer, isTrue);
      });
      test(
        'trade licence derives its issuer from the state (no free-text)',
        () {
          expect(ManualDocKind.tradeLicence.requiresIssuer, isFalse);
        },
      );
      test('white card derives its issuer from the state (no free-text)', () {
        expect(ManualDocKind.whiteCard.requiresIssuer, isFalse);
      });
      test('ABN issuer is fixed (the ABR)', () {
        expect(ManualDocKind.abnCertificate.requiresIssuer, isFalse);
      });
    },
  );

  test('every kind has distinct, non-empty sheet titles + number labels', () {
    final titles = ManualDocKind.values.map((k) => k.sheetTitle).toSet();
    final labels = ManualDocKind.values.map((k) => k.numberLabel).toSet();
    expect(titles.length, ManualDocKind.values.length);
    expect(labels.length, ManualDocKind.values.length);
    for (final k in ManualDocKind.values) {
      expect(k.sheetTitle.trim(), isNotEmpty);
      expect(k.numberLabel.trim(), isNotEmpty);
      expect(k.numberHint.trim(), isNotEmpty);
    }
  });
}
