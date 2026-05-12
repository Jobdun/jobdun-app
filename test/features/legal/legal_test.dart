import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/legal/domain/legal_document.dart';

void main() {
  group('LegalDocumentType', () {
    test('dbKey values are correct', () {
      expect(LegalDocumentType.termsOfService.dbKey, 'terms_of_service');
      expect(LegalDocumentType.privacyPolicy.dbKey, 'privacy_policy');
    });

    test('assetPath values are correct', () {
      expect(
        LegalDocumentType.termsOfService.assetPath,
        'assets/legal/terms_of_service.md',
      );
      expect(
        LegalDocumentType.privacyPolicy.assetPath,
        'assets/legal/privacy_policy.md',
      );
    });

    test('displayTitle is human-readable', () {
      expect(LegalDocumentType.termsOfService.displayTitle, 'Terms of Service');
      expect(LegalDocumentType.privacyPolicy.displayTitle, 'Privacy Policy');
    });
  });

  group('LegalDocument equality', () {
    test('same type/version/content are equal', () {
      const a = LegalDocument(
        type: LegalDocumentType.termsOfService,
        version: '1.0.0',
        content: 'content',
      );
      const b = LegalDocument(
        type: LegalDocumentType.termsOfService,
        version: '1.0.0',
        content: 'content',
      );
      expect(a, b);
    });

    test('different version means not equal', () {
      const a = LegalDocument(
        type: LegalDocumentType.termsOfService,
        version: '1.0.0',
        content: 'content',
      );
      const b = LegalDocument(
        type: LegalDocumentType.termsOfService,
        version: '2.0.0',
        content: 'content',
      );
      expect(a, isNot(b));
    });
  });

  group('Version bump detection logic', () {
    // Mirrors the logic in pendingReacceptanceProvider.
    List<LegalDocumentType> pendingReacceptance({
      required Map<String, String> current,
      required Map<String, String> accepted,
    }) {
      final pending = <LegalDocumentType>[];
      for (final type in LegalDocumentType.values) {
        final cv = current[type.dbKey] ?? '1.0.0';
        final av = accepted[type.dbKey];
        if (av == null || av != cv) pending.add(type);
      }
      return pending;
    }

    test('returns all types when user has never accepted', () {
      final pending = pendingReacceptance(
        current: {'terms_of_service': '1.0.0', 'privacy_policy': '1.0.0'},
        accepted: {},
      );
      expect(pending, containsAll(LegalDocumentType.values));
    });

    test('returns empty when versions match', () {
      final pending = pendingReacceptance(
        current: {'terms_of_service': '1.0.0', 'privacy_policy': '1.0.0'},
        accepted: {'terms_of_service': '1.0.0', 'privacy_policy': '1.0.0'},
      );
      expect(pending, isEmpty);
    });

    test('returns only bumped doc when one version changes', () {
      final pending = pendingReacceptance(
        current: {'terms_of_service': '2.0.0', 'privacy_policy': '1.0.0'},
        accepted: {'terms_of_service': '1.0.0', 'privacy_policy': '1.0.0'},
      );
      expect(pending, [LegalDocumentType.termsOfService]);
    });
  });
}
