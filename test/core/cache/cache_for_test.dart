import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/core/cache/cache_for.dart';

// Real (short) timer delays, matching the house convention in
// test/core/providers/account_scoped_test.dart — no fake_async.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  // Control: proves the harness genuinely exercises autoDispose. WITHOUT
  // cacheFor, an unlistened provider is thrown away and re-fetches on return —
  // exactly the behaviour Phase 1 caching is meant to soften.
  test(
    'baseline: autoDispose provider rebuilds after its listener is removed',
    () async {
      var builds = 0;
      final provider = FutureProvider.autoDispose<int>((ref) async => ++builds);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sub = container.listen(provider, (_, _) {});
      await container.read(provider.future);
      expect(builds, 1);

      sub.close();
      await _settle(); // unlistened → disposed

      container.listen(provider, (_, _) {});
      await container.read(provider.future);
      expect(builds, 2, reason: 'no cache → re-fetched on return');
    },
  );

  test('cacheFor keeps an autoDispose provider alive within the ttl', () async {
    var builds = 0;
    final provider = FutureProvider.autoDispose<int>((ref) async {
      cacheFor(ref, const Duration(seconds: 5));
      return ++builds;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final sub = container.listen(provider, (_, _) {});
    await container.read(provider.future);
    expect(builds, 1);

    sub.close();
    await _settle(); // would dispose, but cacheFor holds it alive

    container.listen(provider, (_, _) {});
    await container.read(provider.future);
    expect(builds, 1, reason: 'within ttl → cached result reused, no re-fetch');
  });

  test('cacheFor releases the provider after the ttl elapses', () async {
    var builds = 0;
    final provider = FutureProvider.autoDispose<int>((ref) async {
      cacheFor(ref, const Duration(milliseconds: 40));
      return ++builds;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final sub = container.listen(provider, (_, _) {});
    await container.read(provider.future);
    expect(builds, 1);

    sub.close();
    await Future<void>.delayed(const Duration(milliseconds: 90)); // past ttl

    container.listen(provider, (_, _) {});
    await container.read(provider.future);
    expect(builds, 2, reason: 'ttl expired → provider disposed → re-fetched');
  });
}
