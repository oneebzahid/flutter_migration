import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../domain/entities/managed_user.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_datasource.dart';

/// Bridges [UserDataSource] (throws) to [UserRepository] (`Either`).
class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._source);

  final UserDataSource _source;

  @override
  Future<Either<Failure, List<ManagedUser>>> fetchUsers() =>
      guardCall(_source.fetchUsers, fallback: 'Failed to load users');

  @override
  Future<Either<Failure, Unit>> createUser({
    required String email,
    required String password,
    required String branch,
    required List<String> permissions,
  }) => guardCall(() async {
    await _source.createUser(
      email: email,
      password: password,
      branch: branch,
      permissions: permissions,
    );
    return unit;
  }, fallback: 'Failed to create user');

  @override
  Future<Either<Failure, Unit>> updateAccess({
    required String uid,
    required String branch,
    required List<String> permissions,
  }) => guardCall(() async {
    await _source.updateAccess(
      uid: uid,
      branch: branch,
      permissions: permissions,
    );
    return unit;
  }, fallback: 'Failed to update user');

  @override
  Future<Either<Failure, Unit>> approve({
    required String uid,
    required String branch,
    required List<String> permissions,
  }) => guardCall(() async {
    await _source.approve(uid: uid, branch: branch, permissions: permissions);
    return unit;
  }, fallback: 'Failed to approve user');

  @override
  Future<Either<Failure, Unit>> reject(String uid) => guardCall(() async {
    await _source.reject(uid);
    return unit;
  }, fallback: 'Failed to reject user');

  @override
  Future<Either<Failure, Unit>> delete(String uid) => guardCall(() async {
    await _source.delete(uid);
    return unit;
  }, fallback: 'Failed to delete user');
}
