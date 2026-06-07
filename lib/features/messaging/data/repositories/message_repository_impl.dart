import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/message_repository.dart';
import '../datasources/message_remote_datasource.dart';

class MessageRepositoryImpl implements MessageRepository {
  const MessageRepositoryImpl(this._datasource);
  final MessageRemoteDataSource _datasource;

  @override
  Future<Either<Failure, List<Conversation>>> getConversations(
    String userId,
  ) async {
    try {
      return right(await _datasource.getConversations(userId));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String>> getOrCreateConversation({
    required String builderId,
    required String tradeId,
    String? jobId,
  }) async {
    try {
      return right(
        await _datasource.getOrCreateConversation(
          builderId: builderId,
          tradeId: tradeId,
          jobId: jobId,
        ),
      );
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Message>>> getMessages(
    String conversationId, {
    int? limit,
    DateTime? before,
  }) async {
    try {
      return right(
        await _datasource.getMessages(
          conversationId,
          limit: limit,
          before: before,
        ),
      );
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> sendMessage({
    required String conversationId,
    required String senderId,
    required String body,
    required String clientTag,
  }) async {
    try {
      await _datasource.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        body: body,
        clientTag: clientTag,
      );
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> markConversationRead({
    required String conversationId,
    required String userId,
    required bool isBuilder,
  }) async {
    try {
      await _datasource.markConversationRead(
        conversationId: conversationId,
        userId: userId,
        isBuilder: isBuilder,
      );
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> archiveConversation({
    required String conversationId,
    required bool isBuilder,
  }) async {
    try {
      await _datasource.archiveConversation(
        conversationId: conversationId,
        isBuilder: isBuilder,
      );
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Stream<List<Conversation>> watchConversations(String userId) =>
      _datasource.watchConversations(userId);

  @override
  Stream<List<Message>> watchMessages(
    String conversationId, {
    int tailLimit = 50,
  }) => _datasource.watchMessages(conversationId, tailLimit: tailLimit);

  @override
  Stream<Conversation> watchConversation(String conversationId) =>
      _datasource.watchConversation(conversationId);
}
