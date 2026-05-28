import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/admin/features/admin_user_detail/domain/entities/admin_user_detail.dart';
import 'package:jobdun/admin/features/admin_user_detail/domain/repositories/admin_user_detail_repository.dart';
import 'package:jobdun/admin/features/admin_user_detail/domain/usecases/get_admin_user_detail.dart';
import 'package:jobdun/core/errors/failures.dart';

class _MockRepo extends Mock implements AdminUserDetailRepository {}

void main() {
  late GetAdminUserDetail useCase;
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    useCase = GetAdminUserDetail(repo);
  });

  test('forwards user id to repository', () async {
    final detail = AdminUserDetail(
      id: 'u1',
      displayName: 'Alice',
      role: 'trade',
      createdAt: DateTime(2026, 1, 1),
    );
    when(() => repo.getUserDetail('u1'))
        .thenAnswer((_) async => Right(detail));

    final result = await useCase('u1');

    expect(result.isRight(), isTrue);
    verify(() => repo.getUserDetail('u1')).called(1);
  });

  test('propagates failures', () async {
    when(() => repo.getUserDetail(any())).thenAnswer(
      (_) async => const Left(ServerFailure('boom')),
    );
    final result = await useCase('u1');
    expect(result.isLeft(), isTrue);
  });
}
