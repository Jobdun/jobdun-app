import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/core/utils/validators.dart';

void main() {
  group('Validators.abn', () {
    test('null and empty pass (field is optional)', () {
      expect(Validators.abn(null), isNull);
      expect(Validators.abn(''), isNull);
      expect(Validators.abn('   '), isNull);
    });

    test('non-11-digit rejects with length message', () {
      expect(Validators.abn('123'), 'ABN must be 11 digits.');
      expect(Validators.abn('123456789012'), 'ABN must be 11 digits.');
      expect(Validators.abn('abcdefghijk'), 'ABN must be 11 digits.');
      expect(Validators.abn('12 345'), 'ABN must be 11 digits.');
    });

    test('whitespace is tolerated', () {
      expect(Validators.abn('11 004 089 936'), isNull);
      expect(Validators.abn('  11004089936  '), isNull);
    });

    test('real ABNs pass the checksum', () {
      // Public companies — checksum verified by hand against ABR mod-89 rule.
      expect(Validators.abn('11004089936'), isNull, reason: 'Coles');
      expect(Validators.abn('88000014675'), isNull, reason: 'Woolworths');
      expect(Validators.abn('49004028077'), isNull, reason: 'BHP');
      expect(Validators.abn('33051775556'), isNull, reason: 'Telstra');
      expect(Validators.abn('48123123124'), isNull, reason: 'CBA');
    });

    test('11-digit non-ABN numbers fail the checksum', () {
      // These are 11 digits but not real ABNs — must be rejected by the
      // checksum, not by length.
      expect(
        Validators.abn('60004089936'),
        "That ABN doesn't look right — check the digits.",
        reason: 'Coles ABN with first digit wrong',
      );
      expect(
        Validators.abn('12345678901'),
        "That ABN doesn't look right — check the digits.",
      );
      expect(
        Validators.abn('99999999999'),
        "That ABN doesn't look right — check the digits.",
      );
      expect(
        Validators.abn('11111111111'),
        "That ABN doesn't look right — check the digits.",
      );
    });
  });
}
