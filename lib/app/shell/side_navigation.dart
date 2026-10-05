import 'package:flutter/material.dart';

import '../../core/config/company_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/auth/domain/entities/auth_user.dart';
import 'nav_items.dart';

/// Dark sidebar shared by the desktop sidebar, tablet rail and mobile drawer.
class SideNavigation extends StatefulWidget {
  const SideNavigation({
    super.key,
    required this.items,
    required this.currentLocation,
    required this.onNavigate,
    required this.company,
    required this.user,
    this.collapsed = false,
  });

  final List<NavItem> items;
  final String currentLocation;
  final ValueChanged<String> onNavigate;
  final CompanyConfig company;
  final AuthUser user;
  final bool collapsed;

  @override
  State<SideNavigation> createState() => _SideNavigationState();
}

class _SideNavigationState extends State<SideNavigation> {
  final Set<String> _expanded = {};

  bool _isActive(NavItem item) {
    if (item.path == null) return item.children.any(_isActive);
    // Longest-match: '/invoices' must not be active on '/invoices/dummy'.
    return navItemFor(widget.currentLocation)?.id == item.id;
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.collapsed;
    return Material(
      color: AppColors.sidebar,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Brand(
              company: widget.company,
              collapsed: collapsed,
              onTap: () => widget.onNavigate('/dashboard'),
            ),
            const Divider(color: AppColors.sidebarBorder),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                children: [
                  if (!collapsed)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        0,
                        AppSpacing.sm,
                      ),
                      child: Text(
                        'MENU',
                        style: TextStyle(
                          color: AppColors.sidebarText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  for (final item in widget.items) _buildItem(item),
                ],
              ),
            ),
            _UserCard(user: widget.user, collapsed: collapsed),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(NavItem item) {
    final collapsed = widget.collapsed;
    if (!item.hasChildren) {
      return _NavTile(
        icon: item.icon,
        label: item.label,
        selected: _isActive(item),
        collapsed: collapsed,
        onTap: () => widget.onNavigate(item.path!),
      );
    }
    final open = _expanded.contains(item.id) || _isActive(item);
    if (collapsed) {
      // No room for a submenu: tapping goes to the first child.
      return _NavTile(
        icon: item.icon,
        label: item.label,
        selected: _isActive(item),
        collapsed: true,
        onTap: () => widget.onNavigate(item.children.first.path!),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NavTile(
          icon: item.icon,
          label: item.label,
          selected: false,
          highlightIcon: _isActive(item),
          collapsed: false,
          trailing: Icon(
            open ? Icons.expand_less : Icons.expand_more,
            size: 18,
            color: AppColors.sidebarText,
          ),
          onTap: () => setState(
            () => open ? _expanded.remove(item.id) : _expanded.add(item.id),
          ),
        ),
        if (open)
          for (final child in item.children)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg),
              child: _NavTile(
                icon: child.icon,
                label: child.label,
                selected: _isActive(child),
                collapsed: false,
                onTap: () => widget.onNavigate(child.path!),
              ),
            ),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({
    required this.company,
    required this.collapsed,
    required this.onTap,
  });

  final CompanyConfig company;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: AppDimensions.topBarHeight + 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              BrandLogo(
                size: 38,
                fallbackInitial: company.shortName.substring(0, 1),
              ),
              if (!collapsed) ...[
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company.nameLine1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        company.nameLine2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.collapsed,
    required this.onTap,
    this.trailing,
    this.highlightIcon = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;
  final Widget? trailing;

  /// Gold icon for a parent whose child is the active page.
  final bool highlightIcon;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected || highlightIcon
        ? AppColors.accent
        : AppColors.sidebarText;
    final textColor = selected ? Colors.white : AppColors.sidebarText;
    final radius = BorderRadius.circular(AppRadius.md);

    final tile = Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          hoverColor: AppColors.sidebarRaised,
          splashColor: AppColors.accent.withValues(alpha: 0.12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppDimensions.minTapTarget,
            ),
            child: Row(
              children: [
                // Gold active indicator bar.
                Container(
                  width: 3,
                  height: 22,
                  margin: const EdgeInsets.only(right: AppSpacing.md - 3),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(3),
                    ),
                  ),
                ),
                if (collapsed)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 3 + 6),
                      child: Center(
                        child: Icon(icon, size: 20, color: iconColor),
                      ),
                    ),
                  )
                else ...[
                  Icon(icon, size: 20, color: iconColor),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: textColor,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  ?trailing,
                  const SizedBox(width: AppSpacing.md),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: collapsed ? Tooltip(message: label, child: tile) : tile,
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.collapsed});

  final AuthUser user;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.accent,
      child: Text(
        user.email.isEmpty ? '?' : user.email[0].toUpperCase(),
        style: const TextStyle(
          color: AppColors.sidebar,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.sidebarRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.sidebarBorder),
      ),
      child: collapsed
          ? Center(
              child: Tooltip(message: user.email, child: avatar),
            )
          : Row(
              children: [
                avatar,
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.email,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        user.isSuperAdmin ? 'Super admin' : 'User',
                        style: const TextStyle(
                          color: AppColors.sidebarText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
