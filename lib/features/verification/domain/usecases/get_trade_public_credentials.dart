import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/trade_public_credential.dart';
import '../repositories/verifications_repository.dart';

/// Reads the minimized counterparty projection of a tradie's APPROVED
/// supplementary credentials (White Card, public liability) — the trust badges
/// a builder sees on the hire screen. Returns 0..N approved credentials.
class GetTradePublicCredentials {
  const GetTradePublicCredentials(this._repository);
  final VerificationsRepository _repository;

  Future<Either<Failure, List<TradePublicCredential>>> call(String userId) =>
      _repository.getTradePublicCredentials(userId);
}
