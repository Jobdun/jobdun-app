import 'package:equatable/equatable.dart';

// Matches public.builder_profiles table
class BuilderProfile extends Equatable {
  const BuilderProfile({
    required this.id,
    required this.companyName,
    this.abn,
    this.contactName,
    this.contactPhone,
    this.about,
    this.website,
    this.yearsInBusiness,
    this.serviceSuburb,
    this.serviceState,
    this.servicePostcode,
    this.serviceFormattedAddress,
    this.servicePlaceId,
    this.serviceLatitude,
    this.serviceLongitude,
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
  final String? about;
  final String? website;
  final int? yearsInBusiness;
  final String? serviceSuburb;
  final String? serviceState;
  final String? servicePostcode;
  // Set by JPlaceField on profile-edit. Null on legacy rows where the user
  // still hand-typed suburb/state/postcode pre-MapTiler. The home map prefers
  // (serviceLatitude, serviceLongitude) when both are non-null.
  final String? serviceFormattedAddress;
  final String? servicePlaceId;
  final double? serviceLatitude;
  final double? serviceLongitude;
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
