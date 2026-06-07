import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:jobdun/core/cache/cache_store.dart';
import 'package:jobdun/core/cache/hive_cache_store.dart';
import 'package:jobdun/core/cache/in_memory_cache_store.dart';

// One contract, run against every CacheStore implementation so the disk store
// and the in-memory default can never drift apart.
void cacheStoreContract(String name, Future<CacheStore> Function() create) {
  group(name, () {
    late CacheStore store;
    setUp(() async => store = await create());

    test('write then read returns the payload and timestamp', () async {
      final at = DateTime(2026, 6, 1, 9);
      await store.write(
        'k',
        {
          'a': 1,
          'b': [1, 2, 3],
        },
        schemaVersion: 1,
        at: at,
      );

      final rec = await store.read('k', schemaVersion: 1);
      expect(rec, isNotNull);
      expect(rec!.payload, {
        'a': 1,
        'b': [1, 2, 3],
      });
      expect(rec.fetchedAt, at);
    });

    test('read of a missing key returns null', () async {
      expect(await store.read('nope', schemaVersion: 1), isNull);
    });

    test('schema-version mismatch purges the entry and returns null', () async {
      await store.write('k', {'a': 1}, schemaVersion: 1);
      expect(await store.read('k', schemaVersion: 2), isNull);
      // Purged: the original version is gone too.
      expect(await store.read('k', schemaVersion: 1), isNull);
    });

    test('evict removes a single entry', () async {
      await store.write('k', {'a': 1}, schemaVersion: 1);
      await store.evict('k');
      expect(await store.read('k', schemaVersion: 1), isNull);
    });

    test('clear removes everything', () async {
      await store.write('a', {'x': 1}, schemaVersion: 1);
      await store.write('b', {'y': 2}, schemaVersion: 1);
      await store.clear();
      expect(await store.read('a', schemaVersion: 1), isNull);
      expect(await store.read('b', schemaVersion: 1), isNull);
    });
  });
}

void main() {
  cacheStoreContract('InMemoryCacheStore', () async => InMemoryCacheStore());

  cacheStoreContract('HiveCacheStore', () async {
    final dir = await Directory.systemTemp.createTemp('jobdun_cache_test');
    Hive.init(dir.path);
    final box = await Hive.openBox<String>(
      'cache_${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(() async {
      await box.close();
      await dir.delete(recursive: true);
    });
    return HiveCacheStore(box);
  });

  test('HiveCacheStore: a corrupt entry reads as null (fail-safe)', () async {
    final dir = await Directory.systemTemp.createTemp('jobdun_cache_corrupt');
    Hive.init(dir.path);
    final box = await Hive.openBox<String>('corrupt');
    addTearDown(() async {
      await box.close();
      await dir.delete(recursive: true);
    });

    await box.put('bad', 'not-json-at-all {{{');
    final store = HiveCacheStore(box);

    expect(await store.read('bad', schemaVersion: 1), isNull);
    expect(box.get('bad'), isNull, reason: 'corrupt entry is purged');
  });
}
