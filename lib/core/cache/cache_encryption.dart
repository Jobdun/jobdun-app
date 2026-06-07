import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive_ce.dart';

const _cacheKeyStorageName = 'jobdun_cache_aes_key';

/// Returns the persistent 32-byte AES key for the encrypted Hive cache (Phase
/// 2.5, docs/CACHING_ARCHITECTURE.md §3.3).
///
/// Generates and stores one in platform secure storage (Keychain / Keystore) on
/// first run, then reuses it on every later launch so the box stays
/// decryptable. The key never lives in the app bundle or the cache itself.
Future<List<int>> getOrCreateCacheEncryptionKey(
  FlutterSecureStorage storage,
) async {
  final existing = await storage.read(key: _cacheKeyStorageName);
  if (existing != null) return base64Decode(existing);

  final key = Hive.generateSecureKey();
  await storage.write(key: _cacheKeyStorageName, value: base64Encode(key));
  return key;
}
