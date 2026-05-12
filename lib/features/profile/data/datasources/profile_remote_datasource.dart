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
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  const ProfileRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  static const _bucket = 'public-media';

  @override
  Future<UserProfileModel> getProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select(
            'id, display_name, email, phone, avatar_url, bio, onboarding_completed_at, created_at, updated_at',
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
      return _client.storage.from(_bucket).getPublicUrl(path);
    } catch (e) {
      throw StorageException(e.toString());
    }
  }
}
