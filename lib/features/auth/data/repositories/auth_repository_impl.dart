import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._datasource);
  final AuthRemoteDataSource _datasource;

  @override
  Future<Either<Failure, AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _datasource.signIn(email: email, password: password);
      return right(user);
    } on AuthException catch (e) {
      return left(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, AppUser>> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final user = await _datasource.register(
        email: email,
        password: password,
        fullName: fullName,
      );
      if (user == null) {
        return left(
          const AuthFailure('Check your email to confirm your account.'),
        );
      }
      return right(user);
    } on AuthException catch (e) {
      return left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _datasource.signOut();
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, AppUser?>> getCurrentUser() async {
    try {
      final user = await _datasource.getCurrentUser();
      return right(user);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Stream<AppUser?> watchAuthState() => _datasource.watchAuthState();
}
