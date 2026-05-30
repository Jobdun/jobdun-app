import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/builder_public_verification.dart';
import '../entities/verification.dart';

/// Contract for the API-first verification state machine (the `verifications`
/// table + Edge Functions). The existing [VerificationRepository] is the
/// manual-upload (document) flow and remains in place as the v2 fallback path.
abstract interface class VerificationsRepository {
  Future<Either<Failure, List<Verification>>> getForUser(String userId);

  /// Minimized, register-derived projection for COUNTERPARTY display (the
  /// "Verified business" badge). Reads the `get_builder_public_verification`
  /// RPC — never the raw row. Returns 0..N verified credentials.
  Future<Either<Failure, List<BuilderPublicVerification>>>
  getPublicVerification(String userId);

  Future<Either<Failure, VerifyResult>> verifyAbn(String abn);

  Future<Either<Failure, VerifyResult>> verifyLicence({
    required String licenceNumber,
    required String state,
    required String tradeClass,
  });
}
