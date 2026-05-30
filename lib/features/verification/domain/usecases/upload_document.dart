import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/verification_document.dart';
import '../repositories/verification_repository.dart';

class UploadDocument {
  const UploadDocument(this._repository);
  final VerificationRepository _repository;

  Future<Either<Failure, VerificationDocument>> call({
    required String tradeId,
    required DocType docType,
    required File file,
    String? state,
    String? issuer,
    String? documentNumber,
    DateTime? issuedDate,
    DateTime? expiryDate,
    String? tradeClass,
  }) => _repository.uploadDocument(
    tradeId: tradeId,
    docType: docType,
    file: file,
    state: state,
    issuer: issuer,
    documentNumber: documentNumber,
    issuedDate: issuedDate,
    expiryDate: expiryDate,
    tradeClass: tradeClass,
  );
}
