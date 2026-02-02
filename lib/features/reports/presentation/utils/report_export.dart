import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
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
static Future<Uint8List> toPaymentsPdf(
  PaymentsReport report, {
  String branchName = 'اسم الفرع',
  String logoAssetPath = 'assets/images/logo.png',
}) async {
  // ✅ تحميل الخط العربي
  final fontRegular =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
  final fontBold =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));

  // ✅ تحميل الشعار من assets (اختياري)
  pw.ImageProvider? logo;
  try {
    final logoBytes = await rootBundle.load(logoAssetPath);
    logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
  } catch (_) {
    logo = null; // إذا لم يوجد الشعار لا نكسر الـ PDF
  }

  final doc = pw.Document();
  final generatedAt = DateTime.now();

  pw.Widget header(pw.Context ctx) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // شعار (يمين)
            pw.Row(
              children: [
                if (logo != null)
                  pw.Container(
                    width: 36,
                    height: 36,
                    margin: const pw.EdgeInsets.only(left: 8),
                    child: pw.Image(logo!, fit: pw.BoxFit.contain),
                  ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      branchName,
                      style: pw.TextStyle(font: fontBold, fontSize: 14),
                    ),
                    pw.Text(
                      'تقرير السندات',
                      style: pw.TextStyle(font: fontRegular, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),

            // رقم الصفحة (يسار)
            pw.Text(
              'صفحة ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(font: fontRegular, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget footer(pw.Context ctx) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'من: ${report.from ?? '-'}    إلى: ${report.to ?? '-'}',
              style: pw.TextStyle(font: fontRegular, fontSize: 9),
            ),
            pw.Text(
              'تم الإنشاء: ${generatedAt.toString().substring(0, 19)}',
              style: pw.TextStyle(font: fontRegular, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      header: header,
      footer: footer,
      build: (context) {
        return [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 8),

                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'إجمالي القبض: ${report.totals.totalIn.toStringAsFixed(2)}',
                        style: pw.TextStyle(font: fontBold, fontSize: 11),
                      ),
                      pw.Text(
                        'إجمالي الصرف: ${report.totals.totalOut.toStringAsFixed(2)}',
                        style: pw.TextStyle(font: fontBold, fontSize: 11),
                      ),
                      pw.Text(
                        'الصافي: ${report.totals.net.toStringAsFixed(2)}',
                        style: pw.TextStyle(font: fontBold, fontSize: 11),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 14),

                pw.Table.fromTextArray(
                  headers: const [
                    '#',
                    'التاريخ',
                    'النوع',
                    'المبلغ',
                    'العميل',
                    'رقم العقد'
                  ],
                  data: List.generate(report.rows.length, (i) {
                    final r = report.rows[i];
                    return [
                      (i + 1).toString(),
                      r.createdAt,
                      (r.type == 'in') ? 'قبض' : 'صرف',
                      r.amount.toStringAsFixed(2),
                      r.clientName ?? '-',
                      (r.rentNo ?? '').toString(),
                    ];
                  }),
                  headerStyle: pw.TextStyle(font: fontBold, fontSize: 11),
                  cellStyle: pw.TextStyle(font: fontRegular, fontSize: 10),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.grey300),
                  cellAlignment: pw.Alignment.centerRight,
                  columnWidths: const {
                    0: pw.FixedColumnWidth(28),
                    1: pw.FlexColumnWidth(2.2),
                    2: pw.FlexColumnWidth(1.2),
                    3: pw.FlexColumnWidth(1.2),
                    4: pw.FlexColumnWidth(2.2),
                    5: pw.FlexColumnWidth(1.2),
                  },
                ),

                if (report.rows.isEmpty) ...[
                  pw.SizedBox(height: 20),
                  pw.Center(
                    child: pw.Text(
                      'لا توجد بيانات ضمن النطاق',
                      style: pw.TextStyle(font: fontRegular, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
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
    return ReportExportImpl.shareBytesAsFile(
      fileName: fileName,
      mime: mime,
      bytes: bytes,
    );
  }
}
