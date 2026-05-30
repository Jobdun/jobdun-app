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
    String tradeId,
  ) async {
    try {
      return right(await _datasource.getMyDocuments(tradeId));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, VerificationDocument>> uploadDocument({
    required String tradeId,
    required DocType docType,
    required File file,
    String? state,
    String? issuer,
    String? documentNumber,
    DateTime? issuedDate,
    DateTime? expiryDate,
    String? tradeClass,
  }) async {
    try {
      return right(
        await _datasource.uploadDocument(
          tradeId: tradeId,
          docType: docType,
          file: file,
          state: state,
          issuer: issuer,
          documentNumber: documentNumber,
          issuedDate: issuedDate,
          expiryDate: expiryDate,
          tradeClass: tradeClass,
        ),
      );
    } on StorageException catch (e) {
      return left(StorageFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> softDeleteDocument(String documentId) async {
    try {
      await _datasource.softDeleteDocument(documentId);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Stream<List<VerificationDocument>> watchMyDocuments(String tradeId) =>
      _datasource.watchMyDocuments(tradeId);
}
