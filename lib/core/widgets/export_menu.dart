import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/brand_assets.dart';
import '../config/company_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/file_downloader.dart';
import '../utils/table_export.dart';
import 'app_snackbar.dart';

/// What a screen can export. [build] runs only when the user picks a format,
/// so the file always reflects what is on screen right then.
class ExportSpec {
  const ExportSpec({
    required this.build,
    required this.fileBaseName,
    required this.rowCount,
  });

  final ExportTable Function() build;

  /// File name without extension or date, e.g. `inventory`.
  final String fileBaseName;

  /// Rows that will be exported (the filtered set, not just the visible page).
  final int rowCount;

  bool get isEmpty => rowCount == 0;
}

Uint8List? _cachedLogo;

Future<Uint8List?> _loadLogo() async {
  if (_cachedLogo != null) return _cachedLogo;
  try {
    final data = await rootBundle.load(BrandAssets.logo);
    return _cachedLogo = data.buffer.asUint8List();
  } catch (_) {
    return null; // the report still works without the logo
  }
}

/// Builds the file and hands it to the user, with snackbar feedback.
/// [extension] is `xlsx` or `pdf`.
Future<void> runExport(
  BuildContext context,
  ExportSpec spec,
  String extension,
) async {
  final label = extension == 'xlsx' ? 'Excel' : 'PDF';
  final messenger = context;
  try {
    final table = spec.build();
    final meta = ExportMeta(
      companyName: CompanyConfig.bullion.nameLine1,
      generatedAt: DateTime.now(),
      logo: await _loadLogo(),
    );
    final bytes = extension == 'xlsx'
        ? TableExport.toXlsx(table, meta: meta)
        : await TableExport.toPdf(table, meta: meta);
    final d = meta.generatedAt;
    final stamp =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    await AppFileDownloader.instance.save(
      fileName: '${spec.fileBaseName}-$stamp',
      extension: extension,
      bytes: bytes,
    );
    if (messenger.mounted) {
      showAppSnackBar(
        messenger,
        'Downloaded ${table.rows.length} row${table.rows.length == 1 ? '' : 's'} as $label',
      );
    }
  } catch (_) {
    if (messenger.mounted) {
      showAppSnackBar(
        messenger,
        'Could not create the $label file. Please try again.',
        isError: true,
      );
    }
  }
}

/// "Download" menu with Excel and PDF, stating exactly what is exported.
class ExportMenu extends StatefulWidget {
  const ExportMenu({super.key, required this.spec});

  final ExportSpec spec;

  @override
  State<ExportMenu> createState() => _ExportMenuState();
}

class _ExportMenuState extends State<ExportMenu> {
  bool _busy = false;

  Future<void> _go(String ext) async {
    if (_busy) return;
    setState(() => _busy = true);
    await runExport(context, widget.spec, ext);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.spec.isEmpty && !_busy;
    final t = Theme.of(context).textTheme;
    final n = widget.spec.rowCount;
    return MenuAnchor(
      builder: (context, controller, _) => OutlinedButton.icon(
        onPressed: !enabled
            ? null
            : () => controller.isOpen ? controller.close() : controller.open(),
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.file_download_outlined, size: 18),
        label: const Text('Download'),
      ),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            'Exports all $n filtered row${n == 1 ? '' : 's'}\n(every page, not just this one)',
            style: t.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ),
        const Divider(height: 1),
        MenuItemButton(
          leadingIcon: const Icon(Icons.table_chart_outlined, size: 18),
          onPressed: () => _go('xlsx'),
          child: const Text('Excel (.xlsx)'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          onPressed: () => _go('pdf'),
          child: const Text('PDF (.pdf)'),
        ),
      ],
    );
  }
}
