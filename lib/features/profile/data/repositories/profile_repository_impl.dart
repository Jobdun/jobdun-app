import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/builder_profile.dart';
import '../../domain/entities/trade_profile.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';
import '../models/builder_profile_model.dart';
import '../models/trade_profile_model.dart';
import '../models/user_profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._datasource);
  final ProfileRemoteDataSource _datasource;

  @override
  Future<Either<Failure, UserProfile>> getProfile(String userId) async {
    try {
      return right(await _datasource.getProfile(userId));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, BuilderProfile?>> getBuilderProfile(
    String userId,
  ) async {
    try {
      return right(await _datasource.getBuilderProfile(userId));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, TradeProfile?>> getTradeProfile(String userId) async {
    try {
      return right(await _datasource.getTradeProfile(userId));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> updateProfile(UserProfile profile) async {
    try {
      await _datasource.updateProfile(profile as UserProfileModel);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> upsertBuilderProfile(
    BuilderProfile profile,
  ) async {
    try {
      await _datasource.upsertBuilderProfile(profile as BuilderProfileModel);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> upsertTradeProfile(TradeProfile profile) async {
    try {
      await _datasource.upsertTradeProfile(profile as TradeProfileModel);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String>> uploadAvatar(String userId, File file) async {
    try {
      return right(await _datasource.uploadAvatar(userId, file));
    } on StorageException catch (e) {
      return left(StorageFailure(e.message));
    }
  }
}
