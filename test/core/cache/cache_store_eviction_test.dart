import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:jobdun/core/cache/hive_cache_store.dart';
import 'package:jobdun/core/cache/in_memory_cache_store.dart';

void main() {
  test('InMemoryCacheStore evicts oldest entries beyond maxEntries', () async {
    final store = InMemoryCacheStore(maxEntries: 3);
    for (var i = 0; i < 5; i++) {
      await store.write('k$i', {'n': i}, schemaVersion: 1);
    }

    // Oldest two evicted, newest three kept (bounded growth).
    expect(await store.read('k0', schemaVersion: 1), isNull);
    expect(await store.read('k1', schemaVersion: 1), isNull);
    expect(await store.read('k2', schemaVersion: 1), isNotNull);
    expect(await store.read('k3', schemaVersion: 1), isNotNull);
    expect(await store.read('k4', schemaVersion: 1), isNotNull);
  });

  test('HiveCacheStore evicts oldest entries beyond maxEntries', () async {
    final dir = await Directory.systemTemp.createTemp('jobdun_evict');
    Hive.init(dir.path);
    final box = await Hive.openBox<String>('evict');
    addTearDown(() async {
      await box.close();
      await dir.delete(recursive: true);
    });

    final store = HiveCacheStore(box, maxEntries: 3);
    for (var i = 0; i < 5; i++) {
      await store.write('k$i', {'n': i}, schemaVersion: 1);
    }

    expect(await store.read('k0', schemaVersion: 1), isNull);
    expect(await store.read('k4', schemaVersion: 1), isNotNull);
    expect(box.length, 3, reason: 'box is bounded to maxEntries');
  });
}
