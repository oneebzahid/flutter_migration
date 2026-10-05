/// Thrown by the data layer (datasources) when something goes wrong talking
/// to a source (Supabase, REST, local cache, the in-memory mock, ...).
///
/// Exceptions never cross into the domain or presentation layers -
/// repositories catch these and convert them into a `Failure`
/// (see core/error/failures.dart).
class ServerException implements Exception {
  const ServerException([this.message = 'Something went wrong on the server']);
  final String message;

  @override
  String toString() => message;
}

class CacheException implements Exception {
  const CacheException([
    this.message = 'Something went wrong reading local cache',
  ]);
  final String message;

  @override
  String toString() => message;
}

class AuthException implements Exception {
  const AuthException([this.message = 'Authentication failed']);
  final String message;

  @override
  String toString() => message;
}

class NetworkException implements Exception {
  const NetworkException([this.message = 'No internet connection']);
  final String message;

  @override
  String toString() => message;
}

class ValidationException implements Exception {
  const ValidationException([this.message = 'Invalid input']);
  final String message;

  @override
  String toString() => message;
}
