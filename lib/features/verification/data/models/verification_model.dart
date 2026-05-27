import '../../domain/entities/verification.dart';

class VerificationModel extends Verification {
  const VerificationModel({
    required super.id,
    required super.userId,
    required super.kind,
    required super.status,
    required super.manualFallbackAllowed,
    required super.createdAt,
    required super.updatedAt,
    super.abn,
    super.abnEntityName,
    super.entityType,
    super.abnRegisteredAt,
    super.abrState,
    super.abrPostcode,
    super.licenceNumber,
    super.licenceState,
    super.licenceTradeClass,
    super.verifiedAt,
    super.expiresAt,
    super.lastCheckedAt,
    super.failureReason,
  });

  factory VerificationModel.fromJson(Map<String, dynamic> json) {
    return VerificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      kind: _kindFrom(json['kind'] as String),
      status: _statusFrom(json['status'] as String),
      manualFallbackAllowed:
          (json['manual_fallback_allowed'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      abn: json['abn'] as String?,
      abnEntityName: json['abn_entity_name'] as String?,
      entityType: json['entity_type'] as String?,
      abnRegisteredAt: _parseDate(json['abn_registered_at']),
      abrState: json['abr_state'] as String?,
      abrPostcode: json['abr_postcode'] as String?,
      licenceNumber: json['licence_number'] as String?,
      licenceState: json['licence_state'] as String?,
      licenceTradeClass: json['licence_trade_class'] as String?,
      verifiedAt: _parseDate(json['verified_at']),
      expiresAt: _parseDate(json['expires_at']),
      lastCheckedAt: _parseDate(json['last_checked_at']),
      failureReason: json['failure_reason'] as String?,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.parse(value as String);
  }

  static VerificationKind _kindFrom(String raw) {
    switch (raw) {
      case 'abn':
        return VerificationKind.abn;
      case 'licence':
        return VerificationKind.licence;
    }
    throw FormatException('Unknown verification kind: $raw');
  }

  static VerificationStatus _statusFrom(String raw) {
    switch (raw) {
      case 'pending':
        return VerificationStatus.pending;
      case 'verified':
        return VerificationStatus.verified;
      case 'failed':
        return VerificationStatus.failed;
      case 'expired':
        return VerificationStatus.expired;
      case 'suspended':
        return VerificationStatus.suspended;
      case 'manual_review':
        return VerificationStatus.manualReview;
    }
    throw FormatException('Unknown verification status: $raw');
  }
}

VerifyResult verifyResultFromJson(Map<String, dynamic> json) {
  final status = json['status'] as String?;
  switch (status) {
    case 'verified':
      return VerifyVerified(
        entityName: json['entity_name'] as String?,
        holderName: json['holder_name'] as String?,
        regulatorDisplayName: json['regulator_display_name'] as String?,
        expiresAt: json['expires_at'] != null
            ? DateTime.parse(json['expires_at'] as String)
            : null,
        gst: json['gst'] as String?,
      );
    case 'failed':
      return VerifyFailed(
        reason: (json['reason'] as String?) ?? 'unknown',
        manualFallbackAllowed:
            (json['manual_fallback_allowed'] as bool?) ?? false,
        detail: (json['detail'] as String?) ?? '',
        regulatorDisplayName: json['regulator_display_name'] as String?,
      );
    case 'manual_review':
      return VerifyManualReview(
        reason: (json['reason'] as String?) ?? 'manual_review',
      );
    default:
      throw FormatException('Unknown verify-* status: $status');
  }
}
