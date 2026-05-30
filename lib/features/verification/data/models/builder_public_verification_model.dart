import '../../domain/entities/builder_public_verification.dart';
import '../../domain/entities/verification.dart';

class BuilderPublicVerificationModel extends BuilderPublicVerification {
  const BuilderPublicVerificationModel({
    required super.userId,
    required super.kind,
    super.verifiedLegalName,
    super.gstRegistered,
    super.licenceClass,
    super.licenceStatus,
    super.detailCapturedAt,
  });

  factory BuilderPublicVerificationModel.fromJson(Map<String, dynamic> json) {
    return BuilderPublicVerificationModel(
      userId: json['user_id'] as String,
      kind: _kindFrom(json['kind'] as String),
      verifiedLegalName: json['verified_legal_name'] as String?,
      gstRegistered: json['gst_registered'] as bool?,
      licenceClass: json['licence_class'] as String?,
      licenceStatus: json['licence_status'] as String?,
      detailCapturedAt: json['detail_captured_at'] != null
          ? DateTime.parse(json['detail_captured_at'] as String)
          : null,
    );
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
}
