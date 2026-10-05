import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_datasource.dart';

/// Bridges [SettingsDataSource] (throws) to [SettingsRepository] (`Either`).
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._source);

  final SettingsDataSource _source;

  @override
  Future<Either<Failure, String>> getCurrency() =>
      guardCall(_source.getCurrency, fallback: 'Failed to load settings');

  @override
  Future<Either<Failure, Unit>> setCurrency(String code) => guardCall(() async {
    await _source.setCurrency(code);
    return unit;
  }, fallback: 'Failed to update system currency');
}
