import 'package:equatable/equatable.dart';

import 'legal_document.dart';

class LegalAcceptance extends Equatable {
  const LegalAcceptance({
    required this.userId,
    required this.documentType,
    required this.documentVersion,
    required this.acceptedAt,
    this.appVersion,
  });

  final String userId;
  final LegalDocumentType documentType;
  final String documentVersion;
  final DateTime acceptedAt;
  final String? appVersion;

  @override
  List<Object?> get props => [userId, documentType, documentVersion];
}
