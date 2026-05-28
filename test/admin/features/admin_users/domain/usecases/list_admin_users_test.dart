import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/admin/features/admin_users/domain/entities/admin_user_filter.dart';
import 'package:jobdun/admin/features/admin_users/domain/entities/admin_user_row.dart';
import 'package:jobdun/admin/features/admin_users/domain/repositories/admin_users_repository.dart';
import 'package:jobdun/admin/features/admin_users/domain/usecases/list_admin_users.dart';
import 'package:jobdun/core/errors/failures.dart';

class _MockRepo extends Mock implements AdminUsersRepository {}

void main() {
  late ListAdminUsers useCase;
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(AdminUserRoleFilter.all);
  });

  setUp(() {
    repo = _MockRepo();
    useCase = ListAdminUsers(repo);
  });

  test('forwards params to repository', () async {
    final row = AdminUserRow(
      id: 'u1',
      displayName: 'Alice',
      role: 'trade',
      isVerified: true,
      createdAt: DateTime(2026, 1, 1),
    );
    when(
      () => repo.listUsers(
        limit: 50,
        offset: 0,
        filter: AdminUserRoleFilter.trade,
        query: 'ali',
      ),
    ).thenAnswer((_) async => Right([row]));

    final result = await useCase(
      const ListAdminUsersParams(
        limit: 50,
        offset: 0,
        filter: AdminUserRoleFilter.trade,
        query: 'ali',
      ),
    );

    expect(result.isRight(), isTrue);
    verify(
      () => repo.listUsers(
        limit: 50,
        offset: 0,
        filter: AdminUserRoleFilter.trade,
        query: 'ali',
      ),
    ).called(1);
  });

  test('propagates failures', () async {
    when(
      () => repo.listUsers(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        filter: any(named: 'filter'),
        query: any(named: 'query'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await useCase(
      const ListAdminUsersParams(limit: 50, offset: 0),
    );

    expect(result.isLeft(), isTrue);
  });
}
