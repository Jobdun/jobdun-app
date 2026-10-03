part of 'messaging_provider.dart';

extension _ImageRetryConfirmation on MessagingController {
  /// An ignored duplicate insert does not emit a fresh realtime event. Fetch
  /// the authoritative row so a recovered retry cannot spin forever.
  Future<void> _confirmRetriedImage(
    PendingMessage pending,
    int generation,
  ) async {
    Message? confirmed;
    try {
      final result = await _repo
          .getMessageByClientTag(pending.conversationId, pending.clientTag)
          .timeout(_sendTimeout);
      confirmed = result.getOrElse((_) => null);
    } on TimeoutException {
      // Keep a retryable bubble if confirmation could not be obtained.
      confirmed = null;
    }
    if (!_isCurrent(generation)) return;
    final extension = pending.mime == 'image/jpeg'
        ? 'jpg'
        : pending.mime!.split('/').last;
    final expectedPath =
        '${pending.conversationId}/${pending.clientTag}.$extension';
    if (confirmed == null ||
        confirmed.conversationId != pending.conversationId ||
        confirmed.clientTag != pending.clientTag ||
        confirmed.senderId != pending.senderId ||
        confirmed.attachmentPath != expectedPath ||
        confirmed.attachmentMime != pending.mime ||
        confirmed.body.isNotEmpty) {
      _updateOutbox(pending.conversationId, pending.clientTag, failed: true);
      return;
    }
    _mergeConfirmed(pending.conversationId, [confirmed]);
  }
}
