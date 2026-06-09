import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/timesheet_model.dart';

abstract interface class TimesheetRemoteDataSource {
  Future<TimesheetModel> checkIn({
    required String jobId,
    required String builderId,
    required String tradeId,
    double? lat,
    double? lng,
    String? note,
  });

  Future<void> checkOut({
    required String timesheetId,
    double? lat,
    double? lng,
  });

  Future<List<TimesheetModel>> getForJobTrade(String jobId, String tradeId);
}

class TimesheetRemoteDataSourceImpl implements TimesheetRemoteDataSource {
  const TimesheetRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<TimesheetModel> checkIn({
    required String jobId,
    required String builderId,
    required String tradeId,
    double? lat,
    double? lng,
    String? note,
  }) async {
    try {
      final data = await _client
          .from('timesheets')
          .insert({
            'job_id': jobId,
            'builder_id': builderId,
            'trade_id': tradeId,
            'check_in_lat': ?lat,
            'check_in_lng': ?lng,
            'note': ?note,
          })
          .select()
          .single();
      return TimesheetModel.fromJson(data);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> checkOut({
    required String timesheetId,
    double? lat,
    double? lng,
  }) async {
    try {
      await _client
          .from('timesheets')
          .update({
            'check_out_at': DateTime.now().toIso8601String(),
            'check_out_lat': ?lat,
            'check_out_lng': ?lng,
          })
          .eq('id', timesheetId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<TimesheetModel>> getForJobTrade(
    String jobId,
    String tradeId,
  ) async {
    try {
      final rows = await _client
          .from('timesheets')
          .select()
          .eq('job_id', jobId)
          .eq('trade_id', tradeId)
          .order('check_in_at', ascending: false);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(TimesheetModel.fromJson)
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
