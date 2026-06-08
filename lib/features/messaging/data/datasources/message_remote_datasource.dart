import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

abstract interface class MessageRemoteDataSource {
  Future<List<ConversationModel>> getConversations(String userId);
  Future<String> getOrCreateConversation({
    required String builderId,
    required String tradeId,
    String? jobId,
  });

  /// Fetches messages oldest→newest. With [limit] set, returns the most-recent
  /// page (or, with [before], the page immediately older than that timestamp) —
  /// used for scroll-back pagination. With [limit] null, returns the whole
  /// thread (one-shot callers).
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    int? limit,
    DateTime? before,
  });
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String body,
    required String clientTag,
  });

  /// Soft-delete (unsend) a message — sets `deleted_at`. RLS limits this to the
  /// sender's own messages.
  Future<void> softDeleteMessage(String messageId);
  Future<void> markConversationRead({
    required String conversationId,
    required String userId,
    required bool isBuilder,
  });
  Future<void> archiveConversation({
    required String conversationId,
    required bool isBuilder,
  });
  Stream<List<ConversationModel>> watchConversations(String userId);

  /// Live tail of the most recent [tailLimit] messages, oldest→newest. Older
  /// history is paged in separately via [getMessages].
  Stream<List<MessageModel>> watchMessages(
    String conversationId, {
    int tailLimit,
  });

  /// Live updates to a single conversation row — used by the thread to read the
  /// counterparty's `*_last_read_at` (the "Seen" marker) as it changes.
  Stream<ConversationModel> watchConversation(String conversationId);
}

class MessageRemoteDataSourceImpl implements MessageRemoteDataSource {
  const MessageRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<List<ConversationModel>> getConversations(String userId) async {
    try {
      // get_inbox() resolves the counterparty (display name/avatar), the
      // viewer's unread count, and the job title server-side, and already
      // excludes the viewer's archived rows. See migration
      // 20260603000001_messaging_realtime_fixes.sql.
      final data = await _client.rpc('get_inbox', params: {'p_user': userId});
      return (data as List)
          .map(
            (e) => ConversationModel.fromInboxRow(
              e as Map<String, dynamic>,
              viewerId: userId,
            ),
          )
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<String> getOrCreateConversation({
    required String builderId,
    required String tradeId,
    String? jobId,
  }) async {
    try {
      final id = await _client.rpc(
        'get_or_create_conversation',
        params: {'p_builder': builderId, 'p_trade': tradeId, 'p_job': jobId},
      );
      return id as String;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    int? limit,
    DateTime? before,
  }) async {
    try {
      // Deleted rows are intentionally NOT filtered out — they render as a
      // "message deleted" tombstone (Phase C). RLS still scopes to participants.
      final base = _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId);

      // One-shot path: whole thread, oldest-first.
      if (limit == null) {
        final data = await base.order('created_at', ascending: true);
        return (data as List)
            .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // Paged path: take the most-recent `limit` (older than `before` when
      // scrolling back) newest-first, then reverse to oldest-first for display.
      final filtered = before == null
          ? base
          : base.lt('created_at', before.toIso8601String());
      final data = await filtered
          .order('created_at', ascending: false)
          .limit(limit);
      final page = (data as List)
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return page.reversed.toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String body,
    required String clientTag,
  }) async {
    try {
      // Upsert + ignoreDuplicates makes a retry idempotent: a second insert
      // with the same (conversation_id, client_tag) is a no-op rather than a
      // duplicate row. Verified against Supabase docs (context7).
      await _client
          .from('messages')
          .upsert(
            {
              'conversation_id': conversationId,
              'sender_id': senderId,
              'body': body,
              'client_tag': clientTag,
            },
            onConflict: 'conversation_id,client_tag',
            ignoreDuplicates: true,
          );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> softDeleteMessage(String messageId) async {
    try {
      // RLS (messages_modify_own) restricts this to the sender's own rows.
      await _client
          .from('messages')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', messageId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> markConversationRead({
    required String conversationId,
    required String userId,
    required bool isBuilder,
  }) async {
    try {
      final column = isBuilder ? 'builder_last_read_at' : 'trade_last_read_at';
      final countColumn = isBuilder
          ? 'builder_unread_count'
          : 'trade_unread_count';
      await _client
          .from('conversations')
          .update({column: DateTime.now().toIso8601String(), countColumn: 0})
          .eq('id', conversationId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> archiveConversation({
    required String conversationId,
    required bool isBuilder,
  }) async {
    try {
      final column = isBuilder ? 'builder_archived_at' : 'trade_archived_at';
      await _client
          .from('conversations')
          .update({column: DateTime.now().toIso8601String()})
          .eq('id', conversationId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Stream<List<ConversationModel>> watchConversations(String userId) {
    return _client
        .from('conversations')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
        .map(
          (rows) => rows
              .where((r) {
                // Mirror the getConversations() filter: include rows for which
                // the current viewer is a participant AND has not archived
                // their side. Stream-side filtering since the realtime channel
                // doesn't accept compound or() expressions.
                final isBuilder = r['builder_id'] == userId;
                final isTrade = r['trade_id'] == userId;
                if (!isBuilder && !isTrade) return false;
                final archivedKey = isBuilder
                    ? 'builder_archived_at'
                    : 'trade_archived_at';
                return r[archivedKey] == null;
              })
              .map(ConversationModel.fromJson)
              .toList(),
        );
  }

  @override
  Stream<List<MessageModel>> watchMessages(
    String conversationId, {
    int tailLimit = 50,
  }) {
    // Most-recent `tailLimit` newest-first (so the window keeps the latest as
    // new rows arrive), reversed to oldest-first for the merge/display.
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(tailLimit)
        // Deleted rows stay in the stream so an unsend echoes live as a
        // tombstone; the UI renders the tombstone from MessageModel.isDeleted.
        .map(
          (rows) => rows.map(MessageModel.fromJson).toList().reversed.toList(),
        );
  }

  @override
  Stream<ConversationModel> watchConversation(String conversationId) {
    return _client
        .from('conversations')
        .stream(primaryKey: ['id'])
        .eq('id', conversationId)
        .map(
          (rows) =>
              rows.isEmpty ? null : ConversationModel.fromJson(rows.first),
        )
        .where((c) => c != null)
        .cast<ConversationModel>();
  }
}
