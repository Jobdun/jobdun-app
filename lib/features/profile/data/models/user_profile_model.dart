import '../../domain/entities/user_profile.dart';

class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.id,
    super.displayName,
    super.email,
    super.phone,
    super.avatarUrl,
    super.bio,
    super.onboardingCompletedAt,
    super.createdAt,
    super.updatedAt,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      UserProfileModel(
        id: json['id'] as String,
        displayName: json['display_name'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
        onboardingCompletedAt: json['onboarding_completed_at'] != null
            ? DateTime.parse(json['onboarding_completed_at'] as String)
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
    'display_name': displayName,
    'phone': phone,
    'avatar_url': avatarUrl,
    'bio': bio,
  };
}
