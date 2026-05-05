import 'package:equatable/equatable.dart';

class TradeProfile extends Equatable {
  const TradeProfile({
    required this.id,
    required this.tradeCategory,
    this.businessName,
    this.skills = const [],
    this.yearsExperience,
    this.serviceArea,
    this.availabilityStatus,
    this.bio,
    this.portfolioUrls = const [],
  });

  final String id;
  final String tradeCategory;
  final String? businessName;
  final List<String> skills;
  final int? yearsExperience;
  final String? serviceArea;
  final String? availabilityStatus;
  final String? bio;
  final List<String> portfolioUrls;

  @override
  List<Object?> get props => [id, tradeCategory, businessName];
}
