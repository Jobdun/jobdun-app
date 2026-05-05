import '../../../auth/domain/entities/user_role.dart';
import '../../domain/entities/user_profile.dart';

class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.id,
    required super.role,
    super.fullName,
    super.phone,
    super.avatarUrl,
    super.createdAt,
    super.updatedAt,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'trade';
    final role = UserRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => UserRole.trade,
    );
    return UserProfileModel(
      id: json['id'] as String,
      role: role,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'full_name': fullName,
    'phone': phone,
    'avatar_url': avatarUrl,
  };
}
