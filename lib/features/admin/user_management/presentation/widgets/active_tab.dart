import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_search_field.dart';
import '../../../../../core/widgets/app_states.dart';
import '../../../../../core/widgets/status_badge.dart';
import '../../domain/entities/managed_user.dart';
import '../../domain/entities/screen_catalog.dart';
import 'user_avatar.dart';

class ActiveTab extends StatefulWidget {
  const ActiveTab({
    super.key,
    required this.users,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ManagedUser> users;
  final bool busy;
  final ValueChanged<ManagedUser> onEdit;
  final ValueChanged<ManagedUser> onDelete;

  @override
  State<ActiveTab> createState() => _ActiveTabState();
}

class _ActiveTabState extends State<ActiveTab> {
  String _query = '';

  List<ManagedUser> get _filtered {
    if (_query.isEmpty) return widget.users;
    final q = _query.toLowerCase();
    return widget.users
        .where(
          (u) =>
              u.email.toLowerCase().contains(q) ||
              (u.fullName ?? '').toLowerCase().contains(q) ||
              u.branch.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.users.isEmpty) {
      return const AppEmptyState(
        icon: Icons.group_outlined,
        title: 'No active users yet',
        message: 'Approve pending users or add a new user manually.',
      );
    }
    final list = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AppSearchField(
            hint: 'Search by name, email or branch',
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (list.isEmpty)
          AppEmptyState(
            icon: Icons.search_off,
            title: 'No matching users',
            message: 'Nothing matches "$_query".',
          )
        else
          for (final u in list)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _UserRow(
                user: u,
                busy: widget.busy,
                onEdit: () => widget.onEdit(u),
                onDelete: () => widget.onDelete(u),
              ),
            ),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final ManagedUser user;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final n = user.permissions.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            UserAvatar(email: user.email),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.email, style: t.titleSmall),
                  if (user.fullName != null)
                    Text(
                      user.fullName!,
                      style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      StatusBadge(
                        label: 'Branch: ${branchLabel(user.branch)}',
                        tone: StatusTone.neutral,
                      ),
                      StatusBadge(
                        label: '$n screen${n == 1 ? '' : 's'}',
                        tone: StatusTone.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit access for ${user.email}',
              icon: const Icon(Icons.edit_outlined, color: AppColors.info),
              onPressed: busy ? null : onEdit,
            ),
            IconButton(
              tooltip: 'Delete ${user.email}',
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: busy ? null : onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
