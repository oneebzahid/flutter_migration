import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_dialog.dart';
import '../../../../../core/widgets/app_dropdown.dart';
import '../../domain/entities/screen_catalog.dart';
import 'permission_grid.dart';

class AccessSelection {
  const AccessSelection(this.branch, this.permissions);
  final String branch;
  final List<String> permissions;
}

/// Branch + screen permission editor, used for both "Approve" and "Edit access".
/// Returns null when cancelled. Requires at least one screen (React rule).
Future<AccessSelection?> showAccessEditorDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String confirmLabel,
  required String initialBranch,
  required List<String> initialPermissions,
}) {
  return showDialog<AccessSelection>(
    context: context,
    builder: (_) => _AccessEditor(
      title: title,
      subtitle: subtitle,
      confirmLabel: confirmLabel,
      initialBranch: initialBranch,
      initialPermissions: initialPermissions,
    ),
  );
}

class _AccessEditor extends StatefulWidget {
  const _AccessEditor({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.initialBranch,
    required this.initialPermissions,
  });

  final String title;
  final String subtitle;
  final String confirmLabel;
  final String initialBranch;
  final List<String> initialPermissions;

  @override
  State<_AccessEditor> createState() => _AccessEditorState();
}

class _AccessEditorState extends State<_AccessEditor> {
  late String _branch =
      matchBranch(widget.initialBranch) ?? branchValue(kBranches.first);
  late Set<String> _selected = {...widget.initialPermissions};
  String? _error;

  void _save() {
    if (_selected.isEmpty) {
      setState(() => _error = 'User must have at least one screen permission');
      return;
    }
    // Keep catalog order so stored lists are stable.
    final ordered = [
      for (final g in allScreenGroups)
        for (final s in g.screens)
          if (_selected.contains(s)) s,
    ];
    Navigator.of(context).pop(AccessSelection(_branch, ordered));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppDialog(
      title: widget.title,
      maxWidth: 900,
      actions: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: widget.confirmLabel,
          icon: Icons.check,
          onPressed: _save,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.subtitle,
            style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: AppDropdown<String>(
              label: 'Branch',
              value: _branch,
              items: [
                for (final b in kBranches) AppDropdownItem(branchValue(b), b),
              ],
              onChanged: (v) => setState(() => _branch = v ?? _branch),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Screen access (${_selected.length} selected)',
                  style: t.titleSmall,
                ),
              ),
              if (_selected.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _selected = {}),
                  child: const Text('Clear all'),
                ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: t.bodySmall?.copyWith(color: AppColors.error),
                ),
              ),
            ),
          PermissionGrid(
            selected: _selected,
            onToggle: (s) => setState(() {
              _selected = toggleScreen(_selected, s);
              _error = null;
            }),
            onToggleGroup: (g) => setState(() {
              _selected = toggleGroup(_selected, g);
              _error = null;
            }),
          ),
        ],
      ),
    );
  }
}
