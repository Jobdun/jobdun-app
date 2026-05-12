import 'package:equatable/equatable.dart';

import 'user_role.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.fullName,
    this.avatarUrl,
    this.isOnboardingComplete = false,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final UserRole role;
  final bool isOnboardingComplete;

  @override
  List<Object?> get props => [
    id,
    email,
    role,
    fullName,
    avatarUrl,
    isOnboardingComplete,
  ];
}
