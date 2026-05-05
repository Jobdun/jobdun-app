import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/notification_repository.dart';

class MarkAsRead {
  const MarkAsRead(this._repository);
  final NotificationRepository _repository;

  Future<Either<Failure, void>> call(String notificationId) =>
      _repository.markAsRead(notificationId);
}
