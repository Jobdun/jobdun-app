import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/verification_document.dart';

abstract interface class VerificationRepository {
  Future<Either<Failure, List<VerificationDocument>>> getMyDocuments(
    String tradeId,
  );
  Future<Either<Failure, VerificationDocument>> uploadDocument({
    required String tradeId,
    required DocType docType,
    required File file,
    String? state,
    String? issuer,
    String? documentNumber,
    DateTime? issuedDate,
    DateTime? expiryDate,
  });
  Future<Either<Failure, void>> softDeleteDocument(String documentId);
  Stream<List<VerificationDocument>> watchMyDocuments(String tradeId);
}
