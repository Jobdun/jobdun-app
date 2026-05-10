import '../../domain/entities/verification_document.dart';

class VerificationDocumentModel extends VerificationDocument {
  const VerificationDocumentModel({
    required super.id,
    required super.tradeId,
    required super.docType,
    required super.filePath,
    required super.status,
    required super.submittedAt,
    super.state,
    super.issuer,
    super.documentNumber,
    super.issuedDate,
    super.expiryDate,
    super.rejectionReason,
    super.reviewNotes,
    super.deletedAt,
  });

  factory VerificationDocumentModel.fromJson(Map<String, dynamic> json) =>
      VerificationDocumentModel(
        id: json['id'] as String,
        tradeId: json['trade_id'] as String,
        docType: DocTypeX.fromDb(json['doc_type'] as String? ?? 'other'),
        filePath: json['file_path'] as String? ?? '',
        status: VerificationStatusX.fromDb(json['status'] as String? ?? 'pending'),
        submittedAt: json['submitted_at'] != null
            ? DateTime.parse(json['submitted_at'] as String)
            : DateTime.parse(json['created_at'] as String),
        state: json['state'] as String?,
        issuer: json['issuer'] as String?,
        documentNumber: json['document_number'] as String?,
        issuedDate: json['issued_date'] != null
            ? DateTime.parse(json['issued_date'] as String)
            : null,
        expiryDate: json['expiry_date'] != null
            ? DateTime.parse(json['expiry_date'] as String)
            : null,
        rejectionReason: json['rejection_reason'] as String?,
        reviewNotes: json['review_notes'] as String?,
        deletedAt: json['deleted_at'] != null
            ? DateTime.parse(json['deleted_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
    'trade_id': tradeId,
    'doc_type': docType.dbValue,
    'file_path': filePath,
    'status': status.dbValue,
    if (state != null) 'state': state,
    if (issuer != null) 'issuer': issuer,
    if (documentNumber != null) 'document_number': documentNumber,
    if (issuedDate != null) 'issued_date': issuedDate!.toIso8601String().split('T').first,
    if (expiryDate != null) 'expiry_date': expiryDate!.toIso8601String().split('T').first,
  };
}
