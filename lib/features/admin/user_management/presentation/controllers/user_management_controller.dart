import 'package:dartz/dartz.dart';
import 'package:get/get.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/state/notice.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../domain/entities/managed_user.dart';
import '../../domain/usecases/approve_user_usecase.dart';
import '../../domain/usecases/create_user_usecase.dart';
import '../../domain/usecases/delete_user_usecase.dart';
import '../../domain/usecases/get_users_usecase.dart';
import '../../domain/usecases/reject_user_usecase.dart';
import '../../domain/usecases/update_user_access_usecase.dart';

enum UsersLoad { idle, loading, ready, failed }

/// User administration: pending approvals, active users, create / update /
/// reject / delete. Notice tags: create, approve, reject, delete, update.
class UserManagementController extends GetxController with NoticeMixin {
  UserManagementController(
    this._getUsers,
    this._createUser,
    this._approveUser,
    this._rejectUser,
    this._deleteUser,
    this._updateAccess,
  );

  final GetUsersUseCase _getUsers;
  final CreateUserUseCase _createUser;
  final ApproveUserUseCase _approveUser;
  final RejectUserUseCase _rejectUser;
  final DeleteUserUseCase _deleteUser;
  final UpdateUserAccessUseCase _updateAccess;

  final Rx<UsersLoad> load = UsersLoad.idle.obs;
  final RxList<ManagedUser> users = <ManagedUser>[].obs;
  final RxnString loadError = RxnString();

  /// True while a create/approve/reject/delete/update call is in flight.
  final RxBool busy = false.obs;

  List<ManagedUser> get pending =>
      users.where((u) => u.status == UserStatus.pending).toList();

  /// Same rule as React: approved, or no status at all.
  List<ManagedUser> get active =>
      users.where((u) => u.status == UserStatus.approved).toList();

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  Future<void> reload() async {
    load.value = UsersLoad.loading;
    final result = await _getUsers(const NoParams());
    result.fold(
      (f) {
        load.value = UsersLoad.failed;
        loadError.value = f.message;
      },
      (list) {
        // Users first: listeners on `load` read `pending` when it turns ready.
        loadError.value = null;
        users.assignAll(list);
        load.value = UsersLoad.ready;
      },
    );
  }

  /// Runs a mutation, then re-fetches the list (React does the same).
  Future<void> _run(
    String tag,
    Future<Either<Failure, Unit>> Function() call,
    String success,
  ) async {
    if (busy.value) return;
    busy.value = true;
    final result = await call();
    busy.value = false;
    final error = result.fold<String?>((f) => f.message, (_) => null);
    if (error != null) {
      notify(error, isError: true, tag: tag);
      return;
    }
    notify(success, tag: tag);
    await reload();
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String branch,
    required List<String> permissions,
  }) => _run(
    'create',
    () => _createUser(
      CreateUserParams(
        email: email,
        password: password,
        branch: branch,
        permissions: permissions,
      ),
    ),
    'User "$email" created successfully!',
  );

  Future<void> approve({
    required String uid,
    required String email,
    required String branch,
    required List<String> permissions,
  }) => _run(
    'approve',
    () => _approveUser(
      ApproveUserParams(uid: uid, branch: branch, permissions: permissions),
    ),
    'User "$email" approved successfully!',
  );

  Future<void> reject({required String uid, required String email}) => _run(
    'reject',
    () => _rejectUser(uid),
    'User "$email" registration rejected',
  );

  Future<void> deleteUser({required String uid, required String email}) =>
      _run('delete', () => _deleteUser(uid), 'User "$email" deleted');

  Future<void> updateAccess({
    required String uid,
    required String branch,
    required List<String> permissions,
  }) => _run(
    'update',
    () => _updateAccess(
      UpdateUserAccessParams(
        uid: uid,
        branch: branch,
        permissions: permissions,
      ),
    ),
    'User updated successfully',
  );
}
