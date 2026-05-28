import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/admin/features/admin_audit/domain/entities/admin_audit_event.dart';
import 'package:jobdun/admin/features/admin_audit/domain/repositories/admin_audit_repository.dart';
import 'package:jobdun/admin/features/admin_audit/domain/usecases/list_admin_audit_events.dart';
import 'package:jobdun/core/errors/failures.dart';

class _MockRepo extends Mock implements AdminAuditRepository {}

void main() {
  late ListAdminAuditEvents useCase;
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    useCase = ListAdminAuditEvents(repo);
  });

  test('forwards params to repository', () async {
    final event = AdminAuditEvent(
      id: 'e1',
      occurredAt: DateTime(2026, 5, 1),
      source: AdminAuditSource.verification,
      eventType: 'document_submitted',
    );
    when(
      () => repo.listEvents(limit: 50, offset: 0),
    ).thenAnswer((_) async => Right([event]));

    final result = await useCase(
      const ListAdminAuditEventsParams(limit: 50, offset: 0),
    );

    expect(result.isRight(), isTrue);
    verify(() => repo.listEvents(limit: 50, offset: 0)).called(1);
  });

  test('propagates failures', () async {
    when(
      () => repo.listEvents(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await useCase(
      const ListAdminAuditEventsParams(limit: 50, offset: 0),
    );

    expect(result.isLeft(), isTrue);
  });
}
