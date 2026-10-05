import 'package:equatable/equatable.dart';

/// Base type returned on the `Left` side of every repository/use case
/// `Either<Failure, T>`. Presentation code switches on the concrete subtype
/// to decide what to show; [message] is for display, not comparison.
abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong on the server']);
}

class CacheFailure extends Failure {
  const CacheFailure([
    super.message = 'Something went wrong reading local cache',
  ]);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection']);
}

/// A business rule or input check failed (duplicate serial, overpayment,
/// transfer not allowed, ...). The message is written for the end user.
class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Invalid input']);
}
