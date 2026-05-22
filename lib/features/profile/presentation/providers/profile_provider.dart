import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/models/builder_profile_model.dart';
import '../../data/models/trade_profile_model.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/builder_profile.dart';
import '../../domain/entities/trade_profile.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/get_profile.dart';
import '../../domain/usecases/update_profile.dart';
import '../../domain/usecases/upload_avatar.dart';

// ── Data layer providers (public so tests can override) ───────────────────────
final profileDatasourceProvider = Provider<ProfileRemoteDataSource>(
  (ref) => ProfileRemoteDataSourceImpl(SupabaseConfig.client),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ref.read(profileDatasourceProvider)),
);

// ── Use cases ─────────────────────────────────────────────────────────────────
// Only wraps the use cases that exist in domain/usecases/. Methods without a
// matching use case (upsert builder/trade, avatar remove, portfolio, licence)
// call the repository directly — see CLAUDE.md → Engineering Standards.
final getProfileUseCaseProvider = Provider(
  (ref) => GetProfile(ref.read(profileRepositoryProvider)),
);

final updateProfileUseCaseProvider = Provider(
  (ref) => UpdateProfile(ref.read(profileRepositoryProvider)),
);

final uploadAvatarUseCaseProvider = Provider(
  (ref) => UploadAvatar(ref.read(profileRepositoryProvider)),
);

// ── Controller ────────────────────────────────────────────────────────────────
final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(ProfileController.new);

class ProfileController extends Notifier<ProfileState> {
  late ProfileRepository _repo;

  @override
  ProfileState build() {
    _repo = ref.read(profileRepositoryProvider);
    return const ProfileState();
  }

  Future<void> loadProfile() async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);

    final profileResult = await ref
        .read(getProfileUseCaseProvider)
        .call(userId);
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

  // Partial upsert from /profile/edit form values. Routes through the repo
  // upsert methods (not direct Supabase) so the data-layer contract stays the
  // single source of truth — see audit fix in docs/STATE_MANAGEMENT_AUDIT.md.
  Future<bool> saveProfile({
    required UserRole role,
    required String displayName,
    required String suburb,
    required String? auState,
    required String? postcode,
    required String? about,
    // Place-picker extras — set when the user picks via JPlaceField (Phase 3+).
    // Null on legacy 3-field submissions; toJson() emits them only when set
    // so writes don't fail pre-migration.
    String? formattedAddress,
    String? placeId,
    double? latitude,
    double? longitude,
    // Builder-only
    String? companyName,
    String? abn,
    String? contactName,
    String? contactPhone,
    int? yearsInBusiness,
    String? website,
    // Trade-only
    String? fullName,
    String? primaryTrade,
    String? tradeOther,
    int? yearsExperience,
    double? hourlyRateMin,
    double? hourlyRateMax,
    bool? hourlyRateVisible,
  }) async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return false;

    state = state.copyWith(isLoading: true, error: null);

    String? nullIfBlank(String? s) =>
        (s == null || s.trim().isEmpty) ? null : s.trim();

    try {
      // Update display_name on the shared profile row first. Construct a
      // UserProfileModel directly (no entity-level copyWith yet) so the
      // data-source cast in updateProfile() lands on the right type.
      final existingProfile = state.profile;
      if (existingProfile != null) {
        final updated = UserProfileModel(
          id: existingProfile.id,
          displayName: displayName.trim(),
          email: existingProfile.email,
          phone: existingProfile.phone,
          phoneVerifiedAt: existingProfile.phoneVerifiedAt,
          avatarUrl: existingProfile.avatarUrl,
          createdAt: existingProfile.createdAt,
          updatedAt: existingProfile.updatedAt,
        );
        final r = await ref.read(updateProfileUseCaseProvider).call(updated);
        r.fold((f) => throw Exception(f.message), (_) {});
      }

      if (role == UserRole.builder) {
        final existing = state.builderProfile;
        final upserted = BuilderProfileModel(
          id: userId,
          companyName: companyName?.trim() ?? existing?.companyName ?? '',
          abn: nullIfBlank(abn),
          contactName: nullIfBlank(contactName),
          contactPhone: nullIfBlank(contactPhone),
          about: nullIfBlank(about),
          website: nullIfBlank(website),
          yearsInBusiness: yearsInBusiness,
          serviceSuburb: nullIfBlank(suburb),
          serviceState: nullIfBlank(auState),
          servicePostcode: nullIfBlank(postcode),
          serviceFormattedAddress: nullIfBlank(formattedAddress),
          servicePlaceId: nullIfBlank(placeId),
          serviceLatitude: latitude,
          serviceLongitude: longitude,
        );
        final r = await _repo.upsertBuilderProfile(upserted);
        r.fold((f) => throw Exception(f.message), (_) {});
      } else if (role == UserRole.trade) {
        final existing = state.tradeProfile;
        final upserted = TradeProfileModel(
          id: userId,
          fullName: fullName?.trim() ?? existing?.fullName ?? '',
          primaryTrade: primaryTrade ?? existing?.primaryTrade ?? '',
          tradeOther: primaryTrade == 'other' ? nullIfBlank(tradeOther) : null,
          baseSuburb: nullIfBlank(suburb),
          baseState: nullIfBlank(auState),
          basePostcode: nullIfBlank(postcode),
          baseFormattedAddress: nullIfBlank(formattedAddress),
          basePlaceId: nullIfBlank(placeId),
          baseLatitude: latitude,
          baseLongitude: longitude,
          about: nullIfBlank(about),
          yearsExperience: yearsExperience,
          hourlyRateMin: hourlyRateMin,
          hourlyRateMax: hourlyRateMax,
          hourlyRateVisible:
              hourlyRateVisible ?? existing?.hourlyRateVisible ?? true,
        );
        final r = await _repo.upsertTradeProfile(upserted);
        r.fold((f) => throw Exception(f.message), (_) {});
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

  Future<bool> uploadAvatar(File file) async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return false;

    state = state.copyWith(isUploadingAvatar: true, error: null);
    final result = await ref
        .read(uploadAvatarUseCaseProvider)
        .call(userId, file);
    return result.fold(
      (f) {
        state = state.copyWith(isUploadingAvatar: false, error: f.message);
        return false;
      },
      (_) async {
        await loadProfile();
        state = state.copyWith(isUploadingAvatar: false);
        return true;
      },
    );
  }

  Future<bool> removeAvatar() async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return false;

    state = state.copyWith(isUploadingAvatar: true, error: null);
    final result = await _repo.removeAvatar(userId);
    return result.fold(
      (f) {
        state = state.copyWith(isUploadingAvatar: false, error: f.message);
        return false;
      },
      (_) async {
        await loadProfile();
        state = state.copyWith(isUploadingAvatar: false);
        return true;
      },
    );
  }

  Future<bool> uploadTradeLicence(File file) async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return false;
    state = state.copyWith(isUploadingLicence: true, error: null);
    final result = await _repo.uploadTradeLicence(userId, file);
    return result.fold(
      (f) {
        state = state.copyWith(isUploadingLicence: false, error: f.message);
        return false;
      },
      (_) async {
        await loadProfile();
        state = state.copyWith(isUploadingLicence: false);
        return true;
      },
    );
  }

  Future<bool> addPortfolioImage(File file) async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return false;
    state = state.copyWith(isUploadingPortfolio: true, error: null);
    final result = await _repo.addPortfolioImage(userId, file);
    return result.fold(
      (f) {
        state = state.copyWith(isUploadingPortfolio: false, error: f.message);
        return false;
      },
      (_) async {
        await loadProfile();
        state = state.copyWith(isUploadingPortfolio: false);
        return true;
      },
    );
  }

  Future<bool> removePortfolioImage(String publicUrl) async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return false;
    state = state.copyWith(isUploadingPortfolio: true, error: null);
    final result = await _repo.removePortfolioImage(userId, publicUrl);
    return result.fold(
      (f) {
        state = state.copyWith(isUploadingPortfolio: false, error: f.message);
        return false;
      },
      (_) async {
        await loadProfile();
        state = state.copyWith(isUploadingPortfolio: false);
        return true;
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
    this.isUploadingLicence = false,
    this.isUploadingPortfolio = false,
    this.error,
  });

  final UserProfile? profile;
  final BuilderProfile? builderProfile;
  final TradeProfile? tradeProfile;
  final bool isLoading;
  final bool isUploadingAvatar;
  final bool isUploadingLicence;
  final bool isUploadingPortfolio;
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

    return 0;
  }

  ProfileState copyWith({
    UserProfile? profile,
    BuilderProfile? builderProfile,
    TradeProfile? tradeProfile,
    bool? isLoading,
    bool? isUploadingAvatar,
    bool? isUploadingLicence,
    bool? isUploadingPortfolio,
    String? error,
  }) => ProfileState(
    profile: profile ?? this.profile,
    builderProfile: builderProfile ?? this.builderProfile,
    tradeProfile: tradeProfile ?? this.tradeProfile,
    isLoading: isLoading ?? this.isLoading,
    isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
    isUploadingLicence: isUploadingLicence ?? this.isUploadingLicence,
    isUploadingPortfolio: isUploadingPortfolio ?? this.isUploadingPortfolio,
    error: error,
  );
}
