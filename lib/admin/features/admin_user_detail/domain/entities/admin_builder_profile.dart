import 'package:equatable/equatable.dart';

class AdminBuilderProfile extends Equatable {
  const AdminBuilderProfile({
    this.companyName,
    this.abn,
    this.logoUrl,
    this.description,
    this.contactName,
    this.contactPhone,
    this.about,
    this.website,
    this.yearsInBusiness,
    this.serviceSuburb,
    this.serviceState,
    this.servicePostcode,
  });

  final String? companyName;
  final String? abn;
  final String? logoUrl;
  final String? description;
  final String? contactName;
  final String? contactPhone;
  final String? about;
  final String? website;
  final int? yearsInBusiness;
  final String? serviceSuburb;
  final String? serviceState;
  final String? servicePostcode;

  @override
  List<Object?> get props => [
        companyName,
        abn,
        logoUrl,
        description,
        contactName,
        contactPhone,
        about,
        website,
        yearsInBusiness,
        serviceSuburb,
        serviceState,
        servicePostcode,
      ];
}
