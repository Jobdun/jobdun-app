import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/core/validators/phone_validator.dart';

// 2026-08-18 audit: Australians typing their mobile the normal way
// ('0412 345 678') were rejected because the validator never stripped the
// trunk '0', and toE164 would have produced '+610412…'.
void main() {
  final au = countryByCode('AU')!;
  final us = countryByCode('US')!;

  group('trunk-zero handling', () {
    test('AU number with leading 0 validates and formats correctly', () {
      expect(au.validate('0412 345 678'), isNull);
      expect(au.toE164('0412 345 678'), '+61412345678');
    });

    test('AU number without leading 0 still works', () {
      expect(au.validate('412 345 678'), isNull);
      expect(au.toE164('412345678'), '+61412345678');
    });

    test('only one leading zero is stripped', () {
      expect(au.validate('00412345678'), isNotNull);
    });

    test('invalid AU numbers still rejected', () {
      expect(au.validate('312 345 678'), isNotNull);
      expect(au.validate('41234567'), isNotNull);
    });

    test('NANP numbers never lose a leading digit', () {
      expect(us.toE164('(555) 123-4567'), '+15551234567');
    });
  });
}
