import 'package:equatable/equatable.dart';

class AdminVerificationSummary extends Equatable {
  const AdminVerificationSummary({
    required this.kind,
    required this.status,
    this.failureReason,
    this.updatedAt,
  });

  final String kind; // 'licence' | 'abn' | other
  final String status; // 'verified' | 'failed' | 'pending' | ...
  final String? failureReason;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [kind, status, failureReason, updatedAt];
}
