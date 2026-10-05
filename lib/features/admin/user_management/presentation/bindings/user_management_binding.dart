import 'package:get/get.dart';

import '../../data/datasources/user_datasource.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/usecases/approve_user_usecase.dart';
import '../../domain/usecases/create_user_usecase.dart';
import '../../domain/usecases/delete_user_usecase.dart';
import '../../domain/usecases/get_users_usecase.dart';
import '../../domain/usecases/reject_user_usecase.dart';
import '../../domain/usecases/update_user_access_usecase.dart';
import '../controllers/user_management_controller.dart';

/// Wires the User Management route. The [UserDataSource] is registered
/// app-wide in `InitialBindings` while it is an in-memory mock.
class UserManagementBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UserRepository>(
      () => UserRepositoryImpl(Get.find<UserDataSource>()),
    );
    Get.lazyPut(() => GetUsersUseCase(Get.find<UserRepository>()));
    Get.lazyPut(() => CreateUserUseCase(Get.find<UserRepository>()));
    Get.lazyPut(() => ApproveUserUseCase(Get.find<UserRepository>()));
    Get.lazyPut(() => RejectUserUseCase(Get.find<UserRepository>()));
    Get.lazyPut(() => DeleteUserUseCase(Get.find<UserRepository>()));
    Get.lazyPut(() => UpdateUserAccessUseCase(Get.find<UserRepository>()));
    Get.lazyPut(
      () => UserManagementController(
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
      ),
    );
  }
}
