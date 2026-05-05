import 'package:equatable/equatable.dart';

enum DocumentType { licence, insurance, identity }

enum VerificationStatus { pending, approved, rejected }

extension VerificationStatusX on VerificationStatus {
  String get label => switch (this) {
    VerificationStatus.pending => 'Pending Review',
    VerificationStatus.approved => 'Approved',
    VerificationStatus.rejected => 'Rejected',
  };
}

class VerificationDocument extends Equatable {
  const VerificationDocument({
    required this.id,
    required this.userId,
    required this.documentType,
    required this.fileUrl,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
    this.expiresAt,
  });

  final String id;
  final String userId;
  final DocumentType documentType;
  final String fileUrl;
  final VerificationStatus status;
  final String? rejectionReason;
  final DateTime? expiresAt;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, userId, documentType, status];
}
