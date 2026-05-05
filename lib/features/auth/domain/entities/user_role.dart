enum UserRole { builder, trade, admin }

extension UserRoleX on UserRole {
  String get label => switch (this) {
    UserRole.builder => 'Builder',
    UserRole.trade => 'Trade / Crew',
    UserRole.admin => 'Admin',
  };

  String get description => switch (this) {
    UserRole.builder =>
      'Post work, review applicants, and manage project progress.',
    UserRole.trade =>
      'Find work, apply quickly, and maintain verification documents.',
    UserRole.admin => '',
  };
}
