import 'package:equatable/equatable.dart';

/// Immutable snapshot of the reviewee's verification state at the time the
/// review-related hire happened. Copied from `applications.verification_snapshot_at_hire`
/// onto the review at write time so it survives later verification changes.
class VerificationSnapshot extends Equatable {
  const VerificationSnapshot({
    this.abn,
    this.licence,
    this.licenceState,
    this.asOf,
  });

  /// Status of the ABN credential at hire: 'verified' / 'none' / 'expired' / etc.
  final String? abn;

  /// Status of the licence credential at hire: 'verified' / 'none' / 'expired'
  /// / 'cancelled' / 'suspended'.
  final String? licence;

  /// e.g. 'NSW' — used in copy ("NSW Electrical Licence").
  final String? licenceState;

  final DateTime? asOf;

  factory VerificationSnapshot.fromJson(Map<String, dynamic> json) =>
      VerificationSnapshot(
        abn: json['abn'] as String?,
        licence: json['licence'] as String?,
        licenceState: json['licence_state'] as String?,
        asOf: json['as_of'] != null
            ? DateTime.parse(json['as_of'] as String)
            : null,
      );

  bool get hadAbn => abn == 'verified';
  bool get hadLicence => licence == 'verified';
  bool get hadAny => hadAbn || hadLicence;

  @override
  List<Object?> get props => [abn, licence, licenceState, asOf];
}

class Review extends Equatable {
  const Review({
    required this.id,
    required this.jobId,
    required this.reviewerId,
    required this.revieweeId,
    required this.rating,
    required this.createdAt,
    this.comment,
    this.verificationSnapshot,
  }) : assert(rating >= 1 && rating <= 5);

  final String id;
  final String jobId;
  final String reviewerId;
  final String revieweeId;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final VerificationSnapshot? verificationSnapshot;

  @override
  List<Object?> get props => [
    id,
    jobId,
    reviewerId,
    revieweeId,
    rating,
    verificationSnapshot,
  ];
}
