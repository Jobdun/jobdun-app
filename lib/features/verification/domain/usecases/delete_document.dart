import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/verification_repository.dart';

class DeleteDocument {
  const DeleteDocument(this._repository);
  final VerificationRepository _repository;

  Future<Either<Failure, void>> call(String documentId) =>
      _repository.deleteDocument(documentId);
}
