import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/message_model.dart';

abstract interface class MessageRemoteDataSource {
  Future<void> sendMessage(MessageModel message);
  Future<List<MessageModel>> getMessages({
    required String jobId,
    required String otherUserId,
    required String currentUserId,
  });
  Future<void> markAsRead(String messageId);
  Stream<List<MessageModel>> watchMessages({
    required String jobId,
    required String otherUserId,
    required String currentUserId,
  });
}

class MessageRemoteDataSourceImpl implements MessageRemoteDataSource {
  const MessageRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<void> sendMessage(MessageModel message) async {
    try {
      await _client.from('messages').insert(message.toJson());
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<MessageModel>> getMessages({
    required String jobId,
    required String otherUserId,
    required String currentUserId,
  }) async {
    try {
      final data = await _client
          .from('messages')
          .select()
          .eq('job_id', jobId)
          .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId')
          .order('created_at');
      return (data as List)
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .where((m) =>
              (m.senderId == currentUserId && m.receiverId == otherUserId) ||
              (m.senderId == otherUserId && m.receiverId == currentUserId))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> markAsRead(String messageId) async {
    try {
      await _client
          .from('messages')
          .update({'is_read': true})
          .eq('id', messageId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Stream<List<MessageModel>> watchMessages({
    required String jobId,
    required String otherUserId,
    required String currentUserId,
  }) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('job_id', jobId)
        .order('created_at')
        .map((rows) => rows
            .map(MessageModel.fromJson)
            .where((m) =>
                (m.senderId == currentUserId && m.receiverId == otherUserId) ||
                (m.senderId == otherUserId && m.receiverId == currentUserId))
            .toList());
  }
}
