import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/app_notification.dart';

abstract interface class NotificationRepository {
  Future<Either<Failure, List<AppNotification>>> getNotifications(
    String userId,
  );
  Future<Either<Failure, void>> markAsRead(String notificationId);
  Future<Either<Failure, void>> markAllAsRead(String userId);
  Stream<List<AppNotification>> watchNotifications(String userId);
}
