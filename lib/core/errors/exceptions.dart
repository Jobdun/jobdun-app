class ServerException implements Exception {
  const ServerException(this.message);
  final String message;
  @override
  String toString() => 'ServerException: $message';
}

class NetworkException implements Exception {
  const NetworkException([this.message = 'No internet connection.']);
  final String message;
  @override
  String toString() => 'NetworkException: $message';
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => 'AuthException: $message';
}

class StorageException implements Exception {
  const StorageException(this.message);
  final String message;
  @override
  String toString() => 'StorageException: $message';
}

class NotFoundException implements Exception {
  const NotFoundException([this.message = 'Resource not found.']);
  final String message;
  @override
  String toString() => 'NotFoundException: $message';
}
