import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/builder_public_verification.dart';
import '../../domain/entities/trade_public_credential.dart';
import '../../domain/entities/verification.dart';
import '../../domain/repositories/verifications_repository.dart';
import '../datasources/verifications_remote_datasource.dart';

class VerificationsRepositoryImpl implements VerificationsRepository {
  const VerificationsRepositoryImpl(this._datasource);
  final VerificationsRemoteDataSource _datasource;

  @override
  Future<Either<Failure, List<Verification>>> getForUser(String userId) async {
    try {
      return right(await _datasource.getForUser(userId));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<BuilderPublicVerification>>>
  getPublicVerification(String userId) async {
    try {
      return right(await _datasource.getPublicVerification(userId));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<TradePublicCredential>>>
  getTradePublicCredentials(String userId) async {
    try {
      return right(await _datasource.getTradePublicCredentials(userId));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, VerifyResult>> verifyAbn(String abn) async {
    try {
      return right(await _datasource.invokeVerifyAbn(abn));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, VerifyResult>> verifyLicence({
    required String licenceNumber,
    required String state,
    required String tradeClass,
  }) async {
    try {
      return right(
        await _datasource.invokeVerifyLicence(
          licenceNumber: licenceNumber,
          state: state,
          tradeClass: tradeClass,
        ),
      );
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }
}
