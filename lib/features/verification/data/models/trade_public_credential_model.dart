import '../../domain/entities/trade_public_credential.dart';
import '../../domain/entities/verification_document.dart';

class TradePublicCredentialModel extends TradePublicCredential {
  const TradePublicCredentialModel({
    required super.userId,
    required super.docType,
    super.expiresAt,
    super.isExpired,
    super.capturedAt,
  });

  factory TradePublicCredentialModel.fromJson(Map<String, dynamic> json) {
    return TradePublicCredentialModel(
      userId: json['user_id'] as String,
      docType: DocTypeX.fromDb(json['doc_type'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      // 'current' | 'expired' — derived in SQL from expiry_date so the client
      // clock can't flip it. Anything other than 'expired' reads as current.
      isExpired: (json['credential_status'] as String?) == 'expired',
      capturedAt: json['captured_at'] != null
          ? DateTime.parse(json['captured_at'] as String)
          : null,
    );
  }
}
