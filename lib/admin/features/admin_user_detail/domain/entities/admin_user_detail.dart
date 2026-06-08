import 'package:equatable/equatable.dart';

import 'admin_builder_profile.dart';
import 'admin_trade_profile.dart';
import 'admin_verification_summary.dart';

class AdminUserDetail extends Equatable {
  const AdminUserDetail({
    required this.id,
    required this.displayName,
    required this.role,
    required this.createdAt,
    this.userStatus = 'active',
    this.avatarUrl,
    this.phone,
    this.phoneVerifiedAt,
    this.onboardingCompletedAt,
    this.updatedAt,
    this.deletedAt,
    this.licenceUrl,
    this.builder,
    this.trade,
    this.verifications = const [],
  });

  final String id;
  final String displayName;
  final String role; // 'builder' | 'trade' | 'admin' | 'unknown'
  final DateTime createdAt;
  final String userStatus; // active | suspended | banned (#21a moderation)
  final String? avatarUrl;
  final String? phone;
  final DateTime? phoneVerifiedAt;
  final DateTime? onboardingCompletedAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String? licenceUrl;
  final AdminBuilderProfile? builder;
  final AdminTradeProfile? trade;
  final List<AdminVerificationSummary> verifications;

  bool get isDeleted => deletedAt != null;

  @override
  List<Object?> get props => [
    id,
    displayName,
    role,
    createdAt,
    userStatus,
    avatarUrl,
    phone,
    phoneVerifiedAt,
    onboardingCompletedAt,
    updatedAt,
    deletedAt,
    licenceUrl,
    builder,
    trade,
    verifications,
  ];
}
