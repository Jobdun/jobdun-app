import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
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
    profileResult.fold(
      (f) {
        state = state.copyWith(isLoading: false, error: f.message);
        return;
      },
      (profile) => state = state.copyWith(profile: profile),
    );

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
      return builderProfile!.abn != null && builderProfile!.serviceSuburb != null;
    }
    if (tradeProfile != null) {
      return tradeProfile!.baseSuburb != null;
    }
    return false;
  }

  ProfileState copyWith({
    UserProfile? profile,
    BuilderProfile? builderProfile,
    TradeProfile? tradeProfile,
    bool? isLoading,
    bool? isUploadingAvatar,
    String? error,
  }) =>
      ProfileState(
        profile: profile ?? this.profile,
        builderProfile: builderProfile ?? this.builderProfile,
        tradeProfile: tradeProfile ?? this.tradeProfile,
        isLoading: isLoading ?? this.isLoading,
        isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
        error: error,
      );
}
