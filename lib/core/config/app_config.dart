import 'package:flutter/foundation.dart';

class AppConfig {
  // الرابط الديناميكي: يقرأ الرابط والمنفذ تلقائياً من شريط المتصفح في نسخة الويب
  static String get baseUrl {
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      final scheme = Uri.base.scheme.isNotEmpty ? Uri.base.scheme : 'http';
      return "$scheme://$host/alkhair/rental_api/index.php?path=";
    }
    // احتياطي لنسخ الموبايل/الديسكتوب. تم استبدال localhost بـ IP لأن الموبايل لا يفهم localhost.
    // يمكن للمستخدم تغييره لاحقاً من واجهة الإعدادات.
    return "http://192.168.1.100/alkhair/rental_api/index.php?path=";
  }

  /// رمز العملة المستخدم في عرض المبالغ في جميع شاشات النظام
  static const String currencySymbol = 'ر. ي';
}
