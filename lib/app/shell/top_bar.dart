import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/auth/domain/entities/auth_user.dart';

/// Header shown above the content. [leading] is the menu/collapse button.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    required this.user,
    required this.onLogout,
    this.leading,
  });

  final String title;
  final AuthUser user;
  final VoidCallback onLogout;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      height: AppDimensions.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          ?leading,
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: t.titleLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            offset: const Offset(0, AppDimensions.topBarHeight - 12),
            onSelected: (v) {
              if (v == 'logout') onLogout();
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.email, style: t.titleSmall),
                    Text(
                      user.isSuperAdmin ? 'Super admin' : 'User',
                      style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                    if (user.branch.isNotEmpty)
                      Text(
                        user.branch,
                        style: t.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('Sign out'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Text(
                  user.email.isEmpty ? '?' : user.email[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
