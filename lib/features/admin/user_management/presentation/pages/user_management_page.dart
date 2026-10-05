import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../core/settings/currency_provider.dart';
import '../../../../../core/state/notice.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_dialog.dart';
import '../../../../../core/widgets/app_states.dart';
import '../../../../../core/widgets/app_tabs.dart';
import '../../../../../core/widgets/notice_listener.dart';
import '../../domain/entities/managed_user.dart';
import '../controllers/user_management_controller.dart';
import '../widgets/access_editor_dialog.dart';
import '../widgets/active_tab.dart';
import '../widgets/create_user_tab.dart';
import '../widgets/pending_tab.dart';
import '../widgets/system_currency_card.dart';

/// User Management & Approvals (React: `/user-management`).
///
/// Not migrated on purpose: Factory Reset (open decision BR-17).
class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  static const _pending = 0;
  static const _active = 1;
  static const _create = 2;

  final UserManagementController _c = Get.find<UserManagementController>();
  final CurrencyProvider _currency = Get.find<CurrencyProvider>();
  Worker? _loadWorker;

  int _tab = _active;
  int _formKeySeed = 0;

  @override
  void initState() {
    super.initState();
    // Auto-open the pending tab the first time users load, as React does.
    if (_c.load.value == UsersLoad.ready && _c.pending.isNotEmpty) {
      _tab = _pending;
    }
    _loadWorker = ever<UsersLoad>(_c.load, (l) {
      if (l == UsersLoad.ready && _c.pending.isNotEmpty && mounted) {
        setState(() => _tab = _pending);
      }
    });
  }

  @override
  void dispose() {
    _loadWorker?.dispose();
    super.dispose();
  }

  void _onNotice(Notice n) {
    if (n.tag == 'create' && !n.isError) {
      setState(() {
        _formKeySeed++; // resets the form
        _tab = _active;
      });
    }
  }

  Future<void> _approve(ManagedUser u) async {
    final result = await showAccessEditorDialog(
      context,
      title: 'Approve registration',
      subtitle: '${u.email} — assign branch and screen permissions.',
      confirmLabel: 'Approve & grant access',
      initialBranch: u.branch.isEmpty ? 'saudia' : u.branch,
      initialPermissions: u.permissions,
    );
    if (result == null) return;
    _c.approve(
      uid: u.uid,
      email: u.email,
      branch: result.branch,
      permissions: result.permissions,
    );
  }

  Future<void> _reject(ManagedUser u) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Reject registration',
      message: 'Reject the registration request from "${u.email}"?',
      confirmLabel: 'Reject',
      destructive: true,
    );
    if (ok) {
      _c.reject(uid: u.uid, email: u.email);
    }
  }

  Future<void> _edit(ManagedUser u) async {
    final result = await showAccessEditorDialog(
      context,
      title: 'Edit screen access',
      subtitle: '${u.email} — update branch and screen permissions.',
      confirmLabel: 'Save access',
      initialBranch: u.branch.isEmpty ? 'saudia' : u.branch,
      initialPermissions: u.permissions,
    );
    if (result == null) return;
    _c.updateAccess(
      uid: u.uid,
      branch: result.branch,
      permissions: result.permissions,
    );
  }

  Future<void> _delete(ManagedUser u) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete user',
      message: 'Delete "${u.email}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok) {
      _c.deleteUser(uid: u.uid, email: u.email);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NoticeListener(
      notice: _c.notice,
      onNotice: _onNotice,
      child: Obx(() {
        final pending = _c.users.where((u) => u.status == UserStatus.pending);
        final pendingCount = pending.length;
        final activeCount = _c.active.length;
        return ListView(
          padding: AppSpacing.pagePadding,
          children: [
            _Header(pendingCount: pendingCount),
            const SizedBox(height: AppSpacing.lg),
            SystemCurrencyCard(
              code: _currency.currencyCode.value,
              busy: _currency.savingCurrency.value,
              onChanged: _currency.changeCurrency,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTabs(
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
              tabs: [
                AppTabItem(
                  label: 'Pending approvals',
                  icon: Icons.schedule,
                  badge: pendingCount,
                ),
                AppTabItem(
                  label: 'Active users ($activeCount)',
                  icon: Icons.group_outlined,
                ),
                const AppTabItem(
                  label: 'Add new user',
                  icon: Icons.person_add_alt_1_outlined,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _body(),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _body() {
    final busy = _c.busy.value;
    // The create form does not depend on the list, so it is always available.
    if (_tab == _create) {
      return KeyedSubtree(
        key: ValueKey(_formKeySeed),
        child: CreateUserTab(
          busy: busy,
          onSubmit: (d) => _c.createUser(
            email: d.email,
            password: d.password,
            branch: d.branch,
            permissions: d.permissions,
          ),
        ),
      );
    }
    final load = _c.load.value;
    if (load == UsersLoad.failed) {
      return AppErrorState(message: _c.loadError.value, onRetry: _c.reload);
    }
    if (load != UsersLoad.ready) {
      return const SizedBox(
        height: 220,
        child: AppLoading(message: 'Loading users…'),
      );
    }
    if (_tab == _pending) {
      return PendingTab(
        users: _c.pending,
        busy: busy,
        onApprove: _approve,
        onReject: _reject,
      );
    }
    return ActiveTab(
      users: _c.active,
      busy: busy,
      onEdit: _edit,
      onDelete: _delete,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.pendingCount});
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Icon(Icons.shield_outlined, color: AppColors.accent),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User management & approvals', style: t.titleLarge),
              Text(
                'Approve registered users, manage branch access, and control '
                'which screens each user can open.',
                style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
