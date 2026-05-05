import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';

class UserModel extends AppUser {
  const UserModel({
    required super.id,
    required super.email,
    required super.role,
    super.fullName,
    super.avatarUrl,
    super.isOnboardingComplete,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'trade';
    final role = UserRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => UserRole.trade,
    );
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      role: role,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isOnboardingComplete: json['is_onboarding_complete'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'role': role.name,
    'full_name': fullName,
    'avatar_url': avatarUrl,
    'is_onboarding_complete': isOnboardingComplete,
  };
}
