import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

abstract interface class MessageRemoteDataSource {
  Future<List<ConversationModel>> getConversations(String userId);
  Future<List<MessageModel>> getMessages(String conversationId);
  Future<void> sendMessage({required String conversationId, required String senderId, required String body});
  Future<void> markConversationRead({required String conversationId, required String userId, required bool isBuilder});
  Stream<List<ConversationModel>> watchConversations(String userId);
  Stream<List<MessageModel>> watchMessages(String conversationId);
}

class MessageRemoteDataSourceImpl implements MessageRemoteDataSource {
  const MessageRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<List<ConversationModel>> getConversations(String userId) async {
    try {
      final data = await _client
          .from('conversations')
          .select('*, jobs(title)')
          .or('builder_id.eq.$userId,trade_id.eq.$userId')
          .neq('status', 'blocked')
          .order('last_message_at', ascending: false, nullsFirst: false);
      return (data as List).map((e) => ConversationModel.fromJson(e as Map<String, dynamic>)).toList();
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
      return (data as List).map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
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
      final countColumn = isBuilder ? 'builder_unread_count' : 'trade_unread_count';
      await _client.from('conversations').update({
        column: DateTime.now().toIso8601String(),
        countColumn: 0,
      }).eq('id', conversationId);
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
        .map((rows) => rows
            .where((r) => r['builder_id'] == userId || r['trade_id'] == userId)
            .map(ConversationModel.fromJson)
            .toList());
  }

  @override
  Stream<List<MessageModel>> watchMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) => rows
            .where((r) => r['deleted_at'] == null)
            .map(MessageModel.fromJson)
            .toList());
  }
}
