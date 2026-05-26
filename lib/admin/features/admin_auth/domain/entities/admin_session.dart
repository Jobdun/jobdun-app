import 'package:equatable/equatable.dart';

/// Authenticated admin user. Only constructed when the JWT `user_role`
/// claim has been verified as `'admin'`. The presence of this value in
/// the session provider is the gate the router relies on.
class AdminSession extends Equatable {
  const AdminSession({required this.userId, required this.email});

  final String userId;
  final String email;

  @override
  List<Object?> get props => [userId, email];
}

class NotAdminException implements Exception {
  const NotAdminException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AdminSignInException implements Exception {
  const AdminSignInException(this.message);
  final String message;
  @override
  String toString() => message;
}
