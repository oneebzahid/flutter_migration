import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/company_config.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import 'nav_items.dart';
import 'shell_controller.dart';
import 'side_navigation.dart';
import 'top_bar.dart';

/// Adaptive ERP frame:
///  - expanded (>=1024): collapsible persistent sidebar
///  - medium (600-1024): icon-only sidebar
///  - compact (<600): app bar + drawer
///
/// Every signed-in GetX page wraps itself in one (see `AppPages`). Its
/// collapse state lives in [ShellController] so it survives navigation.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.location,
    required this.child,
    this.company = CompanyConfig.bullion,
  });

  final String location;
  final Widget child;
  final CompanyConfig company;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _auth = Get.find<AuthController>();
  final _shell = Get.find<ShellController>();

  String get _title =>
      navItemFor(widget.location)?.label ?? widget.company.shortName;

  Future<void> _logout(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Sign out',
      message: 'Do you want to sign out of ${widget.company.shortName}?',
      confirmLabel: 'Sign out',
    );
    if (ok) {
      await _auth.logout();
      Get.offAllNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = _auth.user.value;
      if (user == null) return const SizedBox.shrink();
      final items = visibleNavItems(user);
      final sidebarCollapsed = _shell.sidebarCollapsed.value;

      return ResponsiveBuilder(
        builder: (context, size) {
          void go(String path) {
            if (size == ScreenSize.compact) Navigator.of(context).maybePop();
            if (path != widget.location) Get.offNamed(path);
          }

          Widget nav({required bool collapsed}) => SideNavigation(
            items: items,
            currentLocation: widget.location,
            onNavigate: go,
            company: widget.company,
            user: user,
            collapsed: collapsed,
          );

          final content = Column(
            children: [
              TopBar(
                title: _title,
                user: user,
                onLogout: () => _logout(context),
                leading: size == ScreenSize.compact
                    ? IconButton(
                        tooltip: 'Menu',
                        icon: const Icon(Icons.menu),
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                      )
                    : size == ScreenSize.expanded
                    ? IconButton(
                        tooltip: sidebarCollapsed
                            ? 'Expand sidebar'
                            : 'Collapse sidebar',
                        icon: Icon(
                          sidebarCollapsed ? Icons.menu : Icons.menu_open,
                        ),
                        onPressed: _shell.toggleSidebar,
                      )
                    : null,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppDimensions.maxContentWidth,
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ],
          );

          if (size == ScreenSize.compact) {
            return Scaffold(
              key: _scaffoldKey,
              drawer: Drawer(
                width: AppDimensions.sidebarWidth,
                child: nav(collapsed: false),
              ),
              body: SafeArea(child: content),
            );
          }

          final collapsed = size == ScreenSize.medium || sidebarCollapsed;
          return Scaffold(
            body: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: collapsed
                      ? AppDimensions.sidebarCollapsedWidth
                      : AppDimensions.sidebarWidth,
                  decoration: const BoxDecoration(color: AppColors.sidebar),
                  child: nav(collapsed: collapsed),
                ),
                Expanded(child: content),
              ],
            ),
          );
        },
      );
    });
  }
}
