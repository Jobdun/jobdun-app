import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/app_user.dart';

abstract interface class AuthRepository {
  Future<Either<Failure, AppUser>> signIn({
    required String email,
    required String password,
  });

  // NOTE: register() intentionally not on this interface. The live signup
  // path is AuthController.register in lib/features/auth/presentation/
  // providers/auth_provider.dart, which writes role into auth.users
  // raw_user_meta_data so the handle_new_user trigger can create
  // user_roles + the matching role-specific stub atomically.

  Future<Either<Failure, void>> signOut();

  Future<Either<Failure, AppUser?>> getCurrentUser();

  Stream<AppUser?> watchAuthState();
}
