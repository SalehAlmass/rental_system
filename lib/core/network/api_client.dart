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
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
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
          // ✅ طباعة تفاصيل الخطأ عشان نعرف السبب الحقيقي
          final status = e.response?.statusCode;
          final data = e.response?.data;
          // ignore: avoid_print
          print('DIO ERROR => ${e.requestOptions.method} ${e.requestOptions.uri}');
          // ignore: avoid_print
          print('STATUS => $status');
          // ignore: avoid_print
          print('DATA => $data');
          // ignore: avoid_print
          print('MESSAGE => ${e.message}');
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
