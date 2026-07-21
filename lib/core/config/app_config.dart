import 'package:flutter/foundation.dart';

class AppConfig {
  // الرابط الديناميكي: يقرأ الرابط والمنفذ تلقائياً من شريط المتصفح في نسخة الويب
  static String get baseUrl {
    if (kIsWeb) {
      final origin = Uri.base.origin; // e.g. http://localhost or http://192.168.1.5:8080
      return "$origin/alkhair/rental_api/index.php?path=";
    }
    // احتياطي لنسخ الموبايل/الديسكتوب في حال أردت تصديرها لاحقاً
    return "http://localhost/alkhair/rental_api/index.php?path=";
  }

  /// رمز العملة المستخدم في عرض المبالغ في جميع شاشات النظام
  static const String currencySymbol = 'ر. ي';
}
