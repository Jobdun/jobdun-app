import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/builder_profile.dart';
import '../entities/trade_profile.dart';
import '../entities/user_profile.dart';

abstract interface class ProfileRepository {
  Future<Either<Failure, UserProfile>> getProfile(String userId);
  Future<Either<Failure, BuilderProfile?>> getBuilderProfile(String userId);
  Future<Either<Failure, TradeProfile?>> getTradeProfile(String userId);
  Future<Either<Failure, void>> updateProfile(UserProfile profile);
  Future<Either<Failure, void>> upsertBuilderProfile(BuilderProfile profile);
  Future<Either<Failure, void>> upsertTradeProfile(TradeProfile profile);
  Future<Either<Failure, String>> uploadAvatar(String userId, File file);
}
