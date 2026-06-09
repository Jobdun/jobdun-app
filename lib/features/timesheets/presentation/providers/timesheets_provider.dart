import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/config/supabase_config.dart';
import '../../data/datasources/timesheet_remote_datasource.dart';
import '../../data/repositories/timesheet_repository_impl.dart';
import '../../domain/entities/timesheet.dart';
import '../../domain/repositories/timesheet_repository.dart';
import '../../domain/usecases/check_in.dart';
import '../../domain/usecases/check_out.dart';
import '../../domain/usecases/get_timesheets.dart';

// ── Data layer (public so tests can override) ─────────────────────────────────
final timesheetDatasourceProvider = Provider<TimesheetRemoteDataSource>(
  (ref) => TimesheetRemoteDataSourceImpl(SupabaseConfig.client),
);

final timesheetRepositoryProvider = Provider<TimesheetRepository>(
  (ref) => TimesheetRepositoryImpl(ref.read(timesheetDatasourceProvider)),
);

// ── Use cases ─────────────────────────────────────────────────────────────────
final checkInUseCaseProvider = Provider(
  (ref) => CheckIn(ref.read(timesheetRepositoryProvider)),
);
final checkOutUseCaseProvider = Provider(
  (ref) => CheckOut(ref.read(timesheetRepositoryProvider)),
);
final getTimesheetsUseCaseProvider = Provider(
  (ref) => GetTimesheets(ref.read(timesheetRepositoryProvider)),
);

// ── Reads ─────────────────────────────────────────────────────────────────────
/// The trade's timesheet entries for one job, newest first.
final timesheetsForProvider = FutureProvider.autoDispose
    .family<List<Timesheet>, ({String jobId, String tradeId})>((
      ref,
      key,
    ) async {
      final result = await ref
          .read(getTimesheetsUseCaseProvider)
          .call(key.jobId, key.tradeId);
      return result.fold((f) => throw Exception(f.message), (l) => l);
    });

// ── Actions ───────────────────────────────────────────────────────────────────
final timesheetActionsProvider = Provider(TimesheetActions.new);

class TimesheetActions {
  TimesheetActions(this._ref);
  final Ref _ref;

  Future<bool> checkIn({
    required String jobId,
    required String builderId,
    required String tradeId,
  }) async {
    final pos = await _capturePosition();
    final result = await _ref
        .read(checkInUseCaseProvider)
        .call(
          jobId: jobId,
          builderId: builderId,
          tradeId: tradeId,
          lat: pos.lat,
          lng: pos.lng,
        );
    if (result.isRight()) {
      _ref.invalidate(timesheetsForProvider((jobId: jobId, tradeId: tradeId)));
    }
    return result.isRight();
  }

  Future<bool> checkOut({
    required String timesheetId,
    required String jobId,
    required String tradeId,
  }) async {
    final pos = await _capturePosition();
    final result = await _ref
        .read(checkOutUseCaseProvider)
        .call(timesheetId: timesheetId, lat: pos.lat, lng: pos.lng);
    if (result.isRight()) {
      _ref.invalidate(timesheetsForProvider((jobId: jobId, tradeId: tradeId)));
    }
    return result.isRight();
  }

  /// Best-effort GPS — clocking on/off still works if location is unavailable
  /// or denied; the coordinates are simply stored null.
  Future<({double? lat, double? lng})> _capturePosition() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return (lat: null, lng: null);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return (lat: null, lng: null);
    }
  }
}
