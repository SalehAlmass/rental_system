import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/failure.dart';
import '../../domain/entities/report_dashboard.dart';

class ReportsRepository {
  ReportsRepository(this._api);
  final ApiClient _api;

  Future<ReportDashboard> getDashboard() async {
    try {
      final res = await _api.dio.get('reports/dashboard');

      final data = (res.data as Map).cast<String, dynamic>();
      return ReportDashboard.fromJson(data);
    } on DioException catch (e) {
      final msg = (e.response?.data is Map &&
              e.response?.data['error'] != null)
          ? e.response?.data['error'].toString()
          : (e.message ?? 'Failed to load reports');

      throw ApiFailure(msg ?? 'Failed to load reports', statusCode: e.response?.statusCode);
    }
  }
}
