import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/verification.dart';
import '../models/builder_public_verification_model.dart';
import '../models/trade_public_credential_model.dart';
import '../models/verification_model.dart';

abstract interface class VerificationsRemoteDataSource {
  Future<List<VerificationModel>> getForUser(String userId);
  Future<List<BuilderPublicVerificationModel>> getPublicVerification(
    String userId,
  );
  Future<List<TradePublicCredentialModel>> getTradePublicCredentials(
    String userId,
  );
  Future<VerifyResult> invokeVerifyAbn(String abn);
  Future<VerifyResult> invokeVerifyLicence({
    required String licenceNumber,
    required String state,
    required String tradeClass,
  });
}

class VerificationsRemoteDataSourceImpl
    implements VerificationsRemoteDataSource {
  const VerificationsRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<List<VerificationModel>> getForUser(String userId) async {
    try {
      final rows = await _client
          .from('verifications')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);
      return (rows as List)
          .map((r) => VerificationModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<BuilderPublicVerificationModel>> getPublicVerification(
    String userId,
  ) async {
    try {
      final rows = await _client.rpc(
        'get_builder_public_verification',
        params: {'p_user_id': userId},
      );
      return (rows as List)
          .map(
            (r) => BuilderPublicVerificationModel.fromJson(
              r as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<TradePublicCredentialModel>> getTradePublicCredentials(
    String userId,
  ) async {
    try {
      final rows = await _client.rpc(
        'get_trade_public_credentials',
        params: {'p_user_id': userId},
      );
      return (rows as List)
          .map(
            (r) =>
                TradePublicCredentialModel.fromJson(r as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<VerifyResult> invokeVerifyAbn(String abn) =>
      _invoke('verify-abn', {'abn': abn});

  @override
  Future<VerifyResult> invokeVerifyLicence({
    required String licenceNumber,
    required String state,
    required String tradeClass,
  }) => _invoke('verify-licence', {
    'licence_number': licenceNumber,
    'state': state,
    'trade_class': tradeClass,
  });

  Future<VerifyResult> _invoke(String fn, Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(fn, body: body);
      final data = response.data;
      if (data is Map<String, dynamic>) return verifyResultFromJson(data);
      throw const ServerException(_genericVerifyCopy);
    } on ServerException {
      rethrow;
    } on FunctionException catch (e) {
      throw ServerException(_verifyErrorCopy(e));
    } catch (_) {
      // FormatException from an unexpected payload, network errors, anything
      // else — the message on ServerException is rendered verbatim by the
      // wizard steps, so it must always be human copy, never a raw body
      // (live bug S1 #2, 2026-08-18 audit).
      throw const ServerException(_genericVerifyCopy);
    }
  }

  static const _genericVerifyCopy =
      "The check didn't go through. Please try again in a moment.";

  /// Human copy for edge-function failures. Status first (auth/rate-limit
  /// have fixed meanings), then known error tokens, then generic — raw
  /// response bodies, ISO timestamps and Postgres messages stay out of the UI.
  static String _verifyErrorCopy(FunctionException e) {
    if (e.status == 401) {
      return 'Your session has expired — log in again, then retry the check.';
    }
    if (e.status == 429) {
      return 'Too many attempts — wait a few minutes and try again.';
    }
    final details = e.details;
    final token = details is Map ? details['error'] : null;
    switch (token) {
      case 'unauthenticated':
        return 'Your session has expired — log in again, then retry the '
            'check.';
      case 'rate_limited':
        return 'Too many attempts — wait a few minutes and try again.';
      default:
        return _genericVerifyCopy;
    }
  }
}
