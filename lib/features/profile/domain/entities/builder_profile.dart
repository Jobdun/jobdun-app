import 'package:equatable/equatable.dart';

class BuilderProfile extends Equatable {
  const BuilderProfile({
    required this.id,
    required this.companyName,
    this.businessEmail,
    this.businessPhone,
    this.businessAddress,
    this.abn,
    this.companyDescription,
    this.companyLogoUrl,
  });

  final String id;
  final String companyName;
  final String? businessEmail;
  final String? businessPhone;
  final String? businessAddress;
  final String? abn;
  final String? companyDescription;
  final String? companyLogoUrl;

  @override
  List<Object?> get props => [id, companyName, abn];
}
