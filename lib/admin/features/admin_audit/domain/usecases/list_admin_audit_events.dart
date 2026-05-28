import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_audit_event.dart';
import '../repositories/admin_audit_repository.dart';

class ListAdminAuditEventsParams {
  const ListAdminAuditEventsParams({required this.limit, required this.offset});
  final int limit;
  final int offset;
}

class ListAdminAuditEvents {
  const ListAdminAuditEvents(this._repository);

  final AdminAuditRepository _repository;

  Future<Either<Failure, List<AdminAuditEvent>>> call(
    ListAdminAuditEventsParams params,
  ) =>
      _repository.listEvents(limit: params.limit, offset: params.offset);
}
