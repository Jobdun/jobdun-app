import '../entities/message.dart';
import '../repositories/message_repository.dart';

class WatchMessages {
  const WatchMessages(this._repository);
  final MessageRepository _repository;

  Stream<List<Message>> call(String conversationId, {int tailLimit = 50}) =>
      _repository.watchMessages(conversationId, tailLimit: tailLimit);
}
