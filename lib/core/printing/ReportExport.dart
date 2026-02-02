import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle, Uint8List;

Future<Uint8List> buildPdf() async {
  final fontRegular = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
  final fontBold = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));

  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('نظام التأجير - تقرير السندات', style: pw.TextStyle(fontSize: 18, font: fontBold)),
              pw.SizedBox(height: 12),
              pw.Text('هذا نص عربي للتأكد من ظهور الخط بشكل صحيح'),
            ],
          ),
        );
      },
    ),
  );

  return doc.save();
}
