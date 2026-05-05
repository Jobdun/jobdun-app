import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/app_notification.dart';
import '../repositories/notification_repository.dart';

class GetNotifications {
  const GetNotifications(this._repository);
  final NotificationRepository _repository;

  Future<Either<Failure, List<AppNotification>>> call(String userId) =>
      _repository.getNotifications(userId);
}
