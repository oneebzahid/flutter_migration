import '../../domain/entities/auth_user.dart';

/// Raw auth source (Firebase/Supabase/in-memory). Throws `AuthException`
/// with a user-facing message; the repository turns it into an `AuthFailure`.
abstract interface class AuthDataSource {
  Future<AuthUser> signIn({required String email, required String password});
  Future<void> signOut();
  Future<void> sendPasswordReset(String email);
}
