import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/notification_repository.dart';

class MarkAllAsRead {
  const MarkAllAsRead(this._repository);
  final NotificationRepository _repository;

  Future<Either<Failure, void>> call(String userId) =>
      _repository.markAllAsRead(userId);
}
