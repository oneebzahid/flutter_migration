import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppDropdownItem<T> {
  const AppDropdownItem(this.value, this.label);
  final T value;
  final String label;
}

/// Labelled dropdown matching [AppTextField]. Controlled: pass [value] and
/// react in [onChanged].
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.hint,
    this.validator,
    this.required = false,
    this.enabled = true,
  });

  final String label;
  final List<AppDropdownItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final FormFieldValidator<T>? validator;
  final bool required;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            style: t.labelLarge?.copyWith(color: AppColors.textSecondary),
            children: [
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.error),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        DropdownButtonFormField<T>(
          // initialValue only applies on first build; re-key so a changed
          // [value] is reflected.
          key: ValueKey(value),
          initialValue: value,
          isExpanded: true,
          hint: hint == null ? null : Text(hint!),
          validator: validator,
          onChanged: enabled ? onChanged : null,
          items: [
            for (final i in items)
              DropdownMenuItem<T>(value: i.value, child: Text(i.label)),
          ],
        ),
      ],
    );
  }
}
