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
      await _client.from('reviews').insert(review.toJson());
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
