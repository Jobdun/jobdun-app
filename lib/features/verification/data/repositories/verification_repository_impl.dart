import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/verification_document.dart';
import '../../domain/repositories/verification_repository.dart';
import '../datasources/verification_remote_datasource.dart';

class VerificationRepositoryImpl implements VerificationRepository {
  const VerificationRepositoryImpl(this._datasource);
  final VerificationRemoteDataSource _datasource;

  @override
  Future<Either<Failure, List<VerificationDocument>>> getMyDocuments(
    String userId,
  ) async {
    try {
      return right(await _datasource.getMyDocuments(userId));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, VerificationDocument>> uploadDocument({
    required String userId,
    required DocumentType documentType,
    required File file,
    DateTime? expiresAt,
  }) async {
    try {
      return right(await _datasource.uploadDocument(
        userId: userId,
        documentType: documentType,
        file: file,
        expiresAt: expiresAt,
      ));
    } on StorageException catch (e) {
      return left(StorageFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteDocument(String documentId) async {
    try {
      await _datasource.deleteDocument(documentId);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Stream<List<VerificationDocument>> watchMyDocuments(String userId) =>
      _datasource.watchMyDocuments(userId);
}
