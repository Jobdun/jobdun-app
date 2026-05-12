import 'package:equatable/equatable.dart';

// Matches schema enum doc_type exactly
enum DocType {
  tradeLicence,
  publicLiability,
  workersCompensation,
  whiteCard,
  photoId,
  abnCertificate,
  other,
}

extension DocTypeX on DocType {
  String get dbValue => switch (this) {
    DocType.tradeLicence => 'trade_licence',
    DocType.publicLiability => 'public_liability',
    DocType.workersCompensation => 'workers_compensation',
    DocType.whiteCard => 'white_card',
    DocType.photoId => 'photo_id',
    DocType.abnCertificate => 'abn_certificate',
    DocType.other => 'other',
  };

  String get label => switch (this) {
    DocType.tradeLicence => 'Trade Licence',
    DocType.publicLiability => 'Public Liability',
    DocType.workersCompensation => 'Workers Compensation',
    DocType.whiteCard => 'White Card',
    DocType.photoId => 'Photo ID',
    DocType.abnCertificate => 'ABN Certificate',
    DocType.other => 'Other',
  };

  static DocType fromDb(String v) {
    const map = {
      'trade_licence': DocType.tradeLicence,
      'public_liability': DocType.publicLiability,
      'workers_compensation': DocType.workersCompensation,
      'white_card': DocType.whiteCard,
      'photo_id': DocType.photoId,
      'abn_certificate': DocType.abnCertificate,
      'other': DocType.other,
    };
    return map[v] ?? DocType.other;
  }
}

// Matches schema enum verification_status
enum VerificationStatus { pending, approved, rejected, expired }

extension VerificationStatusX on VerificationStatus {
  String get dbValue => name;
  String get label => switch (this) {
    VerificationStatus.pending => 'Pending Review',
    VerificationStatus.approved => 'Approved',
    VerificationStatus.rejected => 'Rejected',
    VerificationStatus.expired => 'Expired',
  };
  static VerificationStatus fromDb(String v) =>
      VerificationStatus.values.firstWhere(
        (s) => s.dbValue == v,
        orElse: () => VerificationStatus.pending,
      );
}

class VerificationDocument extends Equatable {
  const VerificationDocument({
    required this.id,
    required this.tradeId,
    required this.docType,
    required this.filePath,
    required this.status,
    required this.submittedAt,
    this.state,
    this.issuer,
    this.documentNumber,
    this.issuedDate,
    this.expiryDate,
    this.rejectionReason,
    this.reviewNotes,
    this.deletedAt,
  });

  final String id;
  final String tradeId;
  final DocType docType;
  final String filePath;
  final VerificationStatus status;
  final DateTime submittedAt;
  final String? state; // AU state for state-scoped licences
  final String? issuer;
  final String? documentNumber;
  final DateTime? issuedDate;
  final DateTime? expiryDate;
  final String? rejectionReason;
  final String? reviewNotes;
  final DateTime? deletedAt;

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  @override
  List<Object?> get props => [id, tradeId, docType, status];
}
