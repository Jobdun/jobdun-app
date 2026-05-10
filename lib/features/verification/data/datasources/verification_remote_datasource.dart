import 'dart:io';

// hide supabase's StorageException so ours from core/errors/exceptions.dart is unambiguous
import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/verification_document.dart';
import '../models/verification_document_model.dart';

abstract interface class VerificationRemoteDataSource {
  Future<List<VerificationDocumentModel>> getMyDocuments(String tradeId);
  Future<VerificationDocumentModel> uploadDocument({
    required String tradeId,
    required DocType docType,
    required File file,
    String? state,
    String? issuer,
    String? documentNumber,
    DateTime? issuedDate,
    DateTime? expiryDate,
  });
  Future<void> softDeleteDocument(String documentId);
  Stream<List<VerificationDocumentModel>> watchMyDocuments(String tradeId);
}

class VerificationRemoteDataSourceImpl implements VerificationRemoteDataSource {
  const VerificationRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  static const _bucket = 'private-docs';

  @override
  Future<List<VerificationDocumentModel>> getMyDocuments(String tradeId) async {
    try {
      final data = await _client
          .from('verification_documents')
          .select()
          .eq('trade_id', tradeId)
          .isFilter('deleted_at', null)
          .order('submitted_at', ascending: false);
      return (data as List)
          .map((e) => VerificationDocumentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<VerificationDocumentModel> uploadDocument({
    required String tradeId,
    required DocType docType,
    required File file,
    String? state,
    String? issuer,
    String? documentNumber,
    DateTime? issuedDate,
    DateTime? expiryDate,
  }) async {
    try {
      final ext = file.path.split('.').last;
      final fileName = '${docType.dbValue}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      // Path must start with trade_id to satisfy RLS: (storage.foldername(name))[1] = auth.uid()
      final path = '$tradeId/verification/${docType.dbValue}/$fileName';
      final fileBytes = await file.readAsBytes();

      await _client.storage.from(_bucket).uploadBinary(
        path,
        fileBytes,
        fileOptions: FileOptions(
          contentType: _mimeFromExt(ext),
          upsert: false,
        ),
      );

      final record = await _client
          .from('verification_documents')
          .insert({
            'trade_id': tradeId,
            'doc_type': docType.dbValue,
            'file_path': path,
            'status': VerificationStatus.pending.dbValue,
            // ignore: use_null_aware_elements
            if (state != null) 'state': state,
            // ignore: use_null_aware_elements
            if (issuer != null) 'issuer': issuer,
            // ignore: use_null_aware_elements
            if (documentNumber != null) 'document_number': documentNumber,
            if (issuedDate != null) 'issued_date': issuedDate.toIso8601String().split('T').first,
            if (expiryDate != null) 'expiry_date': expiryDate.toIso8601String().split('T').first,
          })
          .select()
          .single();
      return VerificationDocumentModel.fromJson(record);
    } catch (e) {
      throw StorageException(e.toString());
    }
  }

  // Soft delete — schema requires deleted_at, never hard delete verification docs.
  @override
  Future<void> softDeleteDocument(String documentId) async {
    try {
      await _client
          .from('verification_documents')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', documentId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Stream<List<VerificationDocumentModel>> watchMyDocuments(String tradeId) {
    return _client
        .from('verification_documents')
        .stream(primaryKey: ['id'])
        .eq('trade_id', tradeId)
        .order('submitted_at', ascending: false)
        .map((rows) => rows
            .where((r) => r['deleted_at'] == null)
            .map(VerificationDocumentModel.fromJson)
            .toList());
  }

  static String _mimeFromExt(String ext) => switch (ext.toLowerCase()) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
}
