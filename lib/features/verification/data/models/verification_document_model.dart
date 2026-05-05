import '../../domain/entities/verification_document.dart';

class VerificationDocumentModel extends VerificationDocument {
  const VerificationDocumentModel({
    required super.id,
    required super.userId,
    required super.documentType,
    required super.fileUrl,
    required super.status,
    required super.createdAt,
    super.rejectionReason,
    super.expiresAt,
  });

  factory VerificationDocumentModel.fromJson(Map<String, dynamic> json) {
    final typeStr = json['document_type'] as String? ?? 'licence';
    final type = DocumentType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => DocumentType.licence,
    );
    final statusStr = json['status'] as String? ?? 'pending';
    final status = VerificationStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => VerificationStatus.pending,
    );
    return VerificationDocumentModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      documentType: type,
      fileUrl: json['file_url'] as String,
      status: status,
      rejectionReason: json['rejection_reason'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'document_type': documentType.name,
    'file_url': fileUrl,
    'status': status.name,
    'expires_at': expiresAt?.toIso8601String().split('T').first,
  };
}
