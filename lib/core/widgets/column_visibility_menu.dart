import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Toggle which table columns are shown. [columns] maps column id → header.
class ColumnVisibilityMenu extends StatelessWidget {
  const ColumnVisibilityMenu({
    super.key,
    required this.columns,
    required this.hidden,
    required this.onChanged,
  });

  final Map<String, String> columns;
  final Set<String> hidden;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, _) => OutlinedButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.view_column_outlined, size: 18),
        label: Text(
          hidden.isEmpty
              ? 'Columns'
              : 'Columns (${columns.length - hidden.length}/${columns.length})',
        ),
      ),
      menuChildren: [
        for (final e in columns.entries)
          CheckboxMenuButton(
            closeOnActivate: false,
            value: !hidden.contains(e.key),
            onChanged: (v) {
              final next = {...hidden};
              if (v ?? false) {
                next.remove(e.key);
              } else {
                next.add(e.key);
              }
              onChanged(next);
            },
            child: Text(e.value),
          ),
        const Divider(),
        MenuItemButton(
          onPressed: hidden.isEmpty ? null : () => onChanged({}),
          child: const Text(
            'Show all',
            style: TextStyle(color: AppColors.info),
          ),
        ),
      ],
    );
  }
}
