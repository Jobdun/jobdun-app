import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';

class UserModel extends AppUser {
  const UserModel({
    required super.id,
    required super.email,
    required super.role,
    super.fullName,
    super.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Role may come from JWT claim 'user_role' OR from a joined user_roles row.
    final roleStr =
        json['user_role'] as String? ?? json['role'] as String? ?? 'trade';
    final role = UserRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => UserRole.trade,
    );
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      role: role,
      fullName: json['display_name'] as String? ?? json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'display_name': fullName,
    'avatar_url': avatarUrl,
  };
}
