import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_audit_event.dart';

abstract class AdminAuditRepository {
  Future<Either<Failure, List<AdminAuditEvent>>> listEvents({
    required int limit,
    required int offset,
  });
}
