import 'dart:io';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/builder_profile.dart';
import '../entities/profile_patches.dart';
import '../entities/trade_profile.dart';
import '../entities/user_profile.dart';

abstract interface class ProfileRepository {
  Future<Either<Failure, UserProfile>> getProfile(String userId);
  Future<Either<Failure, BuilderProfile?>> getBuilderProfile(String userId);

  // Front-of-card storefront view of ANOTHER builder (no contact details,
  // coordinates rounded). Use for pre-relationship surfaces like /builders/:id.
  Future<Either<Failure, BuilderProfile?>> getBuilderPublicProfile(
    String userId,
  );
  Future<Either<Failure, TradeProfile?>> getTradeProfile(String userId);

  // Front-of-card storefront view of ANOTHER tradie (no licence, rate gated
  // by the tradie's own visibility flag, coordinates rounded). Use for
  // pre-relationship surfaces like /trades/:id.
  Future<Either<Failure, TradeProfile?>> getTradePublicProfile(String userId);
  // Partial updates — only columns set on the patch are written. Empty
  // patches resolve to success without touching the network.
  Future<Either<Failure, void>> patchUserProfile(
    String userId,
    UserProfilePatch patch,
  );
  Future<Either<Failure, void>> patchTradeProfile(
    String userId,
    TradeProfilePatch patch,
  );
  Future<Either<Failure, void>> patchBuilderProfile(
    String userId,
    BuilderProfilePatch patch,
  );

  // Single-column "open for work" toggle for the trade's home availability bar.
  Future<Either<Failure, void>> setTradeAvailability(
    String userId,
    bool isAvailable,
  );

  // Replaces the trade's blocked-off calendar dates (#13) with [dates].
  Future<Either<Failure, void>> setTradeUnavailableDates(
    String userId,
    List<DateTime> dates,
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

  // Uploads an apprentice resume to private-docs at
  // {uid}/resume/{epoch}.{ext} and stamps resume_path + resume_uploaded_at.
  // Replaces any existing resume, deleting the old object so the bucket
  // doesn't accumulate orphans. Returns the new storage path.
  //
  // Takes bytes, not a File: file_picker returns a null `path` on web and
  // only ever guarantees `bytes`, so bytes keeps one code path.
  Future<Either<Failure, String>> uploadResume(
    String userId,
    Uint8List bytes,
    String fileName,
  );

  // Deletes the resume object and clears both resume columns.
  Future<Either<Failure, void>> deleteResume(String userId);

  // 60-minute signed URL. Storage RLS decides whether the caller is
  // allowed: the owner always, a builder only once the apprentice has
  // applied to one of their jobs.
  Future<Either<Failure, String>> getResumeSignedUrl(String storagePath);
}
