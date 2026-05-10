import 'package:equatable/equatable.dart';

// Base profile — matches public.profiles table.
// Role is NOT stored here — it comes from the JWT claim via authControllerProvider.
class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    this.displayName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.bio,
    this.onboardingCompletedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? displayName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final DateTime? onboardingCompletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isOnboardingComplete => onboardingCompletedAt != null;

  @override
  List<Object?> get props => [id, displayName, email, phone, avatarUrl];
}
