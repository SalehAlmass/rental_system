import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/payment_report.dart';
import 'report_export_impl.dart'
    if (dart.library.html) 'report_export_web.dart';

class ReportExport {
  /// توليد CSV من تقرير الدفعات
  static String toPaymentsCsv(PaymentsReport report) {
    final buffer = StringBuffer();
    buffer.writeln('ID,Date,Type,Amount,Method,Client,Rent,Reference,Notes');

    for (final r in report.rows) {
      final safe = (String? s) => (s ?? '').replaceAll('"', '""');
      buffer.writeln(
        [
          r.id,
          '"${safe(r.createdAt)}"',
          '"${safe(r.type)}"',
          r.amount.toStringAsFixed(2),
          '"${safe(r.method)}"',
          '"${safe(r.clientName)}"',
          r.rentNo ?? '',
          '"${safe(r.referenceNo)}"',
          '"${safe(r.notes)}"',
        ].join(','),
      );
    }

    return buffer.toString();
  }

  /// توليد PDF من تقرير الدفعات
  static Future<Uint8List> toPaymentsPdf(
    PaymentsReport report, {
    String branchName = 'اسم الفرع',
    String logoAssetPath = 'assets/images/logo.png',
  }) async {
    // ===================== تحميل الخطوط (مع fallback) =====================
    // 1) جرّب من assets (أفضل للعمل بدون إنترنت)
    // 2) إذا لم تكن موجودة، استخدم PdfGoogleFonts (يحتاج إنترنت أول مرة)
    pw.Font fontRegular;
    pw.Font fontBold;
    try {
      fontRegular = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
      fontBold = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));
    } catch (_) {
      fontRegular = await PdfGoogleFonts.cairoRegular();
      fontBold = await PdfGoogleFonts.cairoBold();
    }

    // ===================== تحميل شعار =====================
    pw.ImageProvider? logo;
    try {
      final logoBytes = await rootBundle.load(logoAssetPath);
      logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {
      logo = null; // إذا لم يتم العثور على الشعار
    }

    final doc = pw.Document();
    final generatedAt = DateTime.now();

    // ===================== الرأس =====================
    pw.Widget header(pw.Context ctx) {
      return pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // شعار واسم الفرع
              pw.Row(
                children: [
                  if (logo != null)
                    pw.Container(
                      width: 36,
                      height: 36,
                      margin: const pw.EdgeInsets.only(left: 8),
                      child: pw.Image(logo, fit: pw.BoxFit.contain),
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
              // رقم الصفحة
              pw.Text(
                'صفحة ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: pw.TextStyle(font: fontRegular, fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }

    // ===================== التذييل =====================
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

    // ===================== إنشاء صفحة =====================
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: header,
        footer: footer,
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 8),

                // ملخص التقرير
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

                // جدول الدفعات
                pw.Table.fromTextArray(
                  headers: const [
                    'التاريخ',
                    'النوع',
                    'المبلغ',
                    'العميل',
                    'رقم العقد',
                    'الرقم',
                  ],
                  data: List.generate(report.rows.length, (i) {
                    final r = report.rows[i];
                    return [
                      r.createdAt, // التاريخ
                      r.type == 'in' ? 'قبض' : 'صرف', // النوع
                      r.amount.toStringAsFixed(2), // المبلغ
                      r.clientName?.isNotEmpty == true
                          ? r.clientName!
                          : '-', // العميل
                      r.rentNo?.toString() ?? '-', // رقم العقد
                      (i + 1).toString(), // الرقم
                    ];
                  }),
                  headerStyle: pw.TextStyle(font: fontBold, fontSize: 11),
                  cellStyle: pw.TextStyle(font: fontRegular, fontSize: 10),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                  cellAlignment: pw.Alignment.centerRight,
                  columnWidths: const {
                    0: pw.FlexColumnWidth(2.2), // التاريخ
                    1: pw.FlexColumnWidth(1.2), // النوع
                    2: pw.FlexColumnWidth(1.2), // المبلغ
                    3: pw.FlexColumnWidth(2.2), // العميل
                    4: pw.FlexColumnWidth(1.2), // رقم العقد
                    5: pw.FixedColumnWidth(40), // الرقم
                  },
                ),

                // رسالة عند عدم وجود بيانات
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
        ],
      ),
    );

    return doc.save();
  }

  /// مشاركة نص كملف
  static Future<void> shareTextAsFile({
    required String fileName,
    required String mime,
    required String content,
  }) {
    final bytes = Uint8List.fromList(content.codeUnits);
    return shareBytesAsFile(fileName: fileName, mime: mime, bytes: bytes);
  }

  /// مشاركة بيانات بايت كملف
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
