import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/message_reaction.dart';
import '../../domain/entities/report_submission.dart';
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
  Future<Either<Failure, void>> softDeleteMessage(String messageId) async {
    try {
      await _datasource.softDeleteMessage(messageId);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> sendImageMessage({
    required String conversationId,
    required String senderId,
    required String clientTag,
    required File file,
    required String mime,
    int? width,
    int? height,
  }) async {
    try {
      await _datasource.sendImageMessage(
        conversationId: conversationId,
        senderId: senderId,
        clientTag: clientTag,
        file: file,
        mime: mime,
        width: width,
        height: height,
      );
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String>> signedAttachmentUrl(String path) async {
    try {
      return right(await _datasource.signedAttachmentUrl(path));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> setReaction({
    required String messageId,
    required String conversationId,
    required String userId,
    required String emoji,
  }) async {
    try {
      await _datasource.setReaction(
        messageId: messageId,
        conversationId: conversationId,
        userId: userId,
        emoji: emoji,
      );
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> removeReaction({
    required String messageId,
    required String userId,
  }) async {
    try {
      await _datasource.removeReaction(messageId: messageId, userId: userId);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Stream<List<MessageReaction>> watchReactions(String conversationId) =>
      _datasource.watchReactions(conversationId);

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

  // ── Phase D: inbox power + safety ──────────────────────────────────────
  @override
  Future<Either<Failure, void>> pinConversation({
    required String conversationId,
    required bool isBuilder,
    required bool pin,
  }) async {
    try {
      await _datasource.pinConversation(
        conversationId: conversationId,
        isBuilder: isBuilder,
        pin: pin,
      );
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> muteConversation({
    required String conversationId,
    required bool isBuilder,
    required bool mute,
  }) async {
    try {
      await _datasource.muteConversation(
        conversationId: conversationId,
        isBuilder: isBuilder,
        mute: mute,
      );
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> markConversationUnread({
    required String conversationId,
    required bool isBuilder,
  }) async {
    try {
      await _datasource.markConversationUnread(
        conversationId: conversationId,
        isBuilder: isBuilder,
      );
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> blockUser({
    required String blockerId,
    required String blockedId,
    required String conversationId,
  }) async {
    try {
      await _datasource.blockUser(
        blockerId: blockerId,
        blockedId: blockedId,
        conversationId: conversationId,
      );
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> reportUser({
    required ReportSubmission report,
  }) async {
    try {
      await _datasource.reportUser(report);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, bool>> amIBlocking(String blockedId) async {
    try {
      return right(await _datasource.amIBlocking(blockedId));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> unblockUser({
    required String blockedId,
    required String conversationId,
  }) async {
    try {
      await _datasource.unblockUser(
        blockedId: blockedId,
        conversationId: conversationId,
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
