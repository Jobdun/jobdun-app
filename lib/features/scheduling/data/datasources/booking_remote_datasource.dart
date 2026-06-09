import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/booking.dart';
import '../models/booking_model.dart';

abstract interface class BookingRemoteDataSource {
  Future<BookingModel> create({
    required String jobId,
    required String builderId,
    required String tradeId,
    required DateTime scheduledDate,
    String? note,
  });

  // Bookings the user is party to — as the builder OR the trade.
  Future<List<BookingModel>> getForUser(String userId);

  Future<void> updateStatus(String bookingId, BookingStatus status);
}

class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  const BookingRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<BookingModel> create({
    required String jobId,
    required String builderId,
    required String tradeId,
    required DateTime scheduledDate,
    String? note,
  }) async {
    try {
      final data = await _client
          .from('bookings')
          .insert({
            'job_id': jobId,
            'builder_id': builderId,
            'trade_id': tradeId,
            'scheduled_date': scheduledDate.toIso8601String().substring(0, 10),
            'note': ?note,
          })
          .select()
          .single();
      return BookingModel.fromJson(data);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<BookingModel>> getForUser(String userId) async {
    try {
      final rows = await _client
          .from('bookings')
          .select('*, jobs(title)')
          .or('builder_id.eq.$userId,trade_id.eq.$userId')
          .order('scheduled_date', ascending: true);
      final list = (rows as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) return const [];
      // builder_id / trade_id FK profiles, not the role tables — merge names.
      await _mergeName(
        list,
        idKey: 'builder_id',
        table: 'builder_profiles',
        columns: 'id, company_name',
        embedKey: 'builder_profiles',
      );
      await _mergeName(
        list,
        idKey: 'trade_id',
        table: 'trade_profiles',
        columns: 'id, full_name',
        embedKey: 'trade_profiles',
      );
      return list.map(BookingModel.fromJson).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<void> _mergeName(
    List<Map<String, dynamic>> rows, {
    required String idKey,
    required String table,
    required String columns,
    required String embedKey,
  }) async {
    final ids = rows.map((r) => r[idKey] as String).toSet().toList();
    if (ids.isEmpty) return;
    final res = await _client.from(table).select(columns).inFilter('id', ids);
    final byId = {
      for (final p in (res as List).cast<Map<String, dynamic>>())
        p['id'] as String: p,
    };
    for (final r in rows) {
      r[embedKey] = byId[r[idKey]];
    }
  }

  @override
  Future<void> updateStatus(String bookingId, BookingStatus status) async {
    try {
      await _client
          .from('bookings')
          .update({'status': status.dbValue})
          .eq('id', bookingId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
