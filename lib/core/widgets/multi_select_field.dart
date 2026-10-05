import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';
import 'app_dialog.dart';

/// Multi-select filter. Tap opens a checklist dialog (All / Clear / Apply);
/// the current selection shows as chips under the field. An empty selection
/// means "no filter".
class MultiSelectField extends StatelessWidget {
  const MultiSelectField({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.allLabel = 'All',
  });

  final String label;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final String allLabel;

  String get _summary => selected.isEmpty
      ? allLabel
      : (selected.length == 1 ? selected.first : '${selected.length} selected');

  Future<void> _open(BuildContext context) async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (_) =>
          _PickerDialog(title: label, options: options, initial: selected),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final active = selected.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: t.labelSmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          button: true,
          label: '$label filter, $_summary',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => _open(context),
            child: Container(
              height: AppDimensions.fieldHeight - 4,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: active ? AppColors.surfaceMuted : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: active
                      ? AppColors.primaryHover
                      : AppColors.borderStrong,
                  width: active ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _summary,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium?.copyWith(
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        color: active
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickerDialog extends StatefulWidget {
  const _PickerDialog({
    required this.title,
    required this.options,
    required this.initial,
  });

  final String title;
  final List<String> options;
  final Set<String> initial;

  @override
  State<_PickerDialog> createState() => _PickerDialogState();
}

class _PickerDialogState extends State<_PickerDialog> {
  late final Set<String> _sel = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.title,
      maxWidth: 380,
      actions: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: 'Apply',
          onPressed: () => Navigator.of(context).pop(_sel),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TextButton(
                onPressed: () => setState(
                  () => _sel
                    ..clear()
                    ..addAll(widget.options),
                ),
                child: const Text('All'),
              ),
              TextButton(
                onPressed: () => setState(_sel.clear),
                child: const Text('Clear'),
              ),
              const Spacer(),
              Text(
                '${_sel.length} of ${widget.options.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (widget.options.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('No options'),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final o in widget.options)
                    CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _sel.contains(o),
                      title: Text(o),
                      onChanged: (v) => setState(() {
                        if (v ?? false) {
                          _sel.add(o);
                        } else {
                          _sel.remove(o);
                        }
                      }),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
