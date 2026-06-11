import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/core/cache/cache_store.dart';
import 'package:jobdun/core/errors/exceptions.dart';
import 'package:jobdun/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:jobdun/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:jobdun/features/profile/domain/entities/profile_patches.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements ProfileRemoteDataSource {}

class _MockCache extends Mock implements CacheStore {}

void main() {
  late _MockDatasource ds;
  late ProfileRepositoryImpl repo;

  setUpAll(() {
    registerFallbackValue(const UserProfilePatch());
    registerFallbackValue(const TradeProfilePatch());
    registerFallbackValue(const BuilderProfilePatch());
  });

  setUp(() {
    ds = _MockDatasource();
    repo = ProfileRepositoryImpl(ds, _MockCache());
  });

  test('patchTradeProfile forwards userId + patch and returns right', () async {
    const patch = TradeProfilePatch(about: Some('Brickie, 10 yrs'));
    when(() => ds.patchTradeProfile('u1', patch)).thenAnswer((_) async {});
    final r = await repo.patchTradeProfile('u1', patch);
    expect(r.isRight(), isTrue);
    verify(() => ds.patchTradeProfile('u1', patch)).called(1);
  });

  test('patchUserProfile maps ServerException to ServerFailure', () async {
    const patch = UserProfilePatch(displayName: Some('Ken'));
    when(
      () => ds.patchUserProfile('u1', patch),
    ).thenThrow(const ServerException('boom'));
    final r = await repo.patchUserProfile('u1', patch);
    expect(r.isLeft(), isTrue);
  });

  test('empty patch short-circuits without a network call', () async {
    final r = await repo.patchBuilderProfile('u1', const BuilderProfilePatch());
    expect(r.isRight(), isTrue);
    verifyNever(() => ds.patchBuilderProfile(any(), any()));
  });
}
