import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/message_repository.dart';
import '../datasources/message_remote_datasource.dart';
import '../models/message_model.dart';

class MessageRepositoryImpl implements MessageRepository {
  const MessageRepositoryImpl(this._datasource, this._client);
  final MessageRemoteDataSource _datasource;
  final SupabaseClient _client;

  String get _currentUserId => _client.auth.currentUser?.id ?? '';

  @override
  Future<Either<Failure, void>> sendMessage(Message message) async {
    try {
      await _datasource.sendMessage(message as MessageModel);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Message>>> getMessages({
    required String jobId,
    required String otherUserId,
  }) async {
    try {
      final messages = await _datasource.getMessages(
        jobId: jobId,
        otherUserId: otherUserId,
        currentUserId: _currentUserId,
      );
      return right(messages);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Conversation>>> getConversations(
    String userId,
  ) async {
    // Conversations are derived by grouping messages — implement when UI is ready.
    return right(const []);
  }

  @override
  Future<Either<Failure, void>> markAsRead(String messageId) async {
    try {
      await _datasource.markAsRead(messageId);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Stream<List<Message>> watchMessages({
    required String jobId,
    required String otherUserId,
  }) =>
      _datasource.watchMessages(
        jobId: jobId,
        otherUserId: otherUserId,
        currentUserId: _currentUserId,
      );
}
