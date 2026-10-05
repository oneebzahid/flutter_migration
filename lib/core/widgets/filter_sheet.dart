import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_button.dart';

/// Filters as a bottom sheet (compact screens). [fields] is rebuilt whenever
/// [refresh] is called, so selections show immediately while the sheet is open.
Future<void> showFilterSheet(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext context, VoidCallback refresh) fields,
  required VoidCallback onClearAll,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        void refresh() => setSheet(() {});
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            MediaQuery.viewInsetsOf(ctx).bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      onClearAll();
                      refresh();
                    },
                    child: const Text('Clear all'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: SingleChildScrollView(child: fields(ctx, refresh)),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Show results',
                expand: true,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    ),
  );
}
