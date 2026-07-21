import 'package:dio/dio.dart';

class ApiFailure implements Exception {
  ApiFailure(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;

  factory ApiFailure.fromDio(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    
    String msg = 'حدث خطأ غير متوقع';

    // 1. إذا كان الـ Interceptor قد أرسل رسالة مترجمة ولا يوجد رد من الخادم (مثل Network Error)
    if (e.response == null && e.message != null) {
      msg = e.message!;
    } 
    // 2. إذا كان الخادم قد أرجع رسالة JSON صريحة
    else if (data is Map && data['error'] != null) {
      msg = data['error'].toString();
    } 
    // 3. إذا انهار الخادم وأرجع صفحة HTML (مثل خطأ 500)
    else if (data is String && data.toLowerCase().contains('<html')) {
      msg = 'حدث خطأ داخلي في الخادم ($status)';
    } 
    // 4. الحالات الأخرى
    else {
      msg = e.message ?? 'تعذر الاتصال بالخادم';
    }

    return ApiFailure(msg, statusCode: status);
  }
}
