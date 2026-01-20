import 'package:dio/dio.dart';
import 'package:rental_app/core/network/failure.dart';

class PaymentsReportRepository {
  final Dio dio;
  PaymentsReportRepository(this.dio);

  Future<Map<String, dynamic>> fetchPaymentsReport({
    String? from,
    String? to,
    String type = 'all',
    int includeVoid = 0,
  }) async {
    try {
      final res = await dio.get(
        'reports/payments',
        queryParameters: {
          if (from != null) 'from': from,
          if (to != null) 'to': to,
          'type': type,
          'include_void': includeVoid,
        },
      );

      final map = (res.data as Map).cast<String, dynamic>();
      return map;
    } on DioException catch (e) {
      final msg = (e.response?.data is Map && e.response?.data['error'] != null)
          ? e.response?.data['error'].toString()
          : (e.message ?? 'Failed to load report');

      throw ApiFailure(msg ?? '', statusCode: e.response?.statusCode);
    }
  }
}
