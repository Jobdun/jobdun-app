import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'messaging_provider.dart';

/// A short-lived signed URL for a private `chat-attachments` object, keyed by
/// storage path. Riverpod caches per-path, so the image bubble doesn't re-sign
/// on every rebuild. Throws (→ AsyncError) if signing fails.
final signedChatUrlProvider = FutureProvider.family<String, String>((
  ref,
  path,
) async {
  final result = await ref
      .read(messageRepositoryProvider)
      .signedAttachmentUrl(path);
  return result.fold((f) => throw Exception(f.message), (url) => url);
});
