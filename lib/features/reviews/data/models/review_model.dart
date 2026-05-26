import '../../domain/entities/review.dart';

class ReviewModel extends Review {
  const ReviewModel({
    required super.id,
    required super.jobId,
    required super.reviewerId,
    required super.revieweeId,
    required super.rating,
    required super.createdAt,
    super.comment,
    super.verificationSnapshot,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final snap = json['reviewee_verification_snapshot'];
    return ReviewModel(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      reviewerId: json['reviewer_id'] as String,
      revieweeId: json['reviewee_id'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      verificationSnapshot: snap is Map<String, dynamic>
          ? VerificationSnapshot.fromJson(snap)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'reviewer_id': reviewerId,
    'reviewee_id': revieweeId,
    'rating': rating,
    'comment': comment,
  };
}
