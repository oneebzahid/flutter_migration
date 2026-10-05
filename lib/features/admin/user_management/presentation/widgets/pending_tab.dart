import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_states.dart';
import '../../../../../core/widgets/status_badge.dart';
import '../../domain/entities/managed_user.dart';
import 'user_avatar.dart';

class PendingTab extends StatelessWidget {
  const PendingTab({
    super.key,
    required this.users,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final List<ManagedUser> users;
  final bool busy;
  final ValueChanged<ManagedUser> onApprove;
  final ValueChanged<ManagedUser> onReject;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const AppEmptyState(
        icon: Icons.check_circle_outline,
        title: 'No Pending Approvals',
        message: 'All registered users have been processed.',
      );
    }
    return Column(
      children: [
        for (final u in users)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _PendingCard(
              user: u,
              busy: busy,
              onApprove: () => onApprove(u),
              onReject: () => onReject(u),
            ),
          ),
      ],
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.user,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final ManagedUser user;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final registered = user.createdAt == null
        ? 'Recently'
        : DateFormat('d MMM y, h:mm a').format(user.createdAt!);

    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(email: user.email, size: 44),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(user.fullName ?? 'User', style: t.titleMedium),
                  const StatusBadge(
                    label: 'Pending approval',
                    tone: StatusTone.warning,
                  ),
                ],
              ),
              Text(
                user.email,
                style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                'Registered: $registered',
                style: t.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );

    Widget actions({required bool compact}) {
      final approve = AppButton(
        label: 'Approve & set access',
        icon: Icons.how_to_reg_outlined,
        expand: compact,
        onPressed: busy ? null : onApprove,
      );
      final reject = AppButton(
        label: 'Reject',
        icon: Icons.cancel_outlined,
        variant: AppButtonVariant.danger,
        expand: compact,
        onPressed: busy ? null : onReject,
      );
      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            approve,
            const SizedBox(height: AppSpacing.sm),
            reject,
          ],
        );
      }
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [approve, reject],
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warningSoft.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 760
            ? Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: AppSpacing.lg),
                  actions(compact: false),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  info,
                  const SizedBox(height: AppSpacing.md),
                  actions(compact: true),
                ],
              ),
      ),
    );
  }
}
