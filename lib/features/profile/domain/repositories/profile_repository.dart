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

  // Single-column "open for work" toggle for the trade's home availability bar.
  Future<Either<Failure, void>> setTradeAvailability(
    String userId,
    bool isAvailable,
  );
  Future<Either<Failure, String>> uploadAvatar(String userId, File file);

  // Clears profiles.avatar_url and deletes the avatar object from public-media.
  Future<Either<Failure, void>> removeAvatar(String userId);

  // Uploads a trade-licence file (image/PDF) to the private-docs bucket,
  // writes a verification_documents row with status 'pending', and stamps
  // trade_profiles.licence_url. Returns the storage path.
  Future<Either<Failure, String>> uploadTradeLicence(String userId, File file);

  // Uploads one portfolio image to public-media and appends its URL to
  // trade_profiles.portfolio_urls. Returns the appended public URL.
  Future<Either<Failure, String>> addPortfolioImage(String userId, File file);

  // Removes a portfolio image both from storage and from the array column.
  Future<Either<Failure, void>> removePortfolioImage(
    String userId,
    String publicUrl,
  );
}
