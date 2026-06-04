import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/core/network/connectivity_provider.dart';

void main() {
  group('isOnlineFromResults', () {
    test('empty list is offline', () {
      expect(isOnlineFromResults(const []), isFalse);
    });

    test('only "none" is offline', () {
      expect(isOnlineFromResults(const [ConnectivityResult.none]), isFalse);
    });

    test('wifi is online', () {
      expect(isOnlineFromResults(const [ConnectivityResult.wifi]), isTrue);
    });

    test('mobile is online', () {
      expect(isOnlineFromResults(const [ConnectivityResult.mobile]), isTrue);
    });

    test('any non-none interface counts as online', () {
      expect(
        isOnlineFromResults(const [
          ConnectivityResult.none,
          ConnectivityResult.wifi,
        ]),
        isTrue,
      );
    });
  });
}
