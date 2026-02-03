import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'pdf_share_impl.dart'
    if (dart.library.html) 'pdf_share_web.dart'
    as share_impl;

import '../storage/app_settings_storage.dart';
import '../../features/clients/domain/entities/models.dart' show Client;
import '../../features/payments/domain/entities/models.dart' show Payment;
import '../../features/rents/domain/entities/models.dart' show Rent;

/// PDF + Printing + Share helpers (offline).
///
/// - Generates PDF locally (no need for server PDF endpoints)
/// - Prints via native dialog
/// - Shares as a file (WhatsApp, etc.)
class PdfService {
  PdfService({AppSettingsStorage? settings, this.logoAssetPath})
    : _settings = settings ?? AppSettingsStorage();

  final AppSettingsStorage _settings;
  final String? logoAssetPath;

  Future<void> printRentContract(Rent rent) async {
    final bytes = await _buildRentContractPdf(rent);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> shareRentContract(Rent rent) async {
    final bytes = await _buildRentContractPdf(rent);
    await share_impl.PdfShare.sharePdfBytes(
      bytes: bytes,
      fileName: 'contract_${rent.id}.pdf',
      text: 'عقد تأجير #${rent.id}',
    );
  }

  Future<void> printClientStatement({
    required Client client,
    required List<Rent> rents,
    required List<Payment> payments,
    String? from,
    String? to,
  }) async {
    final bytes = await _buildClientStatementPdf(
      client: client,
      rents: rents,
      payments: payments,
      from: from,
      to: to,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> shareClientStatement({
    required Client client,
    required List<Rent> rents,
    required List<Payment> payments,
    String? from,
    String? to,
  }) async {
    final bytes = await _buildClientStatementPdf(
      client: client,
      rents: rents,
      payments: payments,
      from: from,
      to: to,
    );
   await share_impl.PdfShare.sharePdfBytes(
  bytes: bytes,
  fileName: 'statement_client_${client.id}.pdf',
  text: 'كشف حساب العميل: ${client.name}',
);

  }

  // -------------------- VOUCHER (SAND) --------------------
  Future<void> printPaymentVoucher({required Payment payment}) async {
    final bytes = await _buildPaymentVoucherPdf(payment: payment);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> sharePaymentVoucher({required Payment payment}) async {
    final bytes = await _buildPaymentVoucherPdf(payment: payment);
    await share_impl.PdfShare.sharePdfBytes(
      bytes: bytes,
      fileName: 'voucher_${payment.id ?? '0'}.pdf',
      text:
          'سند ${((payment.type ?? '').toLowerCase() == 'in') ? 'قبض' : 'صرف'} #${payment.id ?? ''}',
    );
  }

  Future<Uint8List> _buildRentContractPdf(Rent rent) async {
    final branch = await _settings.getBranchName();
    final theme = await _buildArabicTheme();
    final logo = await _tryLoadLogo();
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
        header: (ctx) => _header(
          ctx,
          title: 'عقد تأجير معدات',
          branchName: branch,
          logo: logo,
        ),
        footer: (ctx) => _footer(ctx),
        build: (_) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _kv('رقم العقد', '#${rent.id}'),
                  _kv('العميل', rent.clientName ?? rent.clientId.toString()),
                  _kv(
                    'المعدة',
                    rent.equipmentName ?? rent.equipmentId.toString(),
                  ),
                  _kv('تاريخ/وقت الخروج', rent.startDatetime),
                  _kv('تاريخ/وقت الإرجاع', rent.endDatetime ?? '-'),
                  _kv('عدد الساعات', (rent.hours ?? 0).toStringAsFixed(2)),
                  _kv(
                    'سعر الساعة',
                    '${(rent.rate ?? 0).toStringAsFixed(2)} ر.س',
                  ),
                  _kv(
                    'الإجمالي',
                    '${(rent.totalAmount ?? 0).toStringAsFixed(2)} ر.س',
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'ملاحظات:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(rent.notes ?? '-'),
                  pw.SizedBox(height: 18),
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('توقيع العميل: __________'),
                      pw.Text('توقيع الموظف: __________'),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  Future<Uint8List> _buildClientStatementPdf({
    required Client client,
    required List<Rent> rents,
    required List<Payment> payments,
    String? from,
    String? to,
  }) async {
    final branch = await _settings.getBranchName();
    final theme = await _buildArabicTheme();
    final logo = await _tryLoadLogo();
    final doc = pw.Document();

    final totalRents = rents.fold<double>(
      0,
      (a, r) => a + (r.totalAmount ?? 0),
    );
    final totalPaid = payments
        .where(
          (p) => (p.type ?? '').toLowerCase() == 'in' && (p.isVoid ?? 0) == 0,
        )
        .fold<double>(0, (a, p) => a + (p.amount ?? 0));
    final balance = totalRents - totalPaid;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
        header: (ctx) => _header(
          ctx,
          title: 'كشف حساب عميل',
          branchName: branch,
          logo: logo,
        ),
        footer: (ctx) => _footer(ctx, from: from, to: to),
        build: (_) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _kv('اسم العميل', client.name),
                  _kv('رقم العميل', client.id.toString()),
                  if (from != null || to != null)
                    _kv('الفترة', '${from ?? '-'}  ➜  ${to ?? '-'}'),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'إجمالي المستحقات: ${totalRents.toStringAsFixed(2)} ر.س',
                      ),
                      pw.Text(
                        'إجمالي المدفوع: ${totalPaid.toStringAsFixed(2)} ر.س',
                      ),
                      pw.Text('الرصيد: ${balance.toStringAsFixed(2)} ر.س'),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'العقود',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Table.fromTextArray(
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    headers: const [
                      '#',
                      'المعدة',
                      'البداية',
                      'النهاية',
                      'الإجمالي',
                    ],
                    data: [
                      for (final r in rents)
                        [
                          r.id.toString(),
                          (r.equipmentName ?? r.equipmentId.toString()),
                          r.startDatetime,
                          (r.endDatetime ?? '-'),
                          ((r.totalAmount ?? 0).toStringAsFixed(2)),
                        ],
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'المدفوعات',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Table.fromTextArray(
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    headers: const [
                      '#',
                      'التاريخ',
                      'النوع',
                      'المبلغ',
                      'الطريقة',
                      'ملاحظة',
                    ],
                    data: [
                      for (final p in payments)
                        [
                          (p.id ?? 0).toString(),
                          (p.createdAt ?? '-'),
                          ((p.type ?? '') == 'in' ? 'قبض' : 'صرف'),
                          ((p.amount ?? 0).toStringAsFixed(2)),
                          (p.method ?? '-'),
                          (p.notes ?? '-'),
                        ],
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  Future<Uint8List> _buildPaymentVoucherPdf({required Payment payment}) async {
    final branch = await _settings.getBranchName();
    final theme = await _buildArabicTheme();
    final logo = await _tryLoadLogo();

    final doc = pw.Document();
    final isIn = (payment.type ?? '').toLowerCase() == 'in';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
        header: (ctx) => _header(
          ctx,
          title: 'سند ${isIn ? 'قبض' : 'صرف'}',
          branchName: branch,
          logo: logo,
        ),
        footer: (ctx) => _footer(ctx),
        build: (_) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(12),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'رقم السند',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text('#${payment.id ?? ''}'),
                          ],
                        ),
                        pw.Divider(),
                        _kv('التاريخ', (payment.createdAt ?? '-')),
                        _kv('النوع', isIn ? 'قبض' : 'صرف'),
                        _kv(
                          'المبلغ',
                          '${(payment.amount ?? 0).toStringAsFixed(2)} ر.س',
                        ),
                        _kv('الطريقة', (payment.method ?? '-')),
                        _kv(
                          'العميل',
                          (payment.clientName ??
                              payment.clientId?.toString() ??
                              '-'),
                        ),
                        if (payment.rentId != null)
                          _kv('رقم العقد', '#${payment.rentId}'),
                        if ((payment.referenceNo ?? '').isNotEmpty)
                          _kv('مرجع', payment.referenceNo!),
                        if ((payment.notes ?? '').isNotEmpty)
                          _kv('ملاحظة', payment.notes!),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('توقيع المستلم: __________'),
                      pw.Text('توقيع الموظف: __________'),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _kv(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              k,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(v)),
        ],
      ),
    );
  }

  Future<pw.ThemeData> _buildArabicTheme() async {
    // نحاول تحميل الخط من assets، وإذا غير موجود نستخدم PdfGoogleFonts (يحتاج إنترنت).
    try {
      final reg = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
      );
      final bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
      );
      return pw.ThemeData.withFont(base: reg, bold: bold);
    } catch (_) {
      final reg = await PdfGoogleFonts.cairoRegular();
      final bold = await PdfGoogleFonts.cairoBold();
      return pw.ThemeData.withFont(base: reg, bold: bold);
    }
  }

  Future<pw.ImageProvider?> _tryLoadLogo() async {
    final path = logoAssetPath;
    if (path == null || path.isEmpty) return null;
    try {
      final bytes = await rootBundle.load(path);
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  pw.Widget _header(
    pw.Context ctx, {
    required String title,
    required String branchName,
    required pw.ImageProvider? logo,
  }) {
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
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(title, style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.Text(
              'صفحة ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _footer(pw.Context ctx, {String? from, String? to}) {
    final now = DateTime.now().toString().substring(0, 19);
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
              (from != null || to != null)
                  ? 'من: ${from ?? '-'}  إلى: ${to ?? '-'}'
                  : '',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.Text('تم الإنشاء: $now', style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ),
    );
  }
}
