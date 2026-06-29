import 'dart:typed_data';
import 'package:flutter/material.dart' show BuildContext, ScaffoldMessenger, SnackBar, Text;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/financial_reports.dart';
import '../../domain/entities/payment_report.dart';
import 'report_export_impl.dart'
    if (dart.library.html) 'report_export_web.dart';

class ReportExport {
  /// توليد CSV من تقرير الدفعات
  static String toPaymentsCsv(PaymentsReport report) {
    final buffer = StringBuffer();
    buffer.writeln('ID,Date,Type,Amount,Method,Client,Rent,Reference,Notes');

    for (final r in report.rows) {
      String safe(String? s) => (s ?? '').replaceAll('"', '""');
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

  // ─────────────────────────────────────────────────────────────────────────
  //  Phase 7: Financial Report PDF Exports
  // ─────────────────────────────────────────────────────────────────────────

  static Future<pw.Font> _loadFont(String asset, Future<pw.Font> Function() fallback) async {
    try {
      return pw.Font.ttf(await rootBundle.load(asset));
    } catch (_) {
      return fallback();
    }
  }

  static Future<Map<String, pw.Font>> _loadFonts() async {
    return {
      'regular': await _loadFont('assets/fonts/Cairo-Regular.ttf', PdfGoogleFonts.cairoRegular),
      'bold':    await _loadFont('assets/fonts/Cairo-Bold.ttf', PdfGoogleFonts.cairoBold),
    };
  }

  static pw.Widget _pdfHeader(pw.Font fontBold, String title, {String? subtitle}) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
      pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.indigo700), textDirection: pw.TextDirection.rtl),
      if (subtitle != null)
        pw.Text(subtitle, style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.grey600), textDirection: pw.TextDirection.rtl),
      pw.SizedBox(height: 6),
      pw.Divider(color: PdfColors.indigo200),
      pw.SizedBox(height: 8),
    ]);
  }

  static pw.Widget _pdfRow(pw.Font fontRegular, String label, String value, {PdfColor? valueColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(value, style: pw.TextStyle(font: fontRegular, color: valueColor ?? PdfColors.black, fontSize: 12), textDirection: pw.TextDirection.rtl),
        pw.Text(label, style: pw.TextStyle(font: fontRegular, fontSize: 12), textDirection: pw.TextDirection.rtl),
      ]),
    );
  }

  static pw.Widget _pdfSection(pw.Font fontBold, pw.Font fontRegular, String title, List<pw.Widget> rows) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
      child: pw.Column(children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          color: PdfColors.indigo50,
          child: pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 13), textDirection: pw.TextDirection.rtl),
        ),
        pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Column(children: rows)),
      ]),
    );
  }

  static final _pdfFmt = NumberFormat('#,##0.00');
  static String _fmtPdf(double v) => '${_pdfFmt.format(v)} ر.س';

  /// Export Financial Summary PDF
  static Future<void> exportFinancialSummary(BuildContext context, FinancialSummary d, {String? from, String? to}) async {
    try {
      final fonts = await _loadFonts();
      final fb = fonts['bold']!;
      final fr = fonts['regular']!;
      final period = '${from ?? ''} — ${to ?? ''}';

      final doc = pw.Document();
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _pdfHeader(fb, 'الملخص المالي', subtitle: period),
          _pdfSection(fb, fr, 'الإيرادات', [
            _pdfRow(fr, 'إيرادات الإيجار', _fmtPdf(d.rentalRevenue), valueColor: PdfColors.green700),
            _pdfRow(fr, 'إيرادات أخرى', _fmtPdf(d.otherRevenue), valueColor: PdfColors.green600),
            _pdfRow(fr, 'إجمالي الإيرادات', _fmtPdf(d.totalRevenue), valueColor: PdfColors.green800),
          ]),
          _pdfSection(fb, fr, 'المصروفات', [
            _pdfRow(fr, 'الصيانة', _fmtPdf(d.maintenanceExpenses), valueColor: PdfColors.orange700),
            _pdfRow(fr, 'الرواتب', _fmtPdf(d.payrollExpenses), valueColor: PdfColors.orange700),
            _pdfRow(fr, 'الاستهلاك', _fmtPdf(d.depreciationExpenses), valueColor: PdfColors.orange700),
            _pdfRow(fr, 'مصروفات تشغيلية', _fmtPdf(d.operationalExpenses), valueColor: PdfColors.orange700),
            _pdfRow(fr, 'إجمالي المصروفات', _fmtPdf(d.totalExpenses), valueColor: PdfColors.red700),
          ]),
          _pdfSection(fb, fr, 'مؤشرات الربحية', [
            _pdfRow(fr, 'الربح الإجمالي', _fmtPdf(d.grossProfit), valueColor: d.grossProfit >= 0 ? PdfColors.green700 : PdfColors.red700),
            _pdfRow(fr, 'الربح التشغيلي', _fmtPdf(d.operatingProfit), valueColor: d.operatingProfit >= 0 ? PdfColors.green700 : PdfColors.red700),
            _pdfRow(fr, 'صافي الربح', _fmtPdf(d.netProfit), valueColor: d.netProfit >= 0 ? PdfColors.green800 : PdfColors.red800),
            _pdfRow(fr, 'هامش الربح', '${d.profitMarginPct.toStringAsFixed(1)}%'),
            _pdfRow(fr, 'المستحقات غير المسددة', _fmtPdf(d.outstandingAmount), valueColor: PdfColors.orange700),
            _pdfRow(fr, 'قيمة الأصول الإجمالية', _fmtPdf(d.totalAssetValue)),
          ]),
        ]),
      ));

      final bytes = await doc.save();
      await shareBytesAsFile(fileName: 'financial_summary_${from ?? 'all'}.pdf', mime: 'application/pdf', bytes: bytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  /// Export Profit & Loss PDF
  static Future<void> exportProfitLoss(BuildContext context, ProfitLoss d, {String? from, String? to}) async {
    try {
      final fonts = await _loadFonts();
      final fb = fonts['bold']!;
      final fr = fonts['regular']!;

      final doc = pw.Document();
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _pdfHeader(fb, 'قائمة الأرباح والخسائر', subtitle: '${from ?? ''} — ${to ?? ''}'),
          _pdfSection(fb, fr, 'الإيرادات', [
            _pdfRow(fr, 'إيرادات الإيجار', _fmtPdf(d.rentalRevenue), valueColor: PdfColors.green700),
            _pdfRow(fr, 'إيرادات أخرى', _fmtPdf(d.otherRevenue), valueColor: PdfColors.green700),
            _pdfRow(fr, 'إجمالي الإيرادات', _fmtPdf(d.totalRevenue), valueColor: PdfColors.green800),
          ]),
          _pdfSection(fb, fr, 'تكلفة الإيرادات', [
            _pdfRow(fr, 'الصيانة', _fmtPdf(d.maintenanceCost), valueColor: PdfColors.orange700),
            _pdfRow(fr, 'الاستهلاك', _fmtPdf(d.depreciationCost), valueColor: PdfColors.orange700),
            _pdfRow(fr, 'إجمالي تكلفة الإيرادات', _fmtPdf(d.totalCost), valueColor: PdfColors.red700),
          ]),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            color: PdfColors.green50,
            child: _pdfRow(fr, 'الربح الإجمالي', _fmtPdf(d.grossProfit), valueColor: d.grossProfit >= 0 ? PdfColors.green800 : PdfColors.red800),
          ),
          pw.SizedBox(height: 8),
          _pdfSection(fb, fr, 'المصروفات التشغيلية', [
            _pdfRow(fr, 'الرواتب والأجور', _fmtPdf(d.payrollExpense), valueColor: PdfColors.orange700),
            _pdfRow(fr, 'مصروفات أخرى', _fmtPdf(d.otherExpenses), valueColor: PdfColors.orange700),
            _pdfRow(fr, 'إجمالي المصروفات التشغيلية', _fmtPdf(d.totalOperating), valueColor: PdfColors.red700),
          ]),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            color: d.netProfit >= 0 ? PdfColors.green100 : PdfColors.red100,
            child: _pdfRow(fr, 'صافي الربح', _fmtPdf(d.netProfit), valueColor: d.netProfit >= 0 ? PdfColors.green800 : PdfColors.red800),
          ),
        ]),
      ));

      final bytes = await doc.save();
      await shareBytesAsFile(fileName: 'profit_loss_${from ?? 'all'}.pdf', mime: 'application/pdf', bytes: bytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  /// Export Cash Flow PDF
  static Future<void> exportCashFlow(BuildContext context, CashFlow d, {String? from, String? to}) async {
    try {
      final fonts = await _loadFonts();
      final fb = fonts['bold']!;
      final fr = fonts['regular']!;

      final doc = pw.Document();
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _pdfHeader(fb, 'تقرير التدفقات النقدية', subtitle: '${from ?? ''} — ${to ?? ''}'),
          _pdfRow(fr, 'الرصيد الافتتاحي', _fmtPdf(d.openingBalance)),
          pw.SizedBox(height: 10),
          _pdfSection(fb, fr, 'التدفقات الداخلة', [
            _pdfRow(fr, 'نقداً', _fmtPdf(d.cashIn), valueColor: PdfColors.green700),
            _pdfRow(fr, 'تحويل بنكي', _fmtPdf(d.transferIn), valueColor: PdfColors.green700),
            _pdfRow(fr, 'إجمالي التدفقات الداخلة', _fmtPdf(d.totalCashIn), valueColor: PdfColors.green800),
          ]),
          _pdfSection(fb, fr, 'التدفقات الخارجة', [
            _pdfRow(fr, 'نقداً', _fmtPdf(d.cashOut), valueColor: PdfColors.red600),
            _pdfRow(fr, 'تحويل بنكي', _fmtPdf(d.transferOut), valueColor: PdfColors.red600),
            _pdfRow(fr, 'صيانة', _fmtPdf(d.maintenanceCashOut), valueColor: PdfColors.orange700),
            _pdfRow(fr, 'إجمالي التدفقات الخارجة', _fmtPdf(d.totalCashOut), valueColor: PdfColors.red800),
          ]),
          _pdfRow(fr, 'صافي الحركة', _fmtPdf(d.netMovement), valueColor: d.netMovement >= 0 ? PdfColors.green700 : PdfColors.red700),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            color: PdfColors.indigo50,
            child: _pdfRow(fb, 'الرصيد الختامي', _fmtPdf(d.closingBalance), valueColor: d.closingBalance >= 0 ? PdfColors.green800 : PdfColors.red800),
          ),
        ]),
      ));

      final bytes = await doc.save();
      await shareBytesAsFile(fileName: 'cash_flow_${from ?? 'all'}.pdf', mime: 'application/pdf', bytes: bytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  /// Export Employee Performance PDF
  static Future<void> exportEmployeePerformance(BuildContext context, List<EmployeePerformanceRow> rows, {String? from, String? to}) async {
    try {
      final fonts = await _loadFonts();
      final fb = fonts['bold']!;
      final fr = fonts['regular']!;

      final doc = pw.Document();
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (ctx) => [
          _pdfHeader(fb, 'تقرير أداء الموظفين', subtitle: '${from ?? ''} — ${to ?? ''}'),
          pw.Table.fromTextArray(
            headers: ['الموظف', 'الإيصالات', 'الإجمالي', 'العقود', 'قيمة العقود', 'متوسط المعاملة'],
            data: rows.map((r) => [
              r.username,
              '${r.receiptsCount}',
              _fmtPdf(r.totalCollected),
              '${r.contractsCreated}',
              _fmtPdf(r.totalContractValue),
              _fmtPdf(r.avgTransactionValue),
            ]).toList(),
            headerStyle: pw.TextStyle(font: fb, fontSize: 11, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
            cellStyle: pw.TextStyle(font: fr, fontSize: 10),
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.indigo50),
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: PdfColors.grey300),
            ),
          ),
        ],
      ));

      final bytes = await doc.save();
      await shareBytesAsFile(fileName: 'employee_performance_${from ?? 'all'}.pdf', mime: 'application/pdf', bytes: bytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }
}
