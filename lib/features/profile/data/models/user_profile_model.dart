import '../../domain/entities/user_profile.dart';

class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.id,
    super.displayName,
    super.email,
    super.phone,
    super.phoneVerifiedAt,
    super.avatarUrl,
    super.createdAt,
    super.updatedAt,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      UserProfileModel(
        id: json['id'] as String,
        displayName: json['display_name'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        phoneVerifiedAt: json['phone_verified_at'] != null
            ? DateTime.parse(json['phone_verified_at'] as String)
            : null,
        avatarUrl: json['avatar_url'] as String?,
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
  };

  /// Full round-trip serialization for the offline cache (Phase 2). Unlike
  /// [toJson] (a write projection), this emits every key [fromJson] reads so a
  /// cached profile rehydrates identically offline. All values JSON-encodable.
  Map<String, dynamic> toCacheMap() => {
    'id': id,
    'display_name': displayName,
    'email': email,
    'phone': phone,
    'phone_verified_at': phoneVerifiedAt?.toIso8601String(),
    'avatar_url': avatarUrl,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}
