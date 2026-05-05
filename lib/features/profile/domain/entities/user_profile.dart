import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/user_role.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.role,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final UserRole role;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [id, role, fullName, phone, avatarUrl];
}
