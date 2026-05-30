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
    this.entityType,
    this.abnRegisteredAt,
    this.abrState,
    this.abrPostcode,
    this.licenceNumber,
    this.licenceState,
    this.licenceTradeClass,
    this.verifiedAt,
    this.expiresAt,
    this.lastCheckedAt,
    this.failureReason,
    this.gstRegistered,
    this.registerSource,
    this.detailCapturedAt,
  });

  final String id;
  final String userId;
  final VerificationKind kind;
  final VerificationStatus status;

  final String? abn;
  final String? abnEntityName;

  // Additional ABR-sourced facts. Stored on the verifications row (not
  // builder_profiles) because they're regulator-truth, not user-entered.
  // entityType: e.g. "Individual/Sole Trader" — replaces hardcoded "Type".
  // abnRegisteredAt: date the current AbnStatus took effect.
  // abrState + abrPostcode: registered business address (state/postcode only
  // — ABR doesn't expose street addresses).
  final String? entityType;
  final DateTime? abnRegisteredAt;
  final String? abrState;
  final String? abrPostcode;

  final String? licenceNumber;
  final String? licenceState;
  final String? licenceTradeClass;

  final DateTime? verifiedAt;
  final DateTime? expiresAt;
  final DateTime? lastCheckedAt;
  final String? failureReason;
  final bool manualFallbackAllowed;

  // Curated display projection (STEP 6). gstRegistered: ABR GST registration.
  // registerSource: which register produced this row ('ABR' / 'admin_manual' /
  // regulator code). detailCapturedAt: the "as at" timestamp — render next to
  // every verified badge so a stale snapshot never reads as a bare "Verified".
  final bool? gstRegistered;
  final String? registerSource;
  final DateTime? detailCapturedAt;

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
    entityType,
    abnRegisteredAt,
    abrState,
    abrPostcode,
    licenceNumber,
    licenceState,
    licenceTradeClass,
    verifiedAt,
    expiresAt,
    lastCheckedAt,
    failureReason,
    manualFallbackAllowed,
    gstRegistered,
    registerSource,
    detailCapturedAt,
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
