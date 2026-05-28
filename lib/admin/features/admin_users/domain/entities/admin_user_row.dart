import 'package:equatable/equatable.dart';

class AdminUserRow extends Equatable {
  const AdminUserRow({
    required this.id,
    required this.displayName,
    required this.role,
    required this.isVerified,
    required this.createdAt,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String role; // 'builder' | 'trade' | 'admin' | 'unknown'
  final bool isVerified;
  final DateTime createdAt;
  final String? avatarUrl;

  @override
  List<Object?> get props =>
      [id, displayName, role, isVerified, createdAt, avatarUrl];
}
