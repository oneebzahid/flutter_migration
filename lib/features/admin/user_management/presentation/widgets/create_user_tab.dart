import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_dropdown.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/screen_catalog.dart';
import 'permission_grid.dart';

class NewUserData {
  const NewUserData({
    required this.email,
    required this.password,
    required this.branch,
    required this.permissions,
  });
  final String email;
  final String password;
  final String branch;
  final List<String> permissions;
}

/// "Add New User" form. Validation and messages follow the React screen.
class CreateUserTab extends StatefulWidget {
  const CreateUserTab({super.key, required this.busy, required this.onSubmit});

  final bool busy;
  final ValueChanged<NewUserData> onSubmit;

  @override
  State<CreateUserTab> createState() => _CreateUserTabState();
}

class _CreateUserTabState extends State<CreateUserTab> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _branch;
  Set<String> _selected = {};
  bool _showPassword = false;
  String? _permissionError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final formOk = _formKey.currentState?.validate() ?? false;
    final permsOk = _selected.isNotEmpty;
    setState(
      () => _permissionError = permsOk
          ? null
          : 'Please select at least one screen permission',
    );
    if (!formOk || !permsOk) return;
    final ordered = [
      for (final g in allScreenGroups)
        for (final s in g.screens)
          if (_selected.contains(s)) s,
    ];
    widget.onSubmit(
      NewUserData(
        email: _email.text.trim(),
        password: _password.text,
        branch: _branch!,
        permissions: ordered,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final enabled = !widget.busy;

    final email = AppTextField(
      label: 'Email address',
      required: true,
      controller: _email,
      enabled: enabled,
      hint: 'user@bullion.com',
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      prefixIcon: Icons.mail_outline,
      validator: (v) =>
          (v == null || v.trim().isEmpty || !_emailRe.hasMatch(v.trim()))
          ? 'Please enter a valid email address'
          : null,
    );
    final password = AppTextField(
      label: 'Password',
      required: true,
      controller: _password,
      enabled: enabled,
      hint: 'At least 6 characters',
      obscureText: !_showPassword,
      textInputAction: TextInputAction.next,
      prefixIcon: Icons.lock_outline,
      validator: (v) => (v == null || v.length < 6)
          ? 'Password must be at least 6 characters'
          : null,
      suffix: IconButton(
        tooltip: _showPassword ? 'Hide password' : 'Show password',
        icon: Icon(
          _showPassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 20,
        ),
        onPressed: () => setState(() => _showPassword = !_showPassword),
      ),
    );
    final branch = AppDropdown<String>(
      label: 'Branch',
      required: true,
      value: _branch,
      hint: 'Select branch',
      enabled: enabled,
      items: [for (final b in kBranches) AppDropdownItem(branchValue(b), b)],
      onChanged: (v) => setState(() => _branch = v),
      validator: (v) => v == null ? 'Please select a branch' : null,
    );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth >= 760) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: email),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: password),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: branch),
                  ],
                );
              }
              return Column(
                children: [
                  email,
                  const SizedBox(height: AppSpacing.lg),
                  password,
                  const SizedBox(height: AppSpacing.lg),
                  branch,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Text('Screen permissions', style: t.titleSmall),
              const SizedBox(width: AppSpacing.sm),
              if (_selected.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_selected.length} selected',
                    style: t.labelSmall?.copyWith(color: AppColors.accent),
                  ),
                ),
              const Spacer(),
              if (_selected.isNotEmpty)
                TextButton(
                  onPressed: enabled
                      ? () => setState(() => _selected = {})
                      : null,
                  child: const Text('Clear all'),
                ),
            ],
          ),
          if (_permissionError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _permissionError!,
                  style: t.bodySmall?.copyWith(color: AppColors.error),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          PermissionGrid(
            selected: _selected,
            enabled: enabled,
            onToggle: (s) => setState(() {
              _selected = toggleScreen(_selected, s);
              _permissionError = null;
            }),
            onToggleGroup: (g) => setState(() {
              _selected = toggleGroup(_selected, g);
              _permissionError = null;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Create user',
              icon: Icons.person_add_alt_1_outlined,
              isLoading: widget.busy,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

final RegExp _emailRe = RegExp(r'\S+@\S+\.\S+');
