import '../../domain/entities/message.dart';

/// Render-time status of a message in the thread. NOT a DB column — derived
/// from where the message lives (outbox vs server) + the counterparty's read
/// marker. See docs/superpowers/specs/2026-06-08-messaging-reliability-core-design.md.
enum MessageStatus {
  /// Optimistic bubble; the insert is in flight.
  sending,

  /// On the server, but the counterparty has not read up to it yet.
  sent,

  /// The counterparty's `last_read_at` is at/after this message.
  seen,

  /// The insert failed; offer a retry.
  failed,
}

/// A message the user has sent locally that has not yet been confirmed by the
/// server (no realtime echo carrying its [clientTag] has arrived). Lives only
/// in memory, in the controller's per-conversation outbox.
class PendingMessage {
  const PendingMessage({
    required this.clientTag,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.failed = false,
  });

  final String clientTag;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final bool failed;

  PendingMessage copyWith({bool? failed}) => PendingMessage(
    clientTag: clientTag,
    conversationId: conversationId,
    senderId: senderId,
    body: body,
    createdAt: createdAt,
    failed: failed ?? this.failed,
  );
}

/// A single rendered row in the thread — either a confirmed server message or
/// an unconfirmed outbox message — flattened to exactly what the bubble needs,
/// plus its derived [status].
class ThreadEntry {
  const ThreadEntry({
    required this.key,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.status,
    required this.isPending,
    this.clientTag,
  });

  /// Stable identity for keys + grouping: the server id, or `pending:<tag>`.
  final String key;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final MessageStatus status;
  final bool isPending;
  // The outbox idempotency key — set for pending entries so a failed one can be
  // retried. Null for confirmed server messages.
  final String? clientTag;
}

/// Merges confirmed server messages with the optimistic outbox into one ordered
/// list (oldest→newest), deduping the optimistic copy once its server echo
/// arrives (matched by `client_tag`), and deriving each message's [MessageStatus].
///
/// Pure + side-effect free so it can be unit-tested without Supabase or widgets.
List<ThreadEntry> buildThreadEntries({
  required List<Message> confirmed,
  required List<PendingMessage> outbox,
  required DateTime? otherLastReadAt,
  required String? me,
}) {
  // Dedup confirmed rows by server id (historical page + live tail can overlap).
  final byId = <String, Message>{};
  for (final m in confirmed) {
    byId[m.id] = m;
  }
  final confirmedTags = byId.values
      .map((m) => m.clientTag)
      .whereType<String>()
      .toSet();

  final entries = <ThreadEntry>[];

  for (final m in byId.values) {
    final mine = me != null && m.senderId == me;
    final seen =
        mine &&
        otherLastReadAt != null &&
        !otherLastReadAt.isBefore(m.createdAt);
    entries.add(
      ThreadEntry(
        key: m.id,
        senderId: m.senderId,
        body: m.body,
        createdAt: m.createdAt,
        status: seen ? MessageStatus.seen : MessageStatus.sent,
        isPending: false,
      ),
    );
  }

  for (final p in outbox) {
    // Echo already merged in from the server — drop the optimistic twin.
    if (confirmedTags.contains(p.clientTag)) continue;
    entries.add(
      ThreadEntry(
        key: 'pending:${p.clientTag}',
        senderId: p.senderId,
        body: p.body,
        createdAt: p.createdAt,
        status: p.failed ? MessageStatus.failed : MessageStatus.sending,
        isPending: true,
        clientTag: p.clientTag,
      ),
    );
  }

  entries.sort((a, b) {
    final byTime = a.createdAt.compareTo(b.createdAt);
    if (byTime != 0) return byTime;
    // At identical timestamps keep confirmed before pending, then stable by key.
    if (a.isPending != b.isPending) return a.isPending ? 1 : -1;
    return a.key.compareTo(b.key);
  });

  return entries;
}
