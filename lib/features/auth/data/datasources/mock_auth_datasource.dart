import '../../../../core/error/exceptions.dart';
import 'auth_datasource.dart';
import '../../domain/entities/auth_user.dart';

/// Frontend-only stand-in for the real backend. Reproduces the React login
/// outcomes (success, wrong credentials, no profile, pending, rejected).
class MockAuthDataSource implements AuthDataSource {
  MockAuthDataSource({this.latency = const Duration(milliseconds: 700)});

  final Duration latency;

  static const demoAdminEmail = 'admin@demo.com';
  static const demoAdminPassword = 'admin123';
  static const demoUserEmail = 'user@demo.com';
  static const demoUserPassword = 'user123';

  static const _accounts = <String, _Account>{
    demoAdminEmail: _Account(
      password: demoAdminPassword,
      user: AuthUser(
        uid: 'demo-admin',
        email: demoAdminEmail,
        role: UserRole.superAdmin,
        branch: 'Head Office',
      ),
    ),
    demoUserEmail: _Account(
      password: demoUserPassword,
      user: AuthUser(
        uid: 'demo-user',
        email: demoUserEmail,
        role: UserRole.user,
        permissions: [Screens.dashboard, Screens.inventory, Screens.invoices],
        branch: 'Abu Dhabi',
      ),
    ),
    'pending@demo.com': _Account(password: 'pending123', status: 'pending'),
    'rejected@demo.com': _Account(password: 'rejected123', status: 'rejected'),
    'noprofile@demo.com': _Account(
      password: 'noprofile123',
      status: 'no-profile',
    ),
  };

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    final account = _accounts[email.trim().toLowerCase()];
    if (account == null || account.password != password) {
      throw const AuthException('Invalid email or password.');
    }
    switch (account.status) {
      case 'no-profile':
        throw const AuthException(
          'Access denied. You are not authorized to use this system.',
        );
      case 'pending':
        throw const AuthException(
          'Your account is pending admin approval. Please wait for the admin to approve your request.',
        );
      case 'rejected':
        throw const AuthException(
          'Your registration request has been rejected by the admin.',
        );
    }
    return account.user!;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordReset(String email) async {
    await Future<void>.delayed(latency);
    if (!_accounts.containsKey(email.trim().toLowerCase())) {
      throw const AuthException('No account found with this email.');
    }
  }
}

class _Account {
  const _Account({required this.password, this.user, this.status = 'active'});
  final String password;
  final AuthUser? user;
  final String status;
}
