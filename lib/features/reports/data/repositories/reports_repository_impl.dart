import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/failure.dart';
import '../../domain/entities/report_dashboard.dart';
import '../../domain/entities/payment_report.dart';

class ReportsRepository {
  ReportsRepository(this._api);

  final ApiClient _api;

  Future<ReportDashboard> dashboard({String? from, String? to}) async {
    try {
      final res = await _api.dio.get(
        'reports/dashboard',
        queryParameters: {
          if (from != null) 'from': from,
          if (to != null) 'to': to,
        },
      );

      final data = (res.data as Map).cast<String, dynamic>();
      return ReportDashboard.fromJson(data);
    } on DioException catch (e) {
      throw ApiFailure(
        e.message ?? 'Failed to load reports',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<PaymentsReport> paymentsReport({String? from, String? to, String type = 'all'}) async {
    try {
      final res = await _api.dio.get(
        'reports/payments',
        queryParameters: {
          if (from != null) 'from': from,
          if (to != null) 'to': to,
          if (type != 'all') 'type': type,
        },
      );

      final data = (res.data as Map).cast<String, dynamic>();
      return PaymentsReport.fromJson(data);
    } on DioException catch (e) {
      throw ApiFailure(
        e.message ?? 'Failed to load payments report',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
