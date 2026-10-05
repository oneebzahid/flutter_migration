import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/guard.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';

/// Bridges [AuthDataSource] (throws) to [AuthRepository] (`Either`).
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._source);

  final AuthDataSource _source;

  @override
  Future<Either<Failure, AuthUser>> signIn({
    required String email,
    required String password,
  }) => guardCall(
    () => _source.signIn(email: email, password: password),
    fallback: 'Something went wrong. Please try again.',
  );

  @override
  Future<Either<Failure, Unit>> signOut() => guardCall(() async {
    await _source.signOut();
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> sendPasswordReset(String email) =>
      guardCall(() async {
        await _source.sendPasswordReset(email);
        return unit;
      }, fallback: 'Failed to send reset email. Try again.');
}
