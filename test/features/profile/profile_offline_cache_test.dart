import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/cache/in_memory_cache_store.dart';
import 'package:jobdun/core/errors/exceptions.dart';
import 'package:jobdun/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:jobdun/features/profile/data/models/builder_profile_model.dart';
import 'package:jobdun/features/profile/data/models/trade_profile_model.dart';
import 'package:jobdun/features/profile/data/models/user_profile_model.dart';
import 'package:jobdun/features/profile/data/repositories/profile_repository_impl.dart';

class MockProfileRemoteDataSource extends Mock
    implements ProfileRemoteDataSource {}

void main() {
  test('UserProfileModel.toCacheMap round-trips (id/email/dates)', () {
    final m = UserProfileModel(
      id: 'u1',
      displayName: 'Ken',
      email: 'k@x.com',
      phone: '0400',
      avatarUrl: 'http://a',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 2, 2),
    );
    final r = UserProfileModel.fromJson(m.toCacheMap());
    expect(r.id, 'u1');
    expect(r.email, 'k@x.com');
    expect(r.displayName, 'Ken');
    expect(r.createdAt, m.createdAt);
  });

  test('BuilderProfileModel.toCacheMap round-trips (server stats kept)', () {
    const m = BuilderProfileModel(
      id: 'b1',
      companyName: 'Acme',
      totalJobsPosted: 7,
      ratingCount: 3,
      averageRating: 4.5,
    );
    final r = BuilderProfileModel.fromJson(m.toCacheMap());
    expect(r.id, 'b1');
    expect(r.companyName, 'Acme');
    expect(r.totalJobsPosted, 7);
    expect(r.averageRating, 4.5);
  });

  test('TradeProfileModel.toCacheMap round-trips (verification + stats)', () {
    const m = TradeProfileModel(
      id: 't1',
      fullName: 'Jo',
      primaryTrade: 'Electrician',
      isVerified: true,
      jobsCompleted: 9,
      portfolioUrls: ['p1'],
    );
    final r = TradeProfileModel.fromJson(m.toCacheMap());
    expect(r.id, 't1');
    expect(r.isVerified, isTrue);
    expect(r.jobsCompleted, 9);
    expect(r.portfolioUrls, ['p1']);
  });

  test('getProfile caches on success and serves last-known offline', () async {
    final ds = MockProfileRemoteDataSource();
    final repo = ProfileRepositoryImpl(ds, InMemoryCacheStore());

    when(() => ds.getProfile('u1')).thenAnswer(
      (_) async => const UserProfileModel(id: 'u1', displayName: 'Ken'),
    );
    final online = await repo.getProfile('u1');
    expect(online.isRight(), isTrue);

    when(() => ds.getProfile('u1')).thenThrow(const ServerException('offline'));
    final offline = await repo.getProfile('u1');
    expect(offline.isRight(), isTrue, reason: 'served cached profile');
    offline.fold(
      (_) => fail('expected cached profile'),
      (p) => expect(p.displayName, 'Ken'),
    );
  });

  test('getBuilderProfile serves last-known offline', () async {
    final ds = MockProfileRemoteDataSource();
    final repo = ProfileRepositoryImpl(ds, InMemoryCacheStore());

    when(() => ds.getBuilderProfile('u1')).thenAnswer(
      (_) async => const BuilderProfileModel(id: 'b1', companyName: 'Acme'),
    );
    await repo.getBuilderProfile('u1');

    when(
      () => ds.getBuilderProfile('u1'),
    ).thenThrow(const ServerException('offline'));
    final offline = await repo.getBuilderProfile('u1');
    expect(offline.isRight(), isTrue);
    offline.fold(
      (_) => fail('cached'),
      (bp) => expect(bp?.companyName, 'Acme'),
    );
  });
}
