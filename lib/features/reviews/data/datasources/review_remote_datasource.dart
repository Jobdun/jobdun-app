import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/review_model.dart';

abstract interface class ReviewRemoteDataSource {
  Future<void> submitReview(ReviewModel review);
  Future<List<ReviewModel>> getReviewsForUser(String userId);
  Future<ReviewModel?> getReviewForJob({
    required String jobId,
    required String reviewerId,
  });
}

class ReviewRemoteDataSourceImpl implements ReviewRemoteDataSource {
  const ReviewRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<void> submitReview(ReviewModel review) async {
    try {
      // v2: copy the hire-time verification snapshot from the application row
      // onto the review at write time. Only happens when the reviewee is the
      // tradie on that job; trade-reviewing-builder writes a null snapshot
      // (no builder snapshot is stamped on applications today).
      Map<String, dynamic>? snapshot;
      final app = await _client
          .from('applications')
          .select('verification_snapshot_at_hire')
          .eq('job_id', review.jobId)
          .eq('trade_id', review.revieweeId)
          .maybeSingle();
      final raw = app?['verification_snapshot_at_hire'];
      if (raw is Map<String, dynamic>) snapshot = raw;

      final payload = review.toJson();
      if (snapshot != null) {
        payload['reviewee_verification_snapshot'] = snapshot;
      }
      await _client.from('reviews').insert(payload);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<ReviewModel>> getReviewsForUser(String userId) async {
    try {
      final data = await _client
          .from('reviews')
          .select()
          .eq('reviewee_id', userId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ReviewModel?> getReviewForJob({
    required String jobId,
    required String reviewerId,
  }) async {
    try {
      final data = await _client
          .from('reviews')
          .select()
          .eq('job_id', jobId)
          .eq('reviewer_id', reviewerId)
          .maybeSingle();
      if (data == null) return null;
      return ReviewModel.fromJson(data);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
