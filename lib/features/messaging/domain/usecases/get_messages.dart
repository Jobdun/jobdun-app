import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/message.dart';
import '../repositories/message_repository.dart';

class GetMessages {
  const GetMessages(this._repository);
  final MessageRepository _repository;

  Future<Either<Failure, List<Message>>> call({
    required String jobId,
    required String otherUserId,
  }) =>
      _repository.getMessages(jobId: jobId, otherUserId: otherUserId);
}
