import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../../core/routes/app_routes.dart';
import '../../../../../core/state/loadable.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/table_export.dart';
import '../../../../../core/widgets/app_data_table.dart';
import '../../../../../core/widgets/table_toolbar.dart';
import '../../../../../core/widgets/export_menu.dart';
import '../../../../../core/widgets/screen_header.dart';
import '../../domain/entities/inventory_records.dart';
import '../controllers/damaged_inventory_controller.dart';
import '../../../../../core/theme/app_typography.dart';

final DateFormat _stamp = DateFormat('d MMM y, h:mm a', 'en_US');
String _when(DateTime d) => _stamp.format(d);

/// Damaged Inventory (React `/inventory/damaged`): read-only archive of
/// serials moved to damaged stock. Records arrive from "Add Returned".
class DamagedInventoryPage extends StatefulWidget {
  const DamagedInventoryPage({super.key});

  @override
  State<DamagedInventoryPage> createState() => _DamagedInventoryPageState();
}

class _DamagedInventoryPageState extends State<DamagedInventoryPage> {
  String _search = '';
  final _c = Get.find<DamagedInventoryController>();

  /// React matches brand, model and serial only.
  List<DamagedRecord> _filter(List<DamagedRecord> all) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (r) =>
              r.brandName.toLowerCase().contains(q) ||
              r.modelName.toLowerCase().contains(q) ||
              r.serialNumber.toLowerCase().contains(q),
        )
        .toList();
  }

  /// Exports the filtered rows; the subtitle uses the unfiltered total (React).
  ExportTable _export(List<DamagedRecord> rows, int total) => ExportTable(
    title: 'Damaged Inventory',
    subtitle: '$total item(s)',
    headers: const [
      'Brand',
      'Model',
      'Serial',
      'Location',
      'Reason',
      'Damaged At',
    ],
    rows: [
      for (final r in rows)
        [
          r.brandName,
          r.modelName,
          r.serialNumber,
          r.location.isEmpty ? '—' : r.location,
          r.reason.isEmpty ? '—' : r.reason,
          _when(r.damagedAt),
        ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = _c.damaged.value;
      final loading = list.isInitialLoading;
      final rows = _filter(list.items);
      final t = Theme.of(context).textTheme;

      return ListView(
        padding: AppSpacing.pagePadding,
        children: [
          ScreenHeader(
            title: 'Damaged Inventory',
            subtitle: '${list.items.length} damaged item(s) archived',
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.error,
            onBack: () => Get.offNamed(AppRoutes.inventory),
          ),
          const SizedBox(height: AppSpacing.lg),
          TableToolbar(
            searchHint: 'Search brand, model, serial…',
            onSearch: (v) => setState(() => _search = v),
            onRefresh: () => _c.load(),
            export: ExportSpec(
              fileBaseName: 'damaged-inventory',
              rowCount: rows.length,
              build: () => _export(rows, list.items.length),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppDataTable<DamagedRecord>(
            rows: rows,
            rowKey: (r) => r.id,
            loading: loading,
            loadingMessage: 'Loading…',
            errorMessage: list.status == LoadStatus.failed ? list.error : null,
            onRetry: () => _c.load(),
            emptyTitle: 'No damaged inventory records.',
            columns: [
              AppColumn(
                id: 'brand',
                header: 'Brand',
                width: 140,
                cell: (_, r) => Text(
                  r.brandName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              AppColumn(
                id: 'model',
                header: 'Model',
                width: 200,
                cell: (_, r) => Text(r.modelName),
              ),
              AppColumn(
                id: 'serial',
                header: 'Serial',
                width: 160,
                cell: (_, r) => Text(
                  r.serialNumber,
                  style: const TextStyle(
                    fontFamily: AppTypography.monoFamily,
                    fontFamilyFallback: AppTypography.monoFallback,
                    fontSize: 12,
                  ),
                ),
              ),
              AppColumn(
                id: 'location',
                header: 'Location',
                width: 180,
                cell: (_, r) => Text(r.location.isEmpty ? '—' : r.location),
              ),
              AppColumn(
                id: 'reason',
                header: 'Reason',
                width: 280,
                cell: (_, r) => Text(
                  r.reason.isEmpty ? '—' : r.reason,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
              ),
              AppColumn(
                id: 'at',
                header: 'Damaged At',
                width: 200,
                cell: (_, r) => Text(
                  _when(r.damagedAt),
                  style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
              ),
            ],
            cardBuilder: (context, r) => Card(
              child: ListTile(
                title: Text('${r.brandName} ${r.modelName}'),
                subtitle: Text(
                  '${r.serialNumber} · ${r.location.isEmpty ? '—' : r.location}\n'
                  '${r.reason.isEmpty ? '—' : r.reason} · ${_when(r.damagedAt)}',
                ),
                isThreeLine: true,
              ),
            ),
          ),
        ],
      );
    });
  }
}
