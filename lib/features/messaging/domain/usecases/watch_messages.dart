import '../entities/message.dart';
import '../repositories/message_repository.dart';

class WatchMessages {
  const WatchMessages(this._repository);
  final MessageRepository _repository;

  Stream<List<Message>> call({
    required String jobId,
    required String otherUserId,
  }) =>
      _repository.watchMessages(jobId: jobId, otherUserId: otherUserId);
}
