import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Web share implementation.
///
/// On web, share_plus/path_provider aren't available.
/// We fallback to the browser download / share dialog via printing.
class PdfShare {
  static Future<void> sharePdfBytes({
    required Uint8List bytes,
    required String fileName,
    String? text, // unused on web
  }) async {
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}
