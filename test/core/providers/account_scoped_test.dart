import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/core/providers/account_scoped.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';

// Minimal controller using the mixin: counts up, resets to 0 on account change.
class _CountNotifier extends Notifier<int> with AccountScoped<int> {
  @override
  int build() {
    resetOnAccountChange((_) => state = 0);
    return 0;
  }

  void inc() => state++;
}

final _countProvider = NotifierProvider<_CountNotifier, int>(_CountNotifier.new);

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test('AccountScoped clears state on account switch and on logout', () async {
    final auth = StreamController<String?>.broadcast();
    final container = ProviderContainer(
      overrides: [currentUserIdProvider.overrideWith((ref) => auth.stream)],
    );
    addTearDown(container.dispose);
    addTearDown(auth.close);

    // Keep an active subscription so the controller stays alive + reactive.
    container.listen(_countProvider, (_, _) {}, fireImmediately: true);

    auth.add('user-a');
    await _settle();
    container.read(_countProvider.notifier).inc();
    container.read(_countProvider.notifier).inc();
    expect(container.read(_countProvider), 2);

    // Switch to user B -> reset (no cache from A).
    auth.add('user-b');
    await _settle();
    expect(container.read(_countProvider), 0);

    // Accumulate again, then log out -> reset.
    container.read(_countProvider.notifier).inc();
    expect(container.read(_countProvider), 1);
    auth.add(null);
    await _settle();
    expect(container.read(_countProvider), 0);
  });
}
