import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/managed_user.dart';
import '../repositories/user_repository.dart';

class GetUsersUseCase implements UseCase<List<ManagedUser>, NoParams> {
  GetUsersUseCase(this._repository);

  final UserRepository _repository;

  @override
  Future<Either<Failure, List<ManagedUser>>> call(NoParams params) =>
      _repository.fetchUsers();
}
