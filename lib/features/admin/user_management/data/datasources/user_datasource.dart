import '../../domain/entities/managed_user.dart';

/// Raw user-administration source. Throws the typed exceptions in
/// `core/error/exceptions.dart`; the repository maps them to failures.
abstract interface class UserDataSource {
  Future<List<ManagedUser>> fetchUsers();

  Future<void> createUser({
    required String email,
    required String password,
    required String branch,
    required List<String> permissions,
  });

  Future<void> updateAccess({
    required String uid,
    required String branch,
    required List<String> permissions,
  });

  Future<void> approve({
    required String uid,
    required String branch,
    required List<String> permissions,
  });

  Future<void> reject(String uid);

  Future<void> delete(String uid);
}
