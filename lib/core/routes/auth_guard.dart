import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../app/shell/nav_items.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import 'app_routes.dart';

/// Route guard: signed-out users go to the login page, signed-in users never
/// see it, and every route needs its screen permission (the React app only
/// hides menu items, so this closes the URL-typing hole).
class AuthGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final user = Get.find<AuthController>().user.value;
    final path = route ?? '';
    if (path == AppRoutes.login) {
      return user == null
          ? null
          : const RouteSettings(name: AppRoutes.dashboard);
    }
    if (user == null) return const RouteSettings(name: AppRoutes.login);
    if (path == '/' || path.isEmpty) {
      return const RouteSettings(name: AppRoutes.dashboard);
    }
    if (path != AppRoutes.dashboard &&
        !user.canAccess(requiredScreenFor(path))) {
      return const RouteSettings(name: AppRoutes.dashboard);
    }
    return null;
  }
}
