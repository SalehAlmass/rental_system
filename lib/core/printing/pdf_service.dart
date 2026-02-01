import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

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
  PdfService({AppSettingsStorage? settings}) : _settings = settings ?? AppSettingsStorage();

  final AppSettingsStorage _settings;

  Future<void> printRentContract(Rent rent) async {
    final bytes = await _buildRentContractPdf(rent);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> shareRentContract(Rent rent) async {
    final bytes = await _buildRentContractPdf(rent);
    final file = await _saveTempFile(bytes, 'contract_${rent.id}.pdf');
    await Share.shareXFiles([XFile(file.path)], text: 'عقد تأجير #${rent.id}');
  }

  Future<void> printClientStatement({
    required Client client,
    required List<Rent> rents,
    required List<Payment> payments,
    String? from,
    String? to,
  }) async {
    final bytes = await _buildClientStatementPdf(client: client, rents: rents, payments: payments, from: from, to: to);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> shareClientStatement({
    required Client client,
    required List<Rent> rents,
    required List<Payment> payments,
    String? from,
    String? to,
  }) async {
    final bytes = await _buildClientStatementPdf(client: client, rents: rents, payments: payments, from: from, to: to);
    final file = await _saveTempFile(bytes, 'statement_client_${client.id}.pdf');
    await Share.shareXFiles([XFile(file.path)], text: 'كشف حساب العميل: ${client.name}');
  }

  Future<Uint8List> _buildRentContractPdf(Rent rent) async {
    final branch = await _settings.getBranchName();
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(branch, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('عقد تأجير معدات', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
                _kv('رقم العقد', '#${rent.id}'),
                _kv('العميل', rent.clientName ?? rent.clientId.toString()),
                _kv('المعدة', rent.equipmentName ?? rent.equipmentId.toString()),
                _kv('تاريخ/وقت الخروج', rent.startDatetime),
                _kv('تاريخ/وقت الإرجاع', rent.endDatetime ?? '-'),
                _kv('عدد الساعات', (rent.hours ?? 0).toStringAsFixed(2)),
                _kv('سعر الساعة', '${(rent.rate ?? 0).toStringAsFixed(2)} ر.س'),
                _kv('الإجمالي', '${(rent.totalAmount ?? 0).toStringAsFixed(2)} ر.س'),
                pw.SizedBox(height: 10),
                pw.Text('ملاحظات:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(rent.notes ?? '-'),
                pw.Spacer(),
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
          );
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
    final doc = pw.Document();

    final totalRents = rents.fold<double>(0, (a, r) => a + (r.totalAmount ?? 0));
    final totalPaid = payments
        .where((p) => (p.type ?? '').toLowerCase() == 'in' && (p.isVoid ?? 0) == 0)
        .fold<double>(0, (a, p) => a + (p.amount ?? 0));
    final balance = totalRents - totalPaid;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text(branch, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Text('كشف حساب عميل', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(),
                  _kv('اسم العميل', client.name),
                  _kv('رقم العميل', client.id.toString()),
                  if (from != null || to != null) _kv('الفترة', '${from ?? '-'}  ➜  ${to ?? '-'}'),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('إجمالي المستحقات: ${totalRents.toStringAsFixed(2)} ر.س'),
                      pw.Text('إجمالي المدفوع: ${totalPaid.toStringAsFixed(2)} ر.س'),
                      pw.Text('الرصيد: ${balance.toStringAsFixed(2)} ر.س'),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text('العقود', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Table.fromTextArray(
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    headers: const ['#', 'المعدة', 'البداية', 'النهاية', 'الإجمالي'],
                    data: [
                      for (final r in rents)
                        [
                          r.id.toString(),
                          (r.equipmentName ?? r.equipmentId.toString()),
                          r.startDatetime,
                          (r.endDatetime ?? '-'),
                          ((r.totalAmount ?? 0).toStringAsFixed(2)),
                        ]
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text('المدفوعات', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Table.fromTextArray(
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    headers: const ['#', 'التاريخ', 'النوع', 'المبلغ', 'الطريقة', 'ملاحظة'],
                    data: [
                      for (final p in payments)
                        [
                          (p.id ?? 0).toString(),
                          (p.createdAt ?? '-'),
                          ((p.type ?? '') == 'in' ? 'قبض' : 'صرف'),
                          ((p.amount ?? 0).toStringAsFixed(2)),
                          (p.method ?? '-'),
                          (p.notes ?? '-'),
                        ]
                    ],
                  ),
                ],
              ),
            )
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
          pw.SizedBox(width: 140, child: pw.Text(k, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(child: pw.Text(v)),
        ],
      ),
    );
  }

  Future<File> _saveTempFile(Uint8List bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
