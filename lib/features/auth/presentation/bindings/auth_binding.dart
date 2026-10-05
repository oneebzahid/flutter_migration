import 'package:get/get.dart';

import '../../data/datasources/auth_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/session_provider.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/send_password_reset_usecase.dart';
import '../controllers/auth_controller.dart';

/// Wires the app-wide session. Called once from `InitialBindings` because the
/// session outlives every route; the controller is also registered as the
/// [SessionProvider] other features depend on.
///
/// Expects an [AuthDataSource] to be registered already (mock or real).
class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<AuthRepository>(
      AuthRepositoryImpl(Get.find<AuthDataSource>()),
      permanent: true,
    );
    final controller = Get.put(
      AuthController(
        LoginUseCase(Get.find<AuthRepository>()),
        LogoutUseCase(Get.find<AuthRepository>()),
        SendPasswordResetUseCase(Get.find<AuthRepository>()),
      ),
      permanent: true,
    );
    Get.put<SessionProvider>(controller, permanent: true);
  }
}
