import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/message.dart';
import '../repositories/message_repository.dart';

class SendMessage {
  const SendMessage(this._repository);
  final MessageRepository _repository;

  Future<Either<Failure, void>> call(Message message) =>
      _repository.sendMessage(message);
}
