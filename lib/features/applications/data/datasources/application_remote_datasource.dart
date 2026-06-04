import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/job_application.dart';
import '../models/job_application_model.dart';

abstract interface class ApplicationRemoteDataSource {
  Future<JobApplicationModel> applyToJob({
    required String jobId,
    required String tradeId,
    required String builderId,
    String? coverNote,
    double? quoteAmount,
  });
  Future<List<JobApplicationModel>> getMyApplications(String tradeId);
  Future<List<JobApplicationModel>> getApplicationsForMyJobs(String builderId);
  Future<void> updateStatus(String applicationId, ApplicationStatus status);
  Future<void> withdraw(String applicationId);
}

class ApplicationRemoteDataSourceImpl implements ApplicationRemoteDataSource {
  const ApplicationRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<JobApplicationModel> applyToJob({
    required String jobId,
    required String tradeId,
    required String builderId,
    String? coverNote,
    double? quoteAmount,
  }) async {
    try {
      // v2: stamp applied_when_verified_at when the trade has a verified
      // licence at submit time. Null means "was unverified at apply."
      final hasVerifiedLicence = await _hasVerifiedLicence(tradeId);
      final data = await _client
          .from('applications')
          .insert({
            'job_id': jobId,
            'trade_id': tradeId,
            'builder_id': builderId,
            // ignore: use_null_aware_elements
            if (coverNote != null) 'cover_note': coverNote,
            // The tradie's quote, in the job's unit. Lands on the application
            // only — the protect_quote trigger keeps it tradie-owned.
            // ignore: use_null_aware_elements
            if (quoteAmount != null) 'quote_amount': quoteAmount,
            if (hasVerifiedLicence)
              'applied_when_verified_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return JobApplicationModel.fromJson(data);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Returns true when the tradie has a `kind='licence'` row in
  /// `status='verified'`. Cheap single-row check.
  Future<bool> _hasVerifiedLicence(String tradeId) async {
    try {
      final row = await _client
          .from('verifications')
          .select('id')
          .eq('user_id', tradeId)
          .eq('kind', 'licence')
          .eq('status', 'verified')
          .limit(1)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  /// Computes the hire-time verification snapshot — written into
  /// `applications.verification_snapshot_at_hire` when an application is
  /// accepted. Caller is the builder; subject is the tradie ([tradeId]).
  Future<Map<String, dynamic>> _computeSnapshot(String tradeId) async {
    final rows = await _client
        .from('verifications')
        .select('kind, status, licence_state')
        .eq('user_id', tradeId);
    String abn = 'none';
    String licence = 'none';
    String? licenceState;
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      if (r['kind'] == 'abn') abn = (r['status'] as String?) ?? 'none';
      if (r['kind'] == 'licence') {
        licence = (r['status'] as String?) ?? 'none';
        licenceState = r['licence_state'] as String?;
      }
    }
    final snapshot = <String, dynamic>{
      'abn': abn,
      'licence': licence,
      'as_of': DateTime.now().toIso8601String(),
    };
    if (licenceState != null) snapshot['licence_state'] = licenceState;
    return snapshot;
  }

  @override
  Future<List<JobApplicationModel>> getMyApplications(String tradeId) async {
    try {
      // builder_profiles can't be embedded directly (applications.builder_id
      // FKs profiles, not builder_profiles) — fetch + merge separately.
      final rows = await _client
          .from('applications')
          .select(
            '*, jobs(title, suburb, state, status, budget_amount, pricing_unit, pricing_type)',
          )
          .eq('trade_id', tradeId)
          .order('created_at', ascending: false);
      final apps = (rows as List).cast<Map<String, dynamic>>();
      if (apps.isEmpty) return const [];
      await _mergeProfiles(
        rows: apps,
        idKey: 'builder_id',
        table: 'builder_profiles',
        columns: 'id, company_name',
        embedKey: 'builder_profiles',
      );
      return apps.map(JobApplicationModel.fromJson).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<JobApplicationModel>> getApplicationsForMyJobs(
    String builderId,
  ) async {
    try {
      // trade_profiles can't be embedded directly (applications.trade_id FKs
      // profiles, not trade_profiles) — fetch + merge separately.
      final rows = await _client
          .from('applications')
          .select(
            '*, jobs(title, suburb, state, budget_amount, pricing_unit, pricing_type)',
          )
          .eq('builder_id', builderId)
          .order('created_at', ascending: false);
      final apps = (rows as List).cast<Map<String, dynamic>>();
      if (apps.isEmpty) return const [];
      await _mergeProfiles(
        rows: apps,
        idKey: 'trade_id',
        table: 'trade_profiles',
        columns: 'id, full_name, primary_trade, is_verified',
        embedKey: 'trade_profiles',
      );
      // avatar_url lives on `profiles` (not trade_profiles) — merge it under
      // `profiles` so the applicant row/detail can show the tradie's photo.
      // Degrades gracefully: if RLS hides the row, the embed is null and the
      // UI falls back to initials.
      await _mergeProfiles(
        rows: apps,
        idKey: 'trade_id',
        table: 'profiles',
        columns: 'id, avatar_url',
        embedKey: 'profiles',
      );
      return apps.map(JobApplicationModel.fromJson).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  // Fetches [table] rows for the distinct [idKey] values in [rows] and merges
  // each under [embedKey], reproducing the shape a PostgREST embed would give
  // — needed because the role tables (trade_profiles / builder_profiles) share
  // their PK with profiles rather than being FK targets of applications.
  Future<void> _mergeProfiles({
    required List<Map<String, dynamic>> rows,
    required String idKey,
    required String table,
    required String columns,
    required String embedKey,
  }) async {
    final ids = rows.map((r) => r[idKey] as String).toSet().toList();
    if (ids.isEmpty) return;
    final profiles = await _client
        .from(table)
        .select(columns)
        .inFilter('id', ids);
    final byId = {
      for (final p in (profiles as List).cast<Map<String, dynamic>>())
        p['id'] as String: p,
    };
    for (final r in rows) {
      r[embedKey] = byId[r[idKey]];
    }
  }

  @override
  Future<void> updateStatus(
    String applicationId,
    ApplicationStatus status,
  ) async {
    try {
      final payload = <String, dynamic>{
        'status': status.dbValue,
        'status_changed_at': DateTime.now().toIso8601String(),
      };
      // v2: at the moment a tradie is hired, snapshot their verification
      // state. Immutable thereafter — surfaced on the eventual review.
      if (status == ApplicationStatus.hired) {
        final row = await _client
            .from('applications')
            .select('trade_id, verification_snapshot_at_hire')
            .eq('id', applicationId)
            .maybeSingle();
        final tradeId = row?['trade_id'] as String?;
        final existing = row?['verification_snapshot_at_hire'];
        if (tradeId != null && existing == null) {
          payload['verification_snapshot_at_hire'] = await _computeSnapshot(
            tradeId,
          );
        }
      }
      await _client
          .from('applications')
          .update(payload)
          .eq('id', applicationId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> withdraw(String applicationId) async {
    try {
      await _client
          .from('applications')
          .update({
            'status': ApplicationStatus.withdrawn.dbValue,
            'status_changed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', applicationId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
