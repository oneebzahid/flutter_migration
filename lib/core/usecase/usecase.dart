import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../error/failures.dart';

/// Contract every domain use case implements.
///
/// [ResultType] is the successful value, [Params] the input. Use [NoParams]
/// when there is none. One class per user action - never a catch-all.
abstract class UseCase<ResultType, Params> {
  Future<Either<Failure, ResultType>> call(Params params);
}

class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
