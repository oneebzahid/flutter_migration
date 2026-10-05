import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';

/// System-wide settings (React: Firestore `settings/currency`).
///
/// Changing the currency only relabels amounts; stored figures are never
/// converted (see plan decision D5).
abstract interface class SettingsRepository {
  Future<Either<Failure, String>> getCurrency();
  Future<Either<Failure, Unit>> setCurrency(String code);
}
