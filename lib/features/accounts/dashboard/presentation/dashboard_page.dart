import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/domain/repositories/session_provider.dart';

/// Temporary landing page. Real KPIs arrive with the Dashboard module; no
/// figures are shown here on purpose.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Get.find<SessionProvider>().currentUser;
    if (user == null) return const SizedBox.shrink();
    return ListView(
      padding: AppSpacing.pagePadding,
      children: [_Hero(user: user)],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.user});
  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = user.email.split('@').first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.sidebar, AppColors.gradientEnd],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: _Ring(size: 180, alpha: 0.18),
            ),
            Positioned(
              right: 40,
              bottom: -70,
              child: _Ring(size: 150, alpha: 0.10),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _Chip(
                        icon: Icons.verified_user_outlined,
                        label: user.isSuperAdmin ? 'Super admin' : 'User',
                      ),
                      if (user.branch.isNotEmpty)
                        _Chip(
                          icon: Icons.location_on_outlined,
                          label: user.branch,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Welcome back, $name',
                    style: t.headlineMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    user.email,
                    style: t.bodyLarge?.copyWith(color: AppColors.sidebarText),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Dashboard metrics will appear here in the Dashboard module.',
                    style: t.bodyMedium?.copyWith(color: AppColors.accent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.alpha});
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.accent.withValues(alpha: alpha),
          width: 22,
        ),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs + 1,
    ),
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.accent),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
