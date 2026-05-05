import 'dart:io';

// hide supabase's StorageException so ours from core/errors/exceptions.dart is unambiguous
import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/verification_document.dart';
import '../models/verification_document_model.dart';

abstract interface class VerificationRemoteDataSource {
  Future<List<VerificationDocumentModel>> getMyDocuments(String userId);
  Future<VerificationDocumentModel> uploadDocument({
    required String userId,
    required DocumentType documentType,
    required File file,
    DateTime? expiresAt,
  });
  Future<void> deleteDocument(String documentId);
  Stream<List<VerificationDocumentModel>> watchMyDocuments(String userId);
}

class VerificationRemoteDataSourceImpl implements VerificationRemoteDataSource {
  const VerificationRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<List<VerificationDocumentModel>> getMyDocuments(String userId) async {
    try {
      final data = await _client
          .from('verification_documents')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => VerificationDocumentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<VerificationDocumentModel> uploadDocument({
    required String userId,
    required DocumentType documentType,
    required File file,
    DateTime? expiresAt,
  }) async {
    try {
      final fileName = '${documentType.name}_${DateTime.now().millisecondsSinceEpoch}';
      final path = 'verification-documents/$userId/$fileName';
      await _client.storage.from('verification-documents').upload(path, file);

      final record = await _client
          .from('verification_documents')
          .insert({
            'user_id': userId,
            'document_type': documentType.name,
            'file_url': path,
            'status': VerificationStatus.pending.name,
            if (expiresAt != null)
              'expires_at': expiresAt.toIso8601String().split('T').first,
          })
          .select()
          .single();
      return VerificationDocumentModel.fromJson(record);
    } catch (e) {
      throw StorageException(e.toString());
    }
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    try {
      await _client
          .from('verification_documents')
          .delete()
          .eq('id', documentId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Stream<List<VerificationDocumentModel>> watchMyDocuments(String userId) {
    return _client
        .from('verification_documents')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(VerificationDocumentModel.fromJson).toList());
  }
}
