import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/verification/domain/entities/builder_public_verification.dart';
import 'package:jobdun/features/verification/domain/entities/trade_public_credential.dart';
import 'package:jobdun/features/verification/domain/entities/verification.dart';
import 'package:jobdun/features/verification/domain/repositories/verifications_repository.dart';
import 'package:jobdun/features/verification/domain/usecases/get_builder_public_verification.dart';

class _FakeRepo implements VerificationsRepository {
  _FakeRepo(this._rows);
  final List<BuilderPublicVerification> _rows;
  String? lastUserId;

  @override
  Future<Either<Failure, List<BuilderPublicVerification>>>
  getPublicVerification(String userId) async {
    lastUserId = userId;
    return right(_rows);
  }

  @override
  Future<Either<Failure, List<TradePublicCredential>>>
  getTradePublicCredentials(String userId) async => right(const []);

  @override
  Future<Either<Failure, List<Verification>>> getForUser(String userId) async =>
      right(const []);

  @override
  Future<Either<Failure, VerifyResult>> verifyAbn(String abn) async =>
      right(const VerifyManualReview(reason: 'x'));

  @override
  Future<Either<Failure, VerifyResult>> verifyLicence({
    required String licenceNumber,
    required String state,
    required String tradeClass,
  }) async => right(const VerifyManualReview(reason: 'x'));
}

void main() {
  test(
    'GetBuilderPublicVerification delegates to repo with the userId',
    () async {
      final rows = [
        const BuilderPublicVerification(
          userId: 'u1',
          kind: VerificationKind.abn,
          verifiedLegalName: 'Acme Building Pty Ltd',
        ),
      ];
      final repo = _FakeRepo(rows);
      final usecase = GetBuilderPublicVerification(repo);

      final result = await usecase.call('u1');

      expect(repo.lastUserId, 'u1');
      expect(
        result.getOrElse((_) => const []).single.verifiedLegalName,
        'Acme Building Pty Ltd',
      );
    },
  );
}
