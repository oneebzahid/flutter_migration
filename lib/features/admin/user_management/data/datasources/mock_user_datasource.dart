import '../../../../../core/error/exceptions.dart';
import '../../domain/entities/managed_user.dart';
import 'user_datasource.dart';

/// In-memory stand-in for Firestore `users`. Seeded so every screen state
/// (pending, active, rejected) can be exercised.
class MockUserDataSource implements UserDataSource {
  MockUserDataSource({this.latency = const Duration(milliseconds: 500)}) {
    final now = DateTime.now();
    _users.addAll([
      ManagedUser(
        uid: 'u-ahmed',
        email: 'ahmed.khan@bullion.com',
        fullName: 'Ahmed Khan',
        status: UserStatus.pending,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      ManagedUser(
        uid: 'u-sara',
        email: 'sara.ali@bullion.com',
        fullName: 'Sara Ali',
        status: UserStatus.pending,
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      const ManagedUser(
        uid: 'u-omar',
        email: 'omar@bullion.com',
        fullName: 'Omar Farooq',
        branch: 'dubai',
        status: UserStatus.approved,
        permissions: [
          'Dashboard',
          'Invoices List',
          'Create Invoice',
          'Inventory Dashboard',
          'Inventory View',
        ],
      ),
      const ManagedUser(
        uid: 'u-lina',
        email: 'lina@bullion.com',
        branch: 'saudia',
        status: UserStatus.approved,
        permissions: [
          'Dashboard',
          'Transaction List',
          'Balance Sheet Report',
          'Bank Activity Report',
        ],
      ),
      const ManagedUser(
        uid: 'u-bilal',
        email: 'bilal@bullion.com',
        fullName: 'Bilal Hussain',
        branch: 'chad',
        status: UserStatus.approved,
        permissions: ['Dashboard', 'Employees List'],
      ),
      const ManagedUser(
        uid: 'u-rejected',
        email: 'rejected.user@bullion.com',
        status: UserStatus.rejected,
      ),
    ]);
  }

  final Duration latency;
  final List<ManagedUser> _users = [];

  Future<void> _wait() => Future<void>.delayed(latency);

  int _index(String uid) {
    final i = _users.indexWhere((u) => u.uid == uid);
    if (i < 0) throw const ValidationException('User not found.');
    return i;
  }

  ManagedUser _with(
    ManagedUser u, {
    UserStatus? status,
    String? branch,
    List<String>? permissions,
  }) => ManagedUser(
    uid: u.uid,
    email: u.email,
    fullName: u.fullName,
    status: status ?? u.status,
    branch: branch ?? u.branch,
    permissions: permissions ?? u.permissions,
    createdAt: u.createdAt,
  );

  @override
  Future<List<ManagedUser>> fetchUsers() async {
    await _wait();
    return List.unmodifiable(_users);
  }

  @override
  Future<void> createUser({
    required String email,
    required String password,
    required String branch,
    required List<String> permissions,
  }) async {
    await _wait();
    if (email.isEmpty ||
        password.isEmpty ||
        branch.isEmpty ||
        permissions.isEmpty) {
      throw const ValidationException(
        'Email, password, branch, and at least one permission are required',
      );
    }
    if (password.length < 6) {
      throw const ValidationException('Password must be at least 6 characters');
    }
    if (_users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      throw const ValidationException('This email is already registered.');
    }
    _users.add(
      ManagedUser(
        uid: 'u-${DateTime.now().microsecondsSinceEpoch}',
        email: email,
        branch: branch,
        permissions: permissions,
        status: UserStatus.approved,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> updateAccess({
    required String uid,
    required String branch,
    required List<String> permissions,
  }) async {
    await _wait();
    if (permissions.isEmpty) {
      throw const ValidationException('User must have at least one permission');
    }
    final i = _index(uid);
    _users[i] = _with(_users[i], branch: branch, permissions: permissions);
  }

  @override
  Future<void> approve({
    required String uid,
    required String branch,
    required List<String> permissions,
  }) async {
    await _wait();
    final i = _index(uid);
    _users[i] = _with(
      _users[i],
      status: UserStatus.approved,
      branch: branch,
      permissions: permissions,
    );
  }

  @override
  Future<void> reject(String uid) async {
    await _wait();
    final i = _index(uid);
    _users[i] = _with(_users[i], status: UserStatus.rejected);
  }

  @override
  Future<void> delete(String uid) async {
    await _wait();
    _users.removeAt(_index(uid));
  }
}
