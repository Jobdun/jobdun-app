import 'package:equatable/equatable.dart';

class AdminTradeProfile extends Equatable {
  const AdminTradeProfile({
    this.fullName,
    this.primaryTrade,
    required this.isVerified,
    this.bio,
    this.portfolioUrls = const [],
    this.hourlyRate,
    this.dayRate,
    this.yearsExperience,
    this.about,
    this.baseSuburb,
    this.baseState,
    this.basePostcode,
  });

  final String? fullName;
  final String? primaryTrade;
  final bool isVerified;
  final String? bio;
  final List<String> portfolioUrls;
  final double? hourlyRate;
  final double? dayRate;
  final int? yearsExperience;
  final String? about;
  final String? baseSuburb;
  final String? baseState;
  final String? basePostcode;

  @override
  List<Object?> get props => [
        fullName,
        primaryTrade,
        isVerified,
        bio,
        portfolioUrls,
        hourlyRate,
        dayRate,
        yearsExperience,
        about,
        baseSuburb,
        baseState,
        basePostcode,
      ];
}
