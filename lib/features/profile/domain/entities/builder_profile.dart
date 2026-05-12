import 'package:equatable/equatable.dart';

// Matches public.builder_profiles table
class BuilderProfile extends Equatable {
  const BuilderProfile({
    required this.id,
    required this.companyName,
    this.abn,
    this.contactName,
    this.contactPhone,
    this.logoUrl,
    this.about,
    this.website,
    this.yearsInBusiness,
    this.serviceSuburb,
    this.serviceState,
    this.servicePostcode,
    this.totalJobsPosted = 0,
    this.activeJobsCount = 0,
    this.hireCount = 0,
    this.averageRating,
    this.ratingCount = 0,
  });

  final String id;
  final String companyName;
  final String? abn;
  final String? contactName;
  final String? contactPhone;
  final String? logoUrl;
  final String? about;
  final String? website;
  final int? yearsInBusiness;
  final String? serviceSuburb;
  final String? serviceState;
  final String? servicePostcode;
  final int totalJobsPosted;
  final int activeJobsCount;
  final int hireCount;
  final double? averageRating;
  final int ratingCount;

  String get displayLocation => (serviceSuburb != null && serviceState != null)
      ? '$serviceSuburb, $serviceState'
      : serviceSuburb ?? serviceState ?? '';

  @override
  List<Object?> get props => [id, companyName, abn];
}
