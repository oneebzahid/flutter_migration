import 'package:dartz/dartz.dart';

import 'exceptions.dart';
import 'failures.dart';

/// The single try/catch every repository implementation uses to turn a
/// datasource call (which throws) into `Either<Failure, T>`.
///
/// [fallback] is shown when something unexpected (not one of our typed
/// exceptions) escapes the datasource.
Future<Either<Failure, T>> guardCall<T>(
  Future<T> Function() call, {
  String fallback = 'Something went wrong. Please try again.',
}) async {
  try {
    return Right(await call());
  } on ValidationException catch (e) {
    return Left(ValidationFailure(e.message));
  } on AuthException catch (e) {
    return Left(AuthFailure(e.message));
  } on NetworkException catch (e) {
    return Left(NetworkFailure(e.message));
  } on CacheException catch (e) {
    return Left(CacheFailure(e.message));
  } on ServerException catch (e) {
    return Left(ServerFailure(e.message));
  } catch (_) {
    return Left(ServerFailure(fallback));
  }
}
