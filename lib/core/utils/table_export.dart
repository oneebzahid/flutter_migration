import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Data to export, independent of the screen that produced it.
/// Cells may be [String], [num], [DateTime] or null (blank).
class ExportTable {
  const ExportTable({
    required this.title,
    required this.headers,
    required this.rows,
    this.subtitle,
    this.filters = const [],
    this.rightAlignedColumns = const {},
  });

  final String title;
  final String? subtitle;
  final List<String> headers;
  final List<List<Object?>> rows;

  /// Human-readable active filters, e.g. `Brand: Garrett`. Empty = none.
  final List<String> filters;

  /// Column indexes holding amounts (right-aligned in the PDF, formatted as
  /// numbers in Excel).
  final Set<int> rightAlignedColumns;

  String get filterLine => filters.isEmpty
      ? 'Filters: none (all records)'
      : 'Filters: ${filters.join(' · ')}';
}

/// Who/when produced a report; printed on every export.
class ExportMeta {
  const ExportMeta({
    required this.companyName,
    required this.generatedAt,
    this.logo,
  });

  final String companyName;
  final DateTime generatedAt;

  /// Company logo (PNG/JPEG bytes). Optional.
  final Uint8List? logo;

  String get generatedLabel {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    String two(int n) => n.toString().padLeft(2, '0');
    final d = generatedAt;
    return '${two(d.day)} ${months[d.month - 1]} ${d.year}, ${two(d.hour)}:${two(d.minute)}';
  }
}

/// Builds `.xlsx` and `.pdf` files from an [ExportTable].
abstract final class TableExport {
  static const _sheetName = 'Sheet1';

  /// Excel workbook. With [meta] the first rows carry the company, report
  /// title, generation time and filters; then a bold header row and the data
  /// (numbers stay numeric, amounts get a thousands/2-decimal format).
  static Uint8List toXlsx(ExportTable t, {ExportMeta? meta}) {
    final excel = Excel.createExcel();
    final name = _safeSheetName(t.title);
    excel.rename(_sheetName, name);
    final sheet = excel[name];

    var row = 0;
    if (meta != null) {
      void line(String text, {bool bold = false, int? size}) {
        sheet.appendRow([TextCellValue(text)]);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .cellStyle = CellStyle(
          bold: bold,
          fontSize: size,
        );
        row++;
      }

      line(meta.companyName, bold: true, size: 16);
      line(t.title, bold: true, size: 13);
      if (t.subtitle != null) line(t.subtitle!);
      line('Generated: ${meta.generatedLabel}');
      line(t.filterLine);
      // Spacer; an empty row would not advance the sheet's row count.
      sheet.appendRow([TextCellValue('')]);
      row++;
    }

    final headerRow = row;
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#FFF1F5F9'),
    );
    sheet.appendRow([for (final h in t.headers) TextCellValue(h)]);
    for (var c = 0; c < t.headers.length; c++) {
      sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: c, rowIndex: headerRow),
              )
              .cellStyle =
          headerStyle;
    }
    row++;

    final amountStyle = CellStyle(
      numberFormat: CustomNumericNumFormat(formatCode: '#,##0.00'),
    );
    for (final r in t.rows) {
      sheet.appendRow([for (final v in r) _cell(v)]);
      for (final c in t.rightAlignedColumns) {
        if (c < r.length && r[c] is num) {
          sheet
                  .cell(
                    CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row),
                  )
                  .cellStyle =
              amountStyle;
        }
      }
      row++;
    }

    for (var c = 0; c < t.headers.length; c++) {
      var width = t.headers[c].length.toDouble();
      for (final r in t.rows) {
        if (c < r.length) {
          final len = _text(r[c]).length;
          if (len > width) width = len.toDouble();
        }
      }
      sheet.setColumnWidth(c, (width + 3).clamp(10, 48));
    }
    final bytes = excel.encode();
    if (bytes == null) throw StateError('Could not encode workbook');
    return Uint8List.fromList(bytes);
  }

  /// Landscape A4 PDF. Page 1 has the full letterhead (logo, company, report
  /// title, generated date and filters); later pages keep a slim header.
  /// Table header rows repeat on every page.
  static Future<Uint8List> toPdf(ExportTable t, {ExportMeta? meta}) async {
    final doc = pw.Document(title: t.title, author: meta?.companyName);
    final many = t.headers.length > 10;
    final fontSize = many ? 6.5 : 8.5;
    final logo = meta?.logo == null ? null : pw.MemoryImage(meta!.logo!);

    pw.Widget letterhead() => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null) ...[
              pw.ClipOval(
                child: pw.SizedBox(
                  width: 44,
                  height: 44,
                  child: pw.Image(logo, fit: pw.BoxFit.cover),
                ),
              ),
              pw.SizedBox(width: 12),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (meta != null)
                    pw.Text(
                      _ascii(meta.companyName),
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                  pw.Text(
                    _ascii(t.title),
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (t.subtitle != null)
                    pw.Text(
                      _ascii(t.subtitle!),
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                ],
              ),
            ),
            if (meta != null)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Generated',
                    style: const pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    meta.generatedLabel,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          _ascii(t.filterLine),
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 0.8, color: PdfColors.amber700),
        pw.SizedBox(height: 4),
      ],
    );

    pw.Widget slimHeader() => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          _ascii('${meta?.companyName ?? ''}  ·  ${t.title}'),
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.Divider(thickness: 0.4, color: PdfColors.grey400),
      ],
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 24),
        header: (ctx) => ctx.pageNumber == 1 ? letterhead() : slimHeader(),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              _ascii(meta == null ? '' : 'Generated ${meta.generatedLabel}'),
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey600,
              ),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headers: [for (final h in t.headers) _ascii(h)],
            data: [
              for (final r in t.rows) [for (final v in r) _ascii(_text(v))],
            ],
            headerStyle: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(fontSize: fontSize),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 3,
            ),
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: PdfColors.grey300,
                width: 0.4,
              ),
              bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.6),
            ),
            cellAlignments: {
              for (var i = 0; i < t.headers.length; i++)
                i: t.rightAlignedColumns.contains(i)
                    ? pw.Alignment.centerRight
                    : pw.Alignment.centerLeft,
            },
          ),
        ],
      ),
    );
    return doc.save();
  }

  static CellValue? _cell(Object? v) => switch (v) {
    null => null,
    int i => IntCellValue(i),
    double d => DoubleCellValue(d),
    DateTime d => TextCellValue(_date(d)),
    _ => TextCellValue(v.toString()),
  };

  static String _text(Object? v) => switch (v) {
    null => '',
    DateTime d => _date(d),
    double d => _money(d),
    _ => v.toString(),
  };

  /// Amounts print with thousands separators and 2 decimals in the PDF.
  static String _money(double d) {
    final fixed = d.toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '$intPart.${parts[1]}';
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// The PDF's built-in fonts only cover Latin-1; replace typographic
  /// characters so nothing renders as a blank box.
  static String _ascii(String s) => s
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('·', '-')
      .replaceAll('…', '...')
      .replaceAll('→', '->');

  /// Excel sheet names: max 31 chars, no `[]:*?/\`.
  static String _safeSheetName(String s) {
    final cleaned = s.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
    final name = cleaned.isEmpty ? 'Export' : cleaned;
    return name.length > 31 ? name.substring(0, 31) : name;
  }
}
