import 'package:get/get.dart';

/// State of the app frame that must survive navigation (every page rebuilds
/// its own [AppShell]).
class ShellController extends GetxController {
  final RxBool sidebarCollapsed = false.obs;

  void toggleSidebar() => sidebarCollapsed.toggle();
}
