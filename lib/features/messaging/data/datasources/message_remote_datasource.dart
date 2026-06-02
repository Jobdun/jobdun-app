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
  Future<List<MessageModel>> getMessages(String conversationId);
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String body,
  });
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
  Stream<List<MessageModel>> watchMessages(String conversationId);
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
  Future<List<MessageModel>> getMessages(String conversationId) async {
    try {
      final data = await _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .isFilter('deleted_at', null)
          .order('created_at');
      return (data as List)
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String body,
  }) async {
    try {
      await _client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': senderId,
        'body': body,
      });
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
  Stream<List<MessageModel>> watchMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map(
          (rows) => rows
              .where((r) => r['deleted_at'] == null)
              .map(MessageModel.fromJson)
              .toList(),
        );
  }
}
