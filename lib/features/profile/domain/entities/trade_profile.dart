import 'package:equatable/equatable.dart';

// Matches public.trade_profiles table
class TradeProfile extends Equatable {
  const TradeProfile({
    required this.id,
    required this.fullName,
    required this.primaryTrade,
    this.crewSize = 1,
    this.yearsExperience,
    this.hourlyRateMin,
    this.hourlyRateMax,
    this.hourlyRateVisible = true,
    this.serviceRadiusKm = 50,
    this.baseSuburb,
    this.baseState,
    this.basePostcode,
    this.about,
    this.isVerified = false,
    this.verifiedAt,
    this.totalApplications = 0,
    this.hireCount = 0,
    this.jobsCompleted = 0,
    this.averageRating,
    this.ratingCount = 0,
  });

  final String id;
  final String fullName;
  final String primaryTrade;
  final int crewSize;
  final int? yearsExperience;
  final double? hourlyRateMin;
  final double? hourlyRateMax;
  final bool hourlyRateVisible;
  final int serviceRadiusKm;
  final String? baseSuburb;
  final String? baseState;
  final String? basePostcode;
  final String? about;
  final bool isVerified;
  final DateTime? verifiedAt;
  final int totalApplications;
  final int hireCount;
  final int jobsCompleted;
  final double? averageRating;
  final int ratingCount;

  String get displayLocation => (baseSuburb != null && baseState != null)
      ? '$baseSuburb, $baseState'
      : baseSuburb ?? baseState ?? '';

  String get displayTrade => primaryTrade
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  List<Object?> get props => [id, fullName, primaryTrade];
}
