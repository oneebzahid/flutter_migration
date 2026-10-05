import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/user_repository.dart';

class RejectUserUseCase implements UseCase<Unit, String> {
  RejectUserUseCase(this._repository);

  final UserRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String params) =>
      _repository.reject(params);
}
