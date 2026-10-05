import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/settings_repository.dart';

class GetCurrencyUseCase implements UseCase<String, NoParams> {
  GetCurrencyUseCase(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Either<Failure, String>> call(NoParams params) =>
      _repository.getCurrency();
}
