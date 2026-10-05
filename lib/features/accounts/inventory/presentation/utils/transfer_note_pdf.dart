import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/product_transfer.dart';

/// A4 stock transfer note, yellow/black like the React "Bullion Electronics"
/// transfer note. Pure function: bytes in, bytes out.
abstract final class TransferNotePdf {
  static const _yellow = PdfColor.fromInt(0xFFFFC107);
  static const _black = PdfColor.fromInt(0xFF111111);

  static String _a(String s) => s
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('·', '-')
      .replaceAll('…', '...')
      .replaceAll('→', '->');

  static String _dt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    const m = [
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
    return '${two(d.day)} ${m[d.month - 1]} ${d.year}, ${two(d.hour)}:${two(d.minute)}';
  }

  static Future<Uint8List> build(
    ProductTransfer t, {
    String company = 'BULLION ELECTRONICS',
    Uint8List? logo,
    DateTime? generatedAt,
  }) async {
    final doc = pw.Document(title: 'Transfer ${t.id}', author: company);
    final image = logo == null ? null : pw.MemoryImage(logo);

    pw.Widget field(String label, String value) => pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            _a(value),
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              color: _black,
              padding: const pw.EdgeInsets.all(16),
              child: pw.Row(
                children: [
                  if (image != null) ...[
                    pw.ClipOval(
                      child: pw.SizedBox(
                        width: 44,
                        height: 44,
                        child: pw.Image(image, fit: pw.BoxFit.cover),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          _a(company),
                          style: pw.TextStyle(
                            color: _yellow,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        pw.Text(
                          'STOCK TRANSFER NOTE',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        t.id,
                        style: pw.TextStyle(
                          color: _yellow,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        t.status.label.toUpperCase(),
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.Container(height: 4, color: _yellow),
            pw.SizedBox(height: 18),
            pw.Row(
              children: [
                field('From', t.from),
                field('To', t.to),
                field('Date & time', _dt(t.date)),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                field('Transferred by', t.transferredBy),
                field('Received by', t.receivedBy ?? '-'),
                field(
                  'Received at',
                  t.receivedAt == null ? '-' : _dt(t.receivedAt!),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: const ['PRODUCT', 'QTY', 'SHIPMENT COST'],
              data: [
                [
                  _a(t.productLabel),
                  '${t.quantity}',
                  t.shipmentCost.toStringAsFixed(2),
                ],
              ],
              headerStyle: pw.TextStyle(
                color: _yellow,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              headerDecoration: const pw.BoxDecoration(color: _black),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
              },
              cellPadding: const pw.EdgeInsets.all(8),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'SERIAL NUMBERS (${t.serials.length})',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in t.serials)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey500),
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: pw.Text(
                      _a(s),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
              ],
            ),
            pw.Spacer(),
            pw.Row(
              children: [
                for (final who in ['Dispatched by', 'Received by'])
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 24),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(height: 1, color: _black),
                          pw.SizedBox(height: 4),
                          pw.Text(who, style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Generated ${_dt(generatedAt ?? DateTime.now())}',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }
}
