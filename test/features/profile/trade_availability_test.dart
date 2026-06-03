import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/exceptions.dart';
import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:jobdun/features/profile/data/repositories/profile_repository_impl.dart';

class _MockDs extends Mock implements ProfileRemoteDataSource {}

void main() {
  late ProfileRepositoryImpl repo;
  late _MockDs ds;

  setUp(() {
    ds = _MockDs();
    repo = ProfileRepositoryImpl(ds);
  });

  test('setTradeAvailability returns Right(void) on success', () async {
    when(() => ds.setTradeAvailability('uid', false)).thenAnswer((_) async {});

    final out = await repo.setTradeAvailability('uid', false);

    expect(out.isRight(), isTrue);
    verify(() => ds.setTradeAvailability('uid', false)).called(1);
  });

  test('setTradeAvailability maps ServerException to ServerFailure', () async {
    when(
      () => ds.setTradeAvailability(any(), any()),
    ).thenThrow(const ServerException('update failed'));

    final out = await repo.setTradeAvailability('uid', true);

    out.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected failure'),
    );
  });
}
