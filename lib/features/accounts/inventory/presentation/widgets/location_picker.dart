import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_dialog.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../controllers/location_controller.dart';

const _addNew = '__add_new__';

/// Location dropdown with an "Add new location…" entry (React
/// `LocationSelector`). The list is the shared, persisted location list in
/// [LocationController]; adding one selects it immediately.
class LocationPicker extends StatefulWidget {
  const LocationPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Stocking Location',
    this.required = false,
    this.placeholder = 'Select location',
    this.errorText,
    this.compact = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String label;
  final bool required;
  final String placeholder;
  final String? errorText;

  /// Smaller, label-less variant for per-unit rows.
  final bool compact;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final LocationController _c = Get.find<LocationController>();

  @override
  void initState() {
    super.initState();
    _c.load();
  }

  Future<void> _add(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AddLocationDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    _c.add(name.trim());
    widget.onChanged(name.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final locations = _c.locations.toList();
      // Keep a just-added / legacy widget.value selectable before the list refreshes.
      final items = {
        ...locations,
        if (widget.value.isNotEmpty) widget.value,
      }.toList()..sort();
      final t = Theme.of(context).textTheme;
      final dropdown = DropdownButtonFormField<String>(
        key: ValueKey('${widget.value}|${items.length}'),
        initialValue: widget.value.isEmpty ? null : widget.value,
        isExpanded: true,
        isDense: widget.compact,
        hint: Text(widget.placeholder),
        decoration: InputDecoration(
          errorText: widget.errorText,
          contentPadding: widget.compact
              ? const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 10,
                )
              : null,
        ),
        items: [
          for (final l in items) DropdownMenuItem(value: l, child: Text(l)),
          const DropdownMenuItem(
            value: _addNew,
            child: Row(
              children: [
                Icon(Icons.add, size: 16, color: AppColors.info),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Add new location…',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),
        ],
        onChanged: (v) {
          if (v == _addNew) {
            _add(context);
          } else if (v != null) {
            widget.onChanged(v);
          }
        },
      );
      if (widget.compact) return dropdown;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              text: widget.label,
              style: t.labelLarge?.copyWith(color: AppColors.textSecondary),
              children: [
                if (widget.required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.error),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          dropdown,
        ],
      );
    });
  }
}

class _AddLocationDialog extends StatefulWidget {
  const _AddLocationDialog();

  @override
  State<_AddLocationDialog> createState() => _AddLocationDialogState();
}

class _AddLocationDialogState extends State<_AddLocationDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final v = _ctrl.text.trim();
    if (v.isNotEmpty) Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: 'Add location',
    maxWidth: 380,
    actions: [
      AppButton(
        label: 'Cancel',
        variant: AppButtonVariant.secondary,
        onPressed: () => Navigator.of(context).pop(),
      ),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _ctrl,
        builder: (_, v, _) => AppButton(
          label: 'Save',
          onPressed: v.text.trim().isEmpty ? null : _save,
        ),
      ),
    ],
    child: AppTextField(
      label: 'Location name',
      hint: 'e.g. Dubai',
      controller: _ctrl,
      autofocus: true,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _save(),
    ),
  );
}
