import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/core/cache/cache_encryption.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  test('generates and stores a 32-byte key on first run', () async {
    final storage = MockSecureStorage();
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});

    final key = await getOrCreateCacheEncryptionKey(storage);

    expect(key.length, 32);
    verify(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).called(1);
  });

  test('reuses the stored key on later runs (no re-write)', () async {
    final storage = MockSecureStorage();
    final original = List<int>.generate(32, (i) => i);
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => base64Encode(original));

    final key = await getOrCreateCacheEncryptionKey(storage);

    expect(key, original);
    verifyNever(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    );
  });
}
