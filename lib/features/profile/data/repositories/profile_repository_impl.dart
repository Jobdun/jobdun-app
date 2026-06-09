import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/cache/cache_store.dart';
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
  const ProfileRepositoryImpl(this._datasource, this._cache);
  final ProfileRemoteDataSource _datasource;
  final CacheStore _cache;

  // Bump when a profile model's cache shape changes (docs/CACHING §3.3).
  static const _cacheVersion = 1;
  String _profileKey(String userId) => 'profile:$userId';
  String _builderProfileKey(String userId) => 'builder_profile:$userId';
  String _tradeProfileKey(String userId) => 'trade_profile:$userId';

  @override
  Future<Either<Failure, UserProfile>> getProfile(String userId) async {
    final key = _profileKey(userId);
    try {
      final profile = await _datasource.getProfile(userId);
      await _cache.write(
        key,
        profile.toCacheMap(),
        schemaVersion: _cacheVersion,
      );
      return right(profile);
    } on ServerException catch (e) {
      final cached = await _cache.read(key, schemaVersion: _cacheVersion);
      if (cached != null) {
        return right(
          UserProfileModel.fromJson(cached.payload as Map<String, dynamic>),
        );
      }
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, BuilderProfile?>> getBuilderProfile(
    String userId,
  ) async {
    final key = _builderProfileKey(userId);
    try {
      final profile = await _datasource.getBuilderProfile(userId);
      if (profile != null) {
        await _cache.write(
          key,
          profile.toCacheMap(),
          schemaVersion: _cacheVersion,
        );
      }
      return right(profile);
    } on ServerException catch (e) {
      final cached = await _cache.read(key, schemaVersion: _cacheVersion);
      if (cached != null) {
        return right(
          BuilderProfileModel.fromJson(cached.payload as Map<String, dynamic>),
        );
      }
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, TradeProfile?>> getTradeProfile(String userId) async {
    final key = _tradeProfileKey(userId);
    try {
      final profile = await _datasource.getTradeProfile(userId);
      if (profile != null) {
        await _cache.write(
          key,
          profile.toCacheMap(),
          schemaVersion: _cacheVersion,
        );
      }
      return right(profile);
    } on ServerException catch (e) {
      final cached = await _cache.read(key, schemaVersion: _cacheVersion);
      if (cached != null) {
        return right(
          TradeProfileModel.fromJson(cached.payload as Map<String, dynamic>),
        );
      }
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
  Future<Either<Failure, void>> setTradeAvailability(
    String userId,
    bool isAvailable,
  ) async {
    try {
      await _datasource.setTradeAvailability(userId, isAvailable);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> setTradeUnavailableDates(
    String userId,
    List<DateTime> dates,
  ) async {
    try {
      await _datasource.setTradeUnavailableDates(userId, dates);
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

  @override
  Future<Either<Failure, void>> removeAvatar(String userId) async {
    try {
      await _datasource.removeAvatar(userId);
      return right(null);
    } on StorageException catch (e) {
      return left(StorageFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String>> uploadTradeLicence(
    String userId,
    File file,
  ) async {
    try {
      return right(await _datasource.uploadTradeLicence(userId, file));
    } on StorageException catch (e) {
      return left(StorageFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String>> addPortfolioImage(
    String userId,
    File file,
  ) async {
    try {
      return right(await _datasource.addPortfolioImage(userId, file));
    } on StorageException catch (e) {
      return left(StorageFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> removePortfolioImage(
    String userId,
    String publicUrl,
  ) async {
    try {
      await _datasource.removePortfolioImage(userId, publicUrl);
      return right(null);
    } on StorageException catch (e) {
      return left(StorageFailure(e.message));
    }
  }
}
