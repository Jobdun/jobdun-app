import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/errors/failures.dart';
import '../../domain/repositories/admin_broadcast_repository.dart';

class AdminBroadcastRepositoryImpl implements AdminBroadcastRepository {
  AdminBroadcastRepositoryImpl({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<Either<Failure, int>> broadcast({
    required String title,
    required String body,
    required String audience,
    Map<String, dynamic> data = const {},
  }) async {
    try {
      // The RPC returns the recipient count as an integer.
      final result = await _client.rpc(
        'admin_broadcast',
        params: {
          'p_title': title,
          'p_body': body,
          'p_audience': audience,
          'p_data': data,
        },
      );
      return Right((result as num).toInt());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
