import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';

abstract class AdminBroadcastRepository {
  /// Send an announcement to [audience] via the audited `admin_broadcast` RPC.
  ///
  /// [audience] is the RPC token: `'all'`, `'builders'`, `'trades'`, or a
  /// single profile id. On success returns the recipient count.
  Future<Either<Failure, int>> broadcast({
    required String title,
    required String body,
    required String audience,
    Map<String, dynamic> data,
  });
}
