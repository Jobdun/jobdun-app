import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../../data/repositories/admin_broadcast_repository_impl.dart';
import '../../domain/repositories/admin_broadcast_repository.dart';

/// Top-level public so tests can override the data seam via
/// `ProviderScope(overrides: [...])`.
final adminBroadcastRepositoryProvider = Provider<AdminBroadcastRepository>(
  (ref) => AdminBroadcastRepositoryImpl(),
);

/// Send action. Thin wrapper over the audited `admin_broadcast` RPC; the
/// compose page reads it, shows loading, and surfaces the recipient count.
final adminBroadcastProvider = Provider(AdminBroadcast.new);

class AdminBroadcast {
  AdminBroadcast(this._ref);
  final Ref _ref;

  Future<Either<Failure, int>> send({
    required String title,
    required String body,
    required String audience,
    Map<String, dynamic> data = const {},
  }) {
    return _ref
        .read(adminBroadcastRepositoryProvider)
        .broadcast(title: title, body: body, audience: audience, data: data);
  }
}
