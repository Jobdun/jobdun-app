import 'package:equatable/equatable.dart';

import 'verification.dart';

/// Minimized, register-derived verification projection shown to COUNTERPARTIES
/// (a trade viewing a builder, or vice-versa) — the "Verified business" trust
/// signal. Sourced from the `get_builder_public_verification` RPC, which only
/// ever returns VERIFIED credentials, so the presence of an instance means
/// verified. Never carries the raw payload, ABN/licence number, or failure
/// reasons — those stay owner/admin-only.
class BuilderPublicVerification extends Equatable {
  const BuilderPublicVerification({
    required this.userId,
    required this.kind,
    this.verifiedLegalName,
    this.gstRegistered,
    this.licenceClass,
    this.licenceStatus,
    this.detailCapturedAt,
  });

  final String userId;
  final VerificationKind kind;
  final String? verifiedLegalName;
  final bool? gstRegistered;
  final String? licenceClass;

  /// 'current' | 'expired' — derived from expiresAt at read time.
  final String? licenceStatus;

  /// The "as at" timestamp — always render alongside the badge.
  final DateTime? detailCapturedAt;

  /// The RPC only returns verified rows, so an instance is always verified.
  bool get isVerified => true;

  @override
  List<Object?> get props => [
    userId,
    kind,
    verifiedLegalName,
    gstRegistered,
    licenceClass,
    licenceStatus,
    detailCapturedAt,
  ];
}
