import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/errors/failures.dart';
import '../../domain/entities/admin_builder_profile.dart';
import '../../domain/entities/admin_trade_profile.dart';
import '../../domain/entities/admin_user_detail.dart';
import '../../domain/entities/admin_verification_summary.dart';
import '../../domain/repositories/admin_user_detail_repository.dart';

class AdminUserDetailRepositoryImpl implements AdminUserDetailRepository {
  AdminUserDetailRepositoryImpl({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<Either<Failure, AdminUserDetail>> getUserDetail(String userId) async {
    try {
      // Run all five fetches in parallel. Trade fetch returns a record
      // because licence_url lives on trade_profiles (NOT profiles, despite
      // the AdminUserDetail.licenceUrl field name) and we want it surfaced
      // at the top level for the profile card.
      final profileF = _fetchProfile(userId);
      final roleF = _fetchRole(userId);
      final builderF = _fetchBuilder(userId);
      final tradeF = _fetchTrade(userId);
      final verifsF = _fetchVerifications(userId);
      await Future.wait<Object?>([
        profileF,
        roleF,
        builderF,
        tradeF,
        verifsF,
      ]);

      final profile = await profileF;
      if (profile == null) {
        return const Left(ServerFailure('Profile not found.'));
      }
      final role = (await roleF) ?? 'unknown';
      final builder = await builderF;
      final tradeResult = await tradeF;
      final verifications = await verifsF;

      DateTime? parseOpt(Object? v) =>
          v == null ? null : DateTime.parse(v as String).toLocal();

      return Right(
        AdminUserDetail(
          id: profile['id'] as String,
          displayName:
              (profile['display_name'] as String?)?.trim().isNotEmpty == true
              ? (profile['display_name'] as String).trim()
              : '${(profile['id'] as String).substring(0, 8)}…',
          role: role,
          avatarUrl: profile['avatar_url'] as String?,
          phone: profile['phone'] as String?,
          phoneVerifiedAt: parseOpt(profile['phone_verified_at']),
          // onboarding_completed_at was dropped by 20260521000001.
          onboardingCompletedAt: null,
          createdAt: DateTime.parse(profile['created_at'] as String).toLocal(),
          updatedAt: parseOpt(profile['updated_at']),
          // profiles has no deleted_at; soft-delete lives on subprofiles.
          // builder_profiles.deleted_at / trade_profiles.deleted_at can
          // surface this later if needed.
          deletedAt: null,
          licenceUrl: tradeResult.licenceUrl,
          builder: builder,
          trade: tradeResult.trade,
          verifications: verifications,
        ),
      );
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Map<String, dynamic>?> _fetchProfile(String userId) => _client
      .from('profiles')
      // NB: onboarding_completed_at, bio (and others) were dropped by
      // 20260521000001_profile_schema_cleanup.sql. Only request columns
      // that still exist on the live schema.
      .select(
        'id, display_name, avatar_url, phone, phone_verified_at, '
        'created_at, updated_at',
      )
      .eq('id', userId)
      .maybeSingle();

  Future<String?> _fetchRole(String userId) async {
    final row = await _client
        .from('user_roles')
        .select('role')
        .eq('user_id', userId)
        .maybeSingle();
    return row?['role'] as String?;
  }

  Future<AdminBuilderProfile?> _fetchBuilder(String userId) async {
    // logo_url + description were dropped by 20260521000001. Builder logos
    // now share the avatar_url field on profiles.
    final row = await _client
        .from('builder_profiles')
        .select(
          'company_name, abn, contact_name, contact_phone, about, website, '
          'years_in_business, service_suburb, service_state, service_postcode',
        )
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return AdminBuilderProfile(
      companyName: row['company_name'] as String?,
      abn: row['abn'] as String?,
      logoUrl: null,
      description: null,
      contactName: row['contact_name'] as String?,
      contactPhone: row['contact_phone'] as String?,
      about: row['about'] as String?,
      website: row['website'] as String?,
      yearsInBusiness: row['years_in_business'] as int?,
      serviceSuburb: row['service_suburb'] as String?,
      serviceState: row['service_state'] as String?,
      servicePostcode: row['service_postcode'] as String?,
    );
  }

  Future<({AdminTradeProfile? trade, String? licenceUrl})> _fetchTrade(
    String userId,
  ) async {
    // bio, hourly_rate, day_rate were dropped by 20260521000001 in favour
    // of hourly_rate_min/max. We surface min as the headline rate so the
    // admin still sees a number — day rate stays null until / unless the
    // schema brings it back.
    final row = await _client
        .from('trade_profiles')
        .select(
          'full_name, primary_trade, is_verified, portfolio_urls, '
          'hourly_rate_min, years_experience, about, '
          'base_suburb, base_state, base_postcode, licence_url',
        )
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return (trade: null, licenceUrl: null);
    double? toDouble(Object? v) => v == null
        ? null
        : (v is num ? v.toDouble() : double.tryParse(v.toString()));
    List<String> toList(Object? v) =>
        v is List ? v.map((e) => e.toString()).toList() : const [];
    return (
      trade: AdminTradeProfile(
        fullName: row['full_name'] as String?,
        primaryTrade: row['primary_trade'] as String?,
        isVerified: (row['is_verified'] as bool?) ?? false,
        bio: null,
        portfolioUrls: toList(row['portfolio_urls']),
        hourlyRate: toDouble(row['hourly_rate_min']),
        dayRate: null,
        yearsExperience: row['years_experience'] as int?,
        about: row['about'] as String?,
        baseSuburb: row['base_suburb'] as String?,
        baseState: row['base_state'] as String?,
        basePostcode: row['base_postcode'] as String?,
      ),
      licenceUrl: row['licence_url'] as String?,
    );
  }

  Future<List<AdminVerificationSummary>> _fetchVerifications(
    String userId,
  ) async {
    final rows = await _client
        .from('verifications')
        .select('kind, status, failure_reason, updated_at')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    final list = (rows as List).cast<Map<String, dynamic>>();
    // Keep latest row per kind only
    final seen = <String>{};
    final result = <AdminVerificationSummary>[];
    for (final r in list) {
      final kind = r['kind'] as String? ?? 'unknown';
      if (!seen.add(kind)) continue;
      result.add(
        AdminVerificationSummary(
          kind: kind,
          status: r['status'] as String? ?? 'unknown',
          failureReason: r['failure_reason'] as String?,
          updatedAt: r['updated_at'] == null
              ? null
              : DateTime.parse(r['updated_at'] as String).toLocal(),
        ),
      );
    }
    return result;
  }
}
