import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {
  PdfService(this.branchName);

  final String branchName;
  final _fmt = NumberFormat.currency(symbol: 'ر.س');

  Future<Uint8List> simpleTable({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text(branchName, style: pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 6),
          pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: headers,
            data: rows,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            border: pw.TableBorder.all(),
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<Uint8List> buildClientStatementPdf({
    required Map<String, dynamic> client,
    required Map<String, dynamic> totals,
    required List<Map<String, dynamic>> rents,
    required List<Map<String, dynamic>> payments,
    String? from,
    String? to,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(branchName, style: pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 6),
          pw.Text('كشف حساب عميل', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),

          // Client Info
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('العميل: ${client['name']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('الهاتف: ${client['phone'] ?? '-'}'),
                pw.Text('العنوان: ${client['address'] ?? '-'}'),
                pw.Text('الرقم: ${client['id']}'),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // Statement period if provided
          if (from != null || to != null)
            pw.Text('الفترة: ${from ?? ''} إلى ${to ?? ''}', style: pw.TextStyle(fontSize: 12)),

          pw.SizedBox(height: 12),

          // Rents table
          pw.Text('الإيجارات', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: ['التاريخ', 'رقم العقد', 'المبلغ'],
            data: rents.map((rent) => [
              rent['date'] ?? '',
              rent['id'].toString(),
              _fmt.format(rent['total_amount'] ?? 0),
            ]).toList(),
            border: pw.TableBorder.all(),
          ),

          pw.SizedBox(height: 12),

          // Payments table
          pw.Text('الدفعات', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: ['التاريخ', 'المبلغ', 'طريقة الدفع'],
            data: payments.map((payment) => [
              payment['created_at'] ?? '',
              _fmt.format(payment['amount'] ?? 0),
              payment['method'] ?? '',
            ]).toList(),
            border: pw.TableBorder.all(),
          ),

          pw.SizedBox(height: 12),

          // Totals
          pw.Expanded(
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('الإجمالي', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(_fmt.format(totals['total'] ?? 0), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<Uint8List> buildRentContractPdf({
    required Map<String, dynamic> rent,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> payments,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(branchName, style: pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 6),
          pw.Text('عقد إيجار معدة', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),

          // Contract Info
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('رقم العقد: ${rent['id']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('اسم العميل: ${rent['client_name'] ?? rent['client_id']}'),
                pw.Text('اسم المعدة: ${rent['equipment_name'] ?? rent['equipment_id']}'),
                pw.Text('تاريخ البدء: ${rent['start_datetime']}'),
                pw.Text('تاريخ الانتهاء: ${rent['end_datetime'] ?? 'لم يتم تحديد'}'),
                pw.Text('المبلغ الإجمالي: ${_fmt.format(rent['total_amount'] ?? 0)}'),
                pw.Text('الحالة: ${rent['status'] ?? 'غير معروفة'}'),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // Items table
          if (items.isNotEmpty) ...[
            pw.Text('البنود', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              headers: ['الوصف', 'الكمية', 'السعر', 'الإجمالي'],
              data: items.map((item) => [
                item['description'] ?? '',
                item['quantity'].toString(),
                _fmt.format(item['unit_price'] ?? 0),
                _fmt.format(item['total'] ?? 0),
              ]).toList(),
              border: pw.TableBorder.all(),
            ),
            pw.SizedBox(height: 12),
          ],

          // Payments table
          if (payments.isNotEmpty) ...[
            pw.Text('الدفعات', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              headers: ['التاريخ', 'المبلغ', 'طريقة الدفع'],
              data: payments.map((payment) => [
                payment['created_at'] ?? '',
                _fmt.format(payment['amount'] ?? 0),
                payment['method'] ?? '',
              ]).toList(),
              border: pw.TableBorder.all(),
            ),
            pw.SizedBox(height: 12),
          ],

          // Notes
          if (rent['notes'] != null && rent['notes'].toString().isNotEmpty) ...[
            pw.Text('ملاحظات', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text(rent['notes'].toString()),
            pw.SizedBox(height: 12),
          ],
        ],
      ),
    );

    return doc.save();
  }
}
