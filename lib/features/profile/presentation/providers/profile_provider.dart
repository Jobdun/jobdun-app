import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/builder_profile.dart';
import '../../domain/entities/trade_profile.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

final _profileDatasourceProvider = Provider<ProfileRemoteDataSource>(
  (ref) => ProfileRemoteDataSourceImpl(SupabaseConfig.client),
);

final _profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ref.read(_profileDatasourceProvider)),
);

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(ProfileController.new);

class ProfileController extends Notifier<ProfileState> {
  late ProfileRepository _repo;

  @override
  ProfileState build() {
    _repo = ref.read(_profileRepositoryProvider);
    return const ProfileState();
  }

  Future<void> loadProfile() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);

    final profileResult = await _repo.getProfile(userId);
    profileResult.fold((f) {
      state = state.copyWith(isLoading: false, error: f.message);
      return;
    }, (profile) => state = state.copyWith(profile: profile));

    if (state.error != null) return;

    final builderResult = await _repo.getBuilderProfile(userId);
    builderResult.fold(
      (_) {},
      (bp) => state = state.copyWith(builderProfile: bp),
    );

    final tradeResult = await _repo.getTradeProfile(userId);
    tradeResult.fold(
      (_) {},
      (tp) => state = state.copyWith(tradeProfile: tp, isLoading: false),
    );

    state = state.copyWith(isLoading: false);
  }

  // Partial upsert from /profile/edit form values. Only writes columns this
  // form actually exposes — keeps the touchpoint small so we don't accidentally
  // clobber fields managed elsewhere (counters, ratings, verification state).
  // Returns true on success so the page can route back / show a snackbar.
  Future<bool> saveProfile({
    required UserRole role,
    required String displayName,
    required String suburb,
    required String? auState,
    required String? about,
    // Builder-only
    String? companyName,
    String? abn,
    String? contactPhone,
    // Trade-only
    String? fullName,
    String? primaryTrade,
    String? tradeOther,
  }) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return false;

    state = state.copyWith(isLoading: true, error: null);

    String? nullIfBlank(String? s) =>
        (s == null || s.trim().isEmpty) ? null : s.trim();

    try {
      // profiles row — always.
      await SupabaseConfig.client
          .from('profiles')
          .update({'display_name': displayName.trim()})
          .eq('id', userId);

      if (role == UserRole.builder) {
        await SupabaseConfig.client.from('builder_profiles').upsert({
          'id': userId,
          if (companyName != null) 'company_name': companyName.trim(),
          'abn': nullIfBlank(abn),
          'service_suburb': nullIfBlank(suburb),
          'service_state': nullIfBlank(auState),
          'contact_phone': nullIfBlank(contactPhone),
          'about': nullIfBlank(about),
        }, onConflict: 'id');
      } else if (role == UserRole.trade) {
        await SupabaseConfig.client.from('trade_profiles').upsert({
          'id': userId,
          if (fullName != null) 'full_name': fullName.trim(),
          'primary_trade': ?primaryTrade,
          'trade_other': primaryTrade == 'other'
              ? nullIfBlank(tradeOther)
              : null,
          'base_suburb': nullIfBlank(suburb),
          'base_state': nullIfBlank(auState),
          'about': nullIfBlank(about),
        }, onConflict: 'id');
      }

      // Reload so home + profile screens get fresh values.
      await loadProfile();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e, st) {
      assert(() {
        debugPrint('[ProfileController] saveProfile: $e\n$st');
        return true;
      }());
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> uploadAvatar(File file) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;

    state = state.copyWith(isUploadingAvatar: true, error: null);
    final result = await _repo.uploadAvatar(userId, file);
    result.fold(
      (f) => state = state.copyWith(isUploadingAvatar: false, error: f.message),
      (url) {
        final current = state.profile;
        if (current != null) {
          final updated = UserProfile(
            id: current.id,
            displayName: current.displayName,
            email: current.email,
            phone: current.phone,
            avatarUrl: url,
            bio: current.bio,
            onboardingCompletedAt: current.onboardingCompletedAt,
            createdAt: current.createdAt,
            updatedAt: current.updatedAt,
          );
          state = state.copyWith(profile: updated, isUploadingAvatar: false);
        } else {
          state = state.copyWith(isUploadingAvatar: false);
        }
      },
    );
  }
}

class ProfileState {
  const ProfileState({
    this.profile,
    this.builderProfile,
    this.tradeProfile,
    this.isLoading = false,
    this.isUploadingAvatar = false,
    this.error,
  });

  final UserProfile? profile;
  final BuilderProfile? builderProfile;
  final TradeProfile? tradeProfile;
  final bool isLoading;
  final bool isUploadingAvatar;
  final String? error;

  bool get isProfileComplete {
    if (profile == null) return false;
    if (builderProfile != null) {
      return builderProfile!.abn != null &&
          builderProfile!.serviceSuburb != null;
    }
    if (tradeProfile != null) {
      return tradeProfile!.baseSuburb != null;
    }
    return false;
  }

  // Drives ProfileCompletenessBanner on /home. Field list is locked by the
  // T1 audit and mirrors supabase/migrations/20260514000001_profile_completeness.sql
  // so the client-side number matches the server view exactly:
  //
  //   builder → company_name · abn · service_suburb · phone_verified  (×25)
  //   trade   → primary_trade · licence_url · base_suburb ·
  //             phone_verified · portfolio (≥1 image)                (×20)
  //
  // Anything not in this list (about, years_experience, contact_phone, etc.)
  // is "nice to have" and intentionally not counted.
  int get profileCompletenessPct {
    if (profile == null) return 0;
    final phoneVerified = profile!.isPhoneVerified;

    if (builderProfile != null) {
      final bp = builderProfile!;
      final done =
          (bp.companyName.isNotEmpty ? 1 : 0) +
          ((bp.abn != null && bp.abn!.isNotEmpty) ? 1 : 0) +
          ((bp.serviceSuburb != null && bp.serviceSuburb!.isNotEmpty) ? 1 : 0) +
          (phoneVerified ? 1 : 0);
      return done * 25;
    }

    if (tradeProfile != null) {
      final tp = tradeProfile!;
      final done =
          (tp.primaryTrade.isNotEmpty ? 1 : 0) +
          (tp.hasLicence ? 1 : 0) +
          ((tp.baseSuburb != null && tp.baseSuburb!.isNotEmpty) ? 1 : 0) +
          (phoneVerified ? 1 : 0) +
          (tp.portfolioCount > 0 ? 1 : 0);
      return done * 20;
    }

    // Authenticated but no role-specific profile yet (role sheet pending).
    return 0;
  }

  ProfileState copyWith({
    UserProfile? profile,
    BuilderProfile? builderProfile,
    TradeProfile? tradeProfile,
    bool? isLoading,
    bool? isUploadingAvatar,
    String? error,
  }) => ProfileState(
    profile: profile ?? this.profile,
    builderProfile: builderProfile ?? this.builderProfile,
    tradeProfile: tradeProfile ?? this.tradeProfile,
    isLoading: isLoading ?? this.isLoading,
    isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
    error: error,
  );
}
