import 'dart:io';

// hide supabase's StorageException so ours from core/errors/exceptions.dart is unambiguous
import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;

import '../../../../core/errors/exceptions.dart';
import '../models/builder_profile_model.dart';
import '../models/trade_profile_model.dart';
import '../models/user_profile_model.dart';

abstract interface class ProfileRemoteDataSource {
  Future<UserProfileModel> getProfile(String userId);
  Future<BuilderProfileModel?> getBuilderProfile(String userId);
  Future<TradeProfileModel?> getTradeProfile(String userId);
  Future<void> updateProfile(UserProfileModel profile);
  Future<void> upsertBuilderProfile(BuilderProfileModel profile);
  Future<void> upsertTradeProfile(TradeProfileModel profile);
  Future<String> uploadAvatar(String userId, File file);
  Future<void> removeAvatar(String userId);
  Future<String> uploadTradeLicence(String userId, File file);
  Future<String> addPortfolioImage(String userId, File file);
  Future<void> removePortfolioImage(String userId, String publicUrl);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  const ProfileRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  static const _bucket = 'public-media';
  static const _privateBucket = 'private-docs';

  @override
  Future<UserProfileModel> getProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select(
            'id, display_name, phone, phone_verified_at, avatar_url, bio, onboarding_completed_at, created_at, updated_at',
          )
          .eq('id', userId)
          .single();
      return UserProfileModel.fromJson(data);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<BuilderProfileModel?> getBuilderProfile(String userId) async {
    try {
      final data = await _client
          .from('builder_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return null;
      return BuilderProfileModel.fromJson(data);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<TradeProfileModel?> getTradeProfile(String userId) async {
    try {
      final data = await _client
          .from('trade_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return null;
      return TradeProfileModel.fromJson(data);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updateProfile(UserProfileModel profile) async {
    try {
      await _client
          .from('profiles')
          .update(profile.toJson())
          .eq('id', profile.id);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> upsertBuilderProfile(BuilderProfileModel profile) async {
    try {
      await _client.from('builder_profiles').upsert(profile.toJson());
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> upsertTradeProfile(TradeProfileModel profile) async {
    try {
      await _client.from('trade_profiles').upsert(profile.toJson());
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<String> uploadAvatar(String userId, File file) async {
    try {
      // Path: public-media/{userId}/avatar.jpg — RLS requires first segment = auth.uid()
      const fileName = 'avatar.jpg';
      final path = '$userId/$fileName';
      final bytes = await file.readAsBytes();
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      // Cache-bust the same path-on-upsert by stamping the public URL. Without
      // a query suffix CachedNetworkImage holds the old bytes after a re-upload.
      final publicUrl = _client.storage.from(_bucket).getPublicUrl(path);
      final stampedUrl =
          '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      // Persist on profiles so /profile + /home avatar surfaces survive reload.
      await _client
          .from('profiles')
          .update({'avatar_url': stampedUrl})
          .eq('id', userId);
      return stampedUrl;
    } catch (e) {
      throw StorageException(e.toString());
    }
  }

  @override
  Future<void> removeAvatar(String userId) async {
    try {
      // Null the column first so the UI updates even if storage cleanup fails
      // (orphan files are cheap; broken avatars on profile aren't).
      await _client
          .from('profiles')
          .update({'avatar_url': null})
          .eq('id', userId);
      await _client.storage.from(_bucket).remove(['$userId/avatar.jpg']);
    } catch (e) {
      throw StorageException(e.toString());
    }
  }

  // Licences live in the private-docs bucket so the file itself can't be
  // hot-linked. Only the owner (and eventually an admin/edge-function with
  // service_role) can read; everyone else only sees the boolean "has a
  // licence on file" via trade_profiles.licence_url IS NOT NULL.
  //
  // We also write a verification_documents row (status = 'pending') so the
  // admin queue picks it up for review without the app needing a second call.
  @override
  Future<String> uploadTradeLicence(String userId, File file) async {
    try {
      final ext = _extOf(file.path, fallback: 'pdf');
      final contentType = _contentTypeFor(ext);
      final path = '$userId/trade_licence.$ext';
      final bytes = await file.readAsBytes();
      await _client.storage
          .from(_privateBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      await _client
          .from('trade_profiles')
          .update({'licence_url': path})
          .eq('id', userId);

      // Idempotent: a re-upload should re-open the review, not stack rows.
      // Delete any existing pending row for this user+type before inserting.
      await _client
          .from('verification_documents')
          .delete()
          .eq('trade_id', userId)
          .eq('type', 'trade_licence')
          .inFilter('status', ['pending', 'rejected']);
      await _client.from('verification_documents').insert({
        'trade_id': userId,
        'type': 'trade_licence',
        'url': path,
        'status': 'pending',
      });

      return path;
    } catch (e) {
      throw StorageException(e.toString());
    }
  }

  // Portfolio images use public-media so other users viewing a trade's
  // profile can see them without per-image signed-URL minting. Filenames
  // are content-hashed to dodge collisions on multi-add.
  @override
  Future<String> addPortfolioImage(String userId, File file) async {
    try {
      final ext = _extOf(file.path, fallback: 'jpg');
      final contentType = _contentTypeFor(ext);
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final path = '$userId/portfolio/$stamp.$ext';
      final bytes = await file.readAsBytes();
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
      final publicUrl = _client.storage.from(_bucket).getPublicUrl(path);

      // Atomic append via array_append — avoids a read-modify-write race if
      // the user multi-picks.
      await _client.rpc(
        'append_portfolio_url',
        params: {'user_id': userId, 'new_url': publicUrl},
      );

      return publicUrl;
    } catch (e) {
      throw StorageException(e.toString());
    }
  }

  @override
  Future<void> removePortfolioImage(String userId, String publicUrl) async {
    try {
      // Derive the storage path from the public URL — public URLs are of
      // the form `<base>/storage/v1/object/public/<bucket>/<path>`.
      final marker = '/$_bucket/';
      final idx = publicUrl.indexOf(marker);
      if (idx > -1) {
        final path = publicUrl.substring(idx + marker.length);
        await _client.storage.from(_bucket).remove([path]);
      }

      await _client.rpc(
        'remove_portfolio_url',
        params: {'user_id': userId, 'target_url': publicUrl},
      );
    } catch (e) {
      throw StorageException(e.toString());
    }
  }

  static String _extOf(String path, {required String fallback}) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return fallback;
    return path.substring(dot + 1).toLowerCase();
  }

  static String _contentTypeFor(String ext) => switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    'heic' || 'heif' => 'image/heic',
    _ => 'image/jpeg',
  };
}
