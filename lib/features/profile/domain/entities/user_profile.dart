import 'package:equatable/equatable.dart';

// Base profile — matches public.profiles table.
// Role is NOT stored here — it comes from the JWT claim via authControllerProvider.
class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    this.displayName,
    this.email,
    this.phone,
    this.phoneVerifiedAt,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayName;
  final String? email;
  final String? phone;
  // Set when the phone-verify OTP flow confirms the number. Drives the
  // phone_verified slot in profile_completeness — NULL = unverified.
  final DateTime? phoneVerifiedAt;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPhoneVerified => phoneVerifiedAt != null;

  @override
  List<Object?> get props => [
    id,
    displayName,
    email,
    phone,
    phoneVerifiedAt,
    avatarUrl,
  ];
}
