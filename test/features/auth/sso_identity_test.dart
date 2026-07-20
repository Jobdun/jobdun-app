import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/features/auth/data/services/sso_identity.dart';

void main() {
  group('SsoIdentity.hasNameProvider', () {
    test('true when providers list contains apple', () {
      expect(
        SsoIdentity.hasNameProvider({
          'provider': 'apple',
          'providers': ['apple'],
        }),
        isTrue,
      );
    });

    test('true when apple is one of several linked identities', () {
      expect(
        SsoIdentity.hasNameProvider({
          'provider': 'email',
          'providers': ['email', 'apple'],
        }),
        isTrue,
      );
    });

    test('true for google', () {
      expect(
        SsoIdentity.hasNameProvider({
          'provider': 'google',
          'providers': ['google'],
        }),
        isTrue,
      );
    });

    test('false for email-only accounts', () {
      expect(
        SsoIdentity.hasNameProvider({
          'provider': 'email',
          'providers': ['email'],
        }),
        isFalse,
      );
    });

    test('falls back to the singular provider key when providers is absent', () {
      expect(SsoIdentity.hasNameProvider({'provider': 'apple'}), isTrue);
      expect(SsoIdentity.hasNameProvider({'provider': 'phone'}), isFalse);
    });

    test('false on empty metadata', () {
      expect(SsoIdentity.hasNameProvider({}), isFalse);
    });
  });

  group('SsoIdentity.metadataDisplayName', () {
    test('reads full_name first', () {
      expect(
        SsoIdentity.metadataDisplayName({
          'full_name': 'Kel Tradie',
          'name': 'Other',
        }),
        'Kel Tradie',
      );
    });

    test('reads a plain string name', () {
      expect(SsoIdentity.metadataDisplayName({'name': 'Kel Tradie'}),
          'Kel Tradie');
    });

    test('composes given_name + family_name', () {
      expect(
        SsoIdentity.metadataDisplayName({
          'given_name': 'Kel',
          'family_name': 'Tradie',
        }),
        'Kel Tradie',
      );
    });

    test('reads the Apple nested name object', () {
      expect(
        SsoIdentity.metadataDisplayName({
          'name': {'firstName': 'Kel', 'lastName': 'Tradie'},
        }),
        'Kel Tradie',
      );
    });

    test('nested object with only firstName', () {
      expect(
        SsoIdentity.metadataDisplayName({
          'name': {'firstName': 'Kel'},
        }),
        'Kel',
      );
    });

    test('whitespace-only values are null', () {
      expect(
        SsoIdentity.metadataDisplayName({'full_name': '   ', 'name': ''}),
        isNull,
      );
    });

    test('null metadata is null', () {
      expect(SsoIdentity.metadataDisplayName(null), isNull);
    });
  });
}
