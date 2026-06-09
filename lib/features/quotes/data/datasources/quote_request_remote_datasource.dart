import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/quote_request_model.dart';

abstract interface class QuoteRequestRemoteDataSource {
  Future<QuoteRequestModel> create({
    required String jobId,
    required String builderId,
    required String tradeId,
    String? requestNote,
  });

  // Trade inbox — requests addressed to this trade, newest first.
  Future<List<QuoteRequestModel>> getReceived(String tradeId);

  // Builder view — the request (if any) for one job+trade pair.
  Future<QuoteRequestModel?> getForJobTrade(String jobId, String tradeId);

  Future<void> respond({
    required String requestId,
    required double quoteAmount,
    String? responseNote,
  });

  Future<void> decline(String requestId);
}

class QuoteRequestRemoteDataSourceImpl implements QuoteRequestRemoteDataSource {
  const QuoteRequestRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<QuoteRequestModel> create({
    required String jobId,
    required String builderId,
    required String tradeId,
    String? requestNote,
  }) async {
    try {
      final data = await _client
          .from('quote_requests')
          .insert({
            'job_id': jobId,
            'builder_id': builderId,
            'trade_id': tradeId,
            'request_note': ?requestNote,
          })
          .select()
          .single();
      return QuoteRequestModel.fromJson(data);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<QuoteRequestModel>> getReceived(String tradeId) async {
    try {
      final rows = await _client
          .from('quote_requests')
          .select('*, jobs(title)')
          .eq('trade_id', tradeId)
          .order('created_at', ascending: false);
      final list = (rows as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) return const [];
      // builder_id FKs profiles, not builder_profiles — merge the company name
      // separately (same shape a PostgREST embed would give).
      final ids = list.map((r) => r['builder_id'] as String).toSet().toList();
      final builders = await _client
          .from('builder_profiles')
          .select('id, company_name')
          .inFilter('id', ids);
      final byId = {
        for (final b in (builders as List).cast<Map<String, dynamic>>())
          b['id'] as String: b,
      };
      for (final r in list) {
        r['builder_profiles'] = byId[r['builder_id']];
      }
      return list.map(QuoteRequestModel.fromJson).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<QuoteRequestModel?> getForJobTrade(
    String jobId,
    String tradeId,
  ) async {
    try {
      final row = await _client
          .from('quote_requests')
          .select()
          .eq('job_id', jobId)
          .eq('trade_id', tradeId)
          .maybeSingle();
      return row == null ? null : QuoteRequestModel.fromJson(row);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> respond({
    required String requestId,
    required double quoteAmount,
    String? responseNote,
  }) async {
    try {
      await _client
          .from('quote_requests')
          .update({
            'status': 'quoted',
            'quote_amount': quoteAmount,
            'response_note': ?responseNote,
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> decline(String requestId) async {
    try {
      await _client
          .from('quote_requests')
          .update({
            'status': 'declined',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
