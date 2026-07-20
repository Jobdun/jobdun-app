import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/core/providers/pending_return_provider.dart';

void main() {
  group('pendingReturnProvider', () {
    test('starts null, set() stores, consume() returns once then clears', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(pendingReturnProvider), isNull);

      container.read(pendingReturnProvider.notifier).set('/jobs/j1');
      expect(container.read(pendingReturnProvider), '/jobs/j1');

      final notifier = container.read(pendingReturnProvider.notifier);
      expect(notifier.consume(), '/jobs/j1');
      expect(container.read(pendingReturnProvider), isNull);
      expect(notifier.consume(), isNull);
    });

    test('clear() drops a stored location', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(pendingReturnProvider.notifier)
        ..set('/jobs/j1')
        ..clear();
      expect(container.read(pendingReturnProvider), isNull);
    });
  });
}
