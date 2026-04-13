// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

class ReportExportImpl {
  static Future<void> shareBytesAsFile({
    required String fileName,
    required String mime,
    required Uint8List bytes,
  }) async {
    final blob = html.Blob([bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final a = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.children.add(a);
    a.click();
    a.remove();
    html.Url.revokeObjectUrl(url);
  }
}