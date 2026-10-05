import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../entities/managed_user.dart';

/// Backend boundary for user administration. Failures carry a
/// user-presentable message.
abstract interface class UserRepository {
  /// Users with role 'user' (super admins are not listed, as in React).
  Future<Either<Failure, List<ManagedUser>>> fetchUsers();

  Future<Either<Failure, Unit>> createUser({
    required String email,
    required String password,
    required String branch,
    required List<String> permissions,
  });

  Future<Either<Failure, Unit>> updateAccess({
    required String uid,
    required String branch,
    required List<String> permissions,
  });

  Future<Either<Failure, Unit>> approve({
    required String uid,
    required String branch,
    required List<String> permissions,
  });

  Future<Either<Failure, Unit>> reject(String uid);

  Future<Either<Failure, Unit>> delete(String uid);
}
