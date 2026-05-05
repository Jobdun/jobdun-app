import '../../domain/entities/builder_profile.dart';

class BuilderProfileModel extends BuilderProfile {
  const BuilderProfileModel({
    required super.id,
    required super.companyName,
    super.businessEmail,
    super.businessPhone,
    super.businessAddress,
    super.abn,
    super.companyDescription,
    super.companyLogoUrl,
  });

  factory BuilderProfileModel.fromJson(Map<String, dynamic> json) =>
      BuilderProfileModel(
        id: json['id'] as String,
        companyName: json['company_name'] as String? ?? '',
        businessEmail: json['business_email'] as String?,
        businessPhone: json['business_phone'] as String?,
        businessAddress: json['business_address'] as String?,
        abn: json['abn'] as String?,
        companyDescription: json['company_description'] as String?,
        companyLogoUrl: json['company_logo_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'company_name': companyName,
    'business_email': businessEmail,
    'business_phone': businessPhone,
    'business_address': businessAddress,
    'abn': abn,
    'company_description': companyDescription,
    'company_logo_url': companyLogoUrl,
  };
}
