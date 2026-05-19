import '../../domain/entities/builder_profile.dart';

class BuilderProfileModel extends BuilderProfile {
  const BuilderProfileModel({
    required super.id,
    required super.companyName,
    super.abn,
    super.contactName,
    super.contactPhone,
    super.logoUrl,
    super.about,
    super.website,
    super.yearsInBusiness,
    super.serviceSuburb,
    super.serviceState,
    super.servicePostcode,
    super.totalJobsPosted,
    super.activeJobsCount,
    super.hireCount,
    super.averageRating,
    super.ratingCount,
  });

  factory BuilderProfileModel.fromJson(Map<String, dynamic> json) =>
      BuilderProfileModel(
        id: json['id'] as String,
        companyName: json['company_name'] as String? ?? '',
        abn: json['abn'] as String?,
        contactName: json['contact_name'] as String?,
        contactPhone: json['contact_phone'] as String?,
        logoUrl: json['logo_url'] as String?,
        about: json['about'] as String?,
        website: json['website'] as String?,
        yearsInBusiness: json['years_in_business'] as int?,
        serviceSuburb: json['service_suburb'] as String?,
        serviceState: json['service_state'] as String?,
        servicePostcode: json['service_postcode'] as String?,
        totalJobsPosted: json['total_jobs_posted'] as int? ?? 0,
        activeJobsCount: json['active_jobs_count'] as int? ?? 0,
        hireCount: json['hire_count'] as int? ?? 0,
        averageRating: (json['average_rating'] as num?)?.toDouble(),
        ratingCount: json['rating_count'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'company_name': companyName,
    'abn': abn,
    'contact_name': contactName,
    'contact_phone': contactPhone,
    'logo_url': logoUrl,
    'about': about,
    'website': website,
    'years_in_business': yearsInBusiness,
    'service_suburb': serviceSuburb,
    'service_state': serviceState,
    'service_postcode': servicePostcode,
  };
}
