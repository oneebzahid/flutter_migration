import '../entities/auth_user.dart';

/// Who is signed in right now. Other features depend on this domain-level
/// contract (e.g. to record "deleted by") instead of on the auth controller.
abstract interface class SessionProvider {
  AuthUser? get currentUser;
}
