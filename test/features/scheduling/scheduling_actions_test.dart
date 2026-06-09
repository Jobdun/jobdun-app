import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/scheduling/domain/entities/booking.dart';
import 'package:jobdun/features/scheduling/domain/repositories/booking_repository.dart';
import 'package:jobdun/features/scheduling/presentation/providers/scheduling_provider.dart';

class _FakeRepo implements BookingRepository {
  String? createdBuilder, createdJob, createdTrade;
  DateTime? createdDate;
  String? statusId;
  BookingStatus? statusValue;

  @override
  Future<Either<Failure, Booking>> create({
    required String jobId,
    required String builderId,
    required String tradeId,
    required DateTime scheduledDate,
    String? note,
  }) async {
    createdJob = jobId;
    createdBuilder = builderId;
    createdTrade = tradeId;
    createdDate = scheduledDate;
    return Right(
      Booking(
        id: 'bk1',
        jobId: jobId,
        builderId: builderId,
        tradeId: tradeId,
        scheduledDate: scheduledDate,
        status: BookingStatus.scheduled,
        createdAt: DateTime(2026),
      ),
    );
  }

  @override
  Future<Either<Failure, List<Booking>>> getForUser(String userId) async =>
      const Right([]);

  @override
  Future<Either<Failure, void>> updateStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    statusId = bookingId;
    statusValue = status;
    return const Right(null);
  }
}

ProviderContainer _container(_FakeRepo repo, {String? uid = 'b1'}) =>
    ProviderContainer(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(repo),
        currentUserIdSyncProvider.overrideWithValue(uid),
      ],
    );

void main() {
  test('create stamps builderId from the signed-in user + forwards', () async {
    final repo = _FakeRepo();
    final c = _container(repo);
    addTearDown(c.dispose);

    final ok = await c
        .read(bookingActionsProvider)
        .create(
          jobId: 'j1',
          tradeId: 't1',
          scheduledDate: DateTime(2026, 7, 1),
        );

    expect(ok, isTrue);
    expect(repo.createdBuilder, 'b1');
    expect(repo.createdJob, 'j1');
    expect(repo.createdTrade, 't1');
    expect(repo.createdDate, DateTime(2026, 7, 1));
  });

  test('create returns false when signed out', () async {
    final repo = _FakeRepo();
    final c = _container(repo, uid: null);
    addTearDown(c.dispose);

    final ok = await c
        .read(bookingActionsProvider)
        .create(
          jobId: 'j1',
          tradeId: 't1',
          scheduledDate: DateTime(2026, 7, 1),
        );

    expect(ok, isFalse);
    expect(repo.createdJob, isNull);
  });

  test('setStatus forwards id + status', () async {
    final repo = _FakeRepo();
    final c = _container(repo);
    addTearDown(c.dispose);

    final ok = await c
        .read(bookingActionsProvider)
        .setStatus('bk1', BookingStatus.completed);

    expect(ok, isTrue);
    expect(repo.statusId, 'bk1');
    expect(repo.statusValue, BookingStatus.completed);
  });
}
