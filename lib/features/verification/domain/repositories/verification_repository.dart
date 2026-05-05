import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/verification_document.dart';

abstract interface class VerificationRepository {
  Future<Either<Failure, List<VerificationDocument>>> getMyDocuments(
    String userId,
  );
  Future<Either<Failure, VerificationDocument>> uploadDocument({
    required String userId,
    required DocumentType documentType,
    required File file,
    DateTime? expiresAt,
  });
  Future<Either<Failure, void>> deleteDocument(String documentId);
  Stream<List<VerificationDocument>> watchMyDocuments(String userId);
}
