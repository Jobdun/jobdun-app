import 'failures.dart';

/// Maps domain [Failure] types to user-facing strings.
/// All providers should call [ErrorMessages.from] instead of failure.toString().
abstract final class ErrorMessages {
  static String from(Failure failure) => switch (failure) {
    AuthFailure f => _authMessage(f.message),
    NetworkFailure _ => 'No internet connection. Please check your network.',
    ServerFailure _ => 'Something went wrong. Please try again.',
    StorageFailure _ => 'File upload failed. Please try again.',
    ValidationFailure f => f.message,
    NotFoundFailure _ => 'The requested item could not be found.',
    PermissionFailure _ => "You don't have permission to do that.",
  };

  static String _authMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login') ||
        lower.contains('invalid credentials')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }
    if (lower.contains('user already registered')) {
      return 'An account with this email already exists.';
    }
    if (lower.contains('password should be') ||
        lower.contains('password is too short')) {
      return 'Password must be at least 8 characters.';
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (lower.contains('network') || lower.contains('socket')) {
      return 'Network error. Please check your connection and try again.';
    }
    return raw;
  }
}
