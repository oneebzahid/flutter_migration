import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/auth_user.dart';

/// Boundary to the backend. Presentation depends on this contract (through
/// use cases), so the real implementation can replace the mock without UI
/// changes. Auth problems come back as `AuthFailure` (message is user-facing).
abstract interface class AuthRepository {
  Future<Either<Failure, AuthUser>> signIn({
    required String email,
    required String password,
  });
  Future<Either<Failure, Unit>> signOut();
  Future<Either<Failure, Unit>> sendPasswordReset(String email);
}
