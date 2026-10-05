import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/user_repository.dart';

class UpdateUserAccessParams extends Equatable {
  const UpdateUserAccessParams({
    required this.uid,
    required this.branch,
    required this.permissions,
  });

  final String uid;
  final String branch;
  final List<String> permissions;

  @override
  List<Object?> get props => [uid, branch, permissions];
}

class UpdateUserAccessUseCase implements UseCase<Unit, UpdateUserAccessParams> {
  UpdateUserAccessUseCase(this._repository);

  final UserRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(UpdateUserAccessParams params) =>
      _repository.updateAccess(
        uid: params.uid,
        branch: params.branch,
        permissions: params.permissions,
      );
}
