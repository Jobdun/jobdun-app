import 'package:equatable/equatable.dart';

enum VerificationKind { abn, licence }

enum VerificationStatus {
  pending,
  verified,
  failed,
  expired,
  suspended,
  manualReview,
}

class Verification extends Equatable {
  const Verification({
    required this.id,
    required this.userId,
    required this.kind,
    required this.status,
    required this.manualFallbackAllowed,
    required this.createdAt,
    required this.updatedAt,
    this.abn,
    this.abnEntityName,
    this.licenceNumber,
    this.licenceState,
    this.licenceTradeClass,
    this.verifiedAt,
    this.expiresAt,
    this.lastCheckedAt,
    this.failureReason,
  });

  final String id;
  final String userId;
  final VerificationKind kind;
  final VerificationStatus status;

  final String? abn;
  final String? abnEntityName;

  final String? licenceNumber;
  final String? licenceState;
  final String? licenceTradeClass;

  final DateTime? verifiedAt;
  final DateTime? expiresAt;
  final DateTime? lastCheckedAt;
  final String? failureReason;
  final bool manualFallbackAllowed;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isVerified => status == VerificationStatus.verified;

  @override
  List<Object?> get props => [
    id,
    userId,
    kind,
    status,
    abn,
    abnEntityName,
    licenceNumber,
    licenceState,
    licenceTradeClass,
    verifiedAt,
    expiresAt,
    lastCheckedAt,
    failureReason,
    manualFallbackAllowed,
    createdAt,
    updatedAt,
  ];
}

sealed class VerifyResult extends Equatable {
  const VerifyResult();
}

class VerifyVerified extends VerifyResult {
  const VerifyVerified({
    this.entityName,
    this.holderName,
    this.regulatorDisplayName,
    this.expiresAt,
    this.gst,
  });

  final String? entityName;
  final String? holderName;
  final String? regulatorDisplayName;
  final DateTime? expiresAt;
  final String? gst;

  @override
  List<Object?> get props => [
    entityName,
    holderName,
    regulatorDisplayName,
    expiresAt,
    gst,
  ];
}

class VerifyFailed extends VerifyResult {
  const VerifyFailed({
    required this.reason,
    required this.manualFallbackAllowed,
    required this.detail,
    this.regulatorDisplayName,
  });

  final String reason;
  final bool manualFallbackAllowed;
  final String detail;
  final String? regulatorDisplayName;

  @override
  List<Object?> get props => [
    reason,
    manualFallbackAllowed,
    detail,
    regulatorDisplayName,
  ];
}

class VerifyManualReview extends VerifyResult {
  const VerifyManualReview({required this.reason});
  final String reason;

  @override
  List<Object?> get props => [reason];
}
