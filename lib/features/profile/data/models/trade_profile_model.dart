import '../../domain/entities/trade_profile.dart';

class TradeProfileModel extends TradeProfile {
  const TradeProfileModel({
    required super.id,
    required super.tradeCategory,
    super.businessName,
    super.skills,
    super.yearsExperience,
    super.serviceArea,
    super.availabilityStatus,
    super.bio,
    super.portfolioUrls,
  });

  factory TradeProfileModel.fromJson(Map<String, dynamic> json) =>
      TradeProfileModel(
        id: json['id'] as String,
        tradeCategory: json['trade_category'] as String? ?? '',
        businessName: json['business_name'] as String?,
        skills: (json['skills'] as List<dynamic>?)?.cast<String>() ?? [],
        yearsExperience: json['years_experience'] as int?,
        serviceArea: json['service_area'] as String?,
        availabilityStatus: json['availability_status'] as String?,
        bio: json['bio'] as String?,
        portfolioUrls:
            (json['portfolio_urls'] as List<dynamic>?)?.cast<String>() ?? [],
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'trade_category': tradeCategory,
    'business_name': businessName,
    'skills': skills,
    'years_experience': yearsExperience,
    'service_area': serviceArea,
    'availability_status': availabilityStatus,
    'bio': bio,
    'portfolio_urls': portfolioUrls,
  };
}
