import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/timesheets/domain/entities/timesheet.dart';
import 'package:jobdun/features/timesheets/domain/repositories/timesheet_repository.dart';
import 'package:jobdun/features/timesheets/presentation/providers/timesheets_provider.dart';

class _FakeRepo implements TimesheetRepository {
  String? ciJob, ciBuilder, ciTrade, coId;

  @override
  Future<Either<Failure, Timesheet>> checkIn({
    required String jobId,
    required String builderId,
    required String tradeId,
    double? lat,
    double? lng,
    String? note,
  }) async {
    ciJob = jobId;
    ciBuilder = builderId;
    ciTrade = tradeId;
    return Right(
      Timesheet(
        id: 'ts1',
        jobId: jobId,
        builderId: builderId,
        tradeId: tradeId,
        checkInAt: DateTime(2026, 6, 10, 8),
        createdAt: DateTime(2026),
      ),
    );
  }

  @override
  Future<Either<Failure, void>> checkOut({
    required String timesheetId,
    double? lat,
    double? lng,
  }) async {
    coId = timesheetId;
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<Timesheet>>> getForJobTrade(
    String jobId,
    String tradeId,
  ) async => const Right([]);
}

ProviderContainer _container(_FakeRepo repo) => ProviderContainer(
  overrides: [timesheetRepositoryProvider.overrideWithValue(repo)],
);

void main() {
  test('checkIn forwards job + builder + trade ids', () async {
    final repo = _FakeRepo();
    final c = _container(repo);
    addTearDown(c.dispose);

    final ok = await c
        .read(timesheetActionsProvider)
        .checkIn(jobId: 'j1', builderId: 'b1', tradeId: 't1');

    expect(ok, isTrue);
    expect(repo.ciJob, 'j1');
    expect(repo.ciBuilder, 'b1');
    expect(repo.ciTrade, 't1');
  });

  test('checkOut forwards the timesheet id', () async {
    final repo = _FakeRepo();
    final c = _container(repo);
    addTearDown(c.dispose);

    final ok = await c
        .read(timesheetActionsProvider)
        .checkOut(timesheetId: 'ts1', jobId: 'j1', tradeId: 't1');

    expect(ok, isTrue);
    expect(repo.coId, 'ts1');
  });
}
