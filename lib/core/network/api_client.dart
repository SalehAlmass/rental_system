import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../storage/base_url_storage.dart';
import '../storage/token_storage.dart';

class ApiClient {
  ApiClient(this._tokenStorage, {BaseUrlStorage? baseUrlStorage})
      : _baseUrlStorage = baseUrlStorage ?? BaseUrlStorage() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: kIsWeb ? null : const Duration(seconds: 45),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
            // Allow changing baseUrl from Settings without rebuilding the app.
          // We override per-request to keep it simple.
          final baseUrl = await _baseUrlStorage.getBaseUrl();
          options.baseUrl = baseUrl;

          final token = await _tokenStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (e, handler) {
          final status = e.response?.statusCode;
          final data = e.response?.data;
          
          // ✅ 1. Logging آمن للإنتاج (لا يُحذف في Release)
          developer.log(
            'API ERROR: ${e.requestOptions.method} ${e.requestOptions.uri}',
            name: 'ApiClient',
            error: e.error,
          );
          if (status != null) {
            developer.log('STATUS: $status', name: 'ApiClient');
          }
          if (data != null) {
            developer.log('DATA: $data', name: 'ApiClient');
          }

          // ✅ 2. مسح الجلسة في حالة 401
          if (status == 401) {
            _tokenStorage.clear(); // إجبار التطبيق على مسح التوكن لحماية الجلسة
          }

          // ✅ 3. ترجمة الأخطاء وتصنيفها
          String? customMessage;
          switch (e.type) {
            case DioExceptionType.connectionTimeout:
            case DioExceptionType.sendTimeout:
            case DioExceptionType.receiveTimeout:
              customMessage = 'انتهى وقت الاتصال بالخادم، يرجى المحاولة لاحقاً';
              break;
            case DioExceptionType.connectionError:
              customMessage = 'لا يوجد اتصال بالإنترنت (تأكد من الشبكة)';
              break;
            case DioExceptionType.badResponse:
              if (status == 401) {
                customMessage = 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً';
              } else if (status == 403) {
                customMessage = 'لا تملك صلاحية لإجراء هذه العملية';
              } else if (status == 404) {
                customMessage = 'البيانات المطلوبة غير موجودة';
              } else if (status != null && status >= 500) {
                customMessage = 'حدث خطأ داخلي في الخادم ($status)';
              }
              break;
            case DioExceptionType.cancel:
              customMessage = 'تم إلغاء الطلب';
              break;
            default:
              customMessage = 'حدث خطأ غير متوقع في الاتصال';
              break;
          }

          // إذا لم يرسل الـ Backend رسالة خطأ صريحة كـ JSON (مثل حالة 500 HTML)
          // نستبدل رسالة النظام المعقدة برسالتنا العربية المترجمة.
          if (customMessage != null && (data == null || data is! Map || data['error'] == null)) {
            final modifiedException = DioException(
              requestOptions: e.requestOptions,
              response: e.response,
              type: e.type,
              error: e.error,
              message: customMessage,
            );
            return handler.next(modifiedException);
          }

          return handler.next(e);
        },
      ),
    );
  }

  late final Dio _dio;
  final TokenStorage _tokenStorage;
  final BaseUrlStorage _baseUrlStorage;

  Dio get dio => _dio;
}
