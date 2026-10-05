import 'package:flutter/material.dart';

import '../../core/widgets/app_states.dart';

/// Honest placeholder for modules that have not been migrated yet.
/// It carries no data and no actions, so nothing here can be mistaken for real behaviour.
class ModulePlaceholderPage extends StatelessWidget {
  const ModulePlaceholderPage({
    super.key,
    required this.title,
    required this.note,
  });

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: Icons.construction_outlined,
    title: '$title — not migrated yet',
    message: note,
  );
}
