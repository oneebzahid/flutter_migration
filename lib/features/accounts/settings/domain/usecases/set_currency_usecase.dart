import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/settings_repository.dart';

class SetCurrencyUseCase implements UseCase<Unit, String> {
  SetCurrencyUseCase(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String params) =>
      _repository.setCurrency(params);
}
