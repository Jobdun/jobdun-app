import 'dart:math';

/// Generates an RFC-4122 version-4 UUID using a cryptographically secure RNG.
///
/// The app has no `uuid` package dependency — messaging only needs a valid
/// `uuid`-typed value for `messages.client_tag` (optimistic-send idempotency
/// key), so a tiny self-contained generator avoids the extra dependency.
String uuidV4() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

  // Set the version (4) and variant (10xx) bits per RFC 4122 §4.4.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
  return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
      '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
      '${hex.sublist(10, 16).join()}';
}
