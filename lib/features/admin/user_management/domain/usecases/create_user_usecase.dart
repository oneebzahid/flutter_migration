import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/user_repository.dart';

class CreateUserParams extends Equatable {
  const CreateUserParams({
    required this.email,
    required this.password,
    required this.branch,
    required this.permissions,
  });

  final String email;
  final String password;
  final String branch;
  final List<String> permissions;

  @override
  List<Object?> get props => [email, password, branch, permissions];
}

class CreateUserUseCase implements UseCase<Unit, CreateUserParams> {
  CreateUserUseCase(this._repository);

  final UserRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(CreateUserParams params) =>
      _repository.createUser(
        email: params.email,
        password: params.password,
        branch: params.branch,
        permissions: params.permissions,
      );
}
