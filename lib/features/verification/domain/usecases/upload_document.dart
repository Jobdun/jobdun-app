import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/verification_document.dart';
import '../repositories/verification_repository.dart';

class UploadDocument {
  const UploadDocument(this._repository);
  final VerificationRepository _repository;

  Future<Either<Failure, VerificationDocument>> call({
    required String userId,
    required DocumentType documentType,
    required File file,
    DateTime? expiresAt,
  }) =>
      _repository.uploadDocument(
        userId: userId,
        documentType: documentType,
        file: file,
        expiresAt: expiresAt,
      );
}
