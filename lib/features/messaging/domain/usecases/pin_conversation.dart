import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/message_repository.dart';

class PinConversation {
  const PinConversation(this._repo);
  final MessageRepository _repo;

  Future<Either<Failure, void>> call({
    required String conversationId,
    required bool isBuilder,
    required bool pin,
  }) => _repo.pinConversation(
    conversationId: conversationId,
    isBuilder: isBuilder,
    pin: pin,
  );
}
