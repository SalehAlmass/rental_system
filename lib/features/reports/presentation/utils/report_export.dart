import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/payment_report.dart';
import 'report_export_impl.dart' if (dart.library.html) 'report_export_web.dart';

class ReportExport {
  static String toPaymentsCsv(PaymentsReport report) {
    final b = StringBuffer();
    b.writeln('ID,Date,Type,Amount,Method,Client,Rent,Reference,Notes');
    for (final r in report.rows) {
      final safe = (String? s) => (s ?? '').replaceAll('"', '""');
      b.writeln([
        r.id,
        '"${safe(r.createdAt)}"',
        '"${safe(r.type)}"',
        r.amount.toStringAsFixed(2),
        '"${safe(r.method)}"',
        '"${safe(r.clientName)}"',
        r.rentNo ?? '',
        '"${safe(r.referenceNo)}"',
        '"${safe(r.notes)}"',
      ].join(','));
    }
    return b.toString();
  }

  static Future<Uint8List> toPaymentsPdf(PaymentsReport report) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
            pw.Text('Payments Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('From: ${report.from ?? '-'}   To: ${report.to ?? '-'}'),
            pw.SizedBox(height: 8),
            pw.Text('Totals: In=${report.totals.totalIn.toStringAsFixed(2)}  Out=${report.totals.totalOut.toStringAsFixed(2)}  Net=${report.totals.net.toStringAsFixed(2)}'),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: const ['ID', 'Date', 'Type', 'Amount', 'Client', 'Rent'],
              data: report.rows
                  .map((r) => [
                        r.id.toString(),
                        r.createdAt,
                        r.type,
                        r.amount.toStringAsFixed(2),
                        r.clientName ?? '-',
                        (r.rentNo ?? '').toString(),
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static Future<void> shareTextAsFile({
    required String fileName,
    required String mime,
    required String content,
  }) {
    final bytes = Uint8List.fromList(content.codeUnits);
    return shareBytesAsFile(fileName: fileName, mime: mime, bytes: bytes);
  }

  static Future<void> shareBytesAsFile({
    required String fileName,
    required String mime,
    required Uint8List bytes,
  }) {
    return ReportExportImpl.shareBytesAsFile(fileName: fileName, mime: mime, bytes: bytes);
  }
}
