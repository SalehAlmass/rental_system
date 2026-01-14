import 'package:dio/dio.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/network/failure.dart';
import 'package:rental_app/features/dashboard/domain/entities/models.dart';

class DashboardRepository {
  DashboardRepository(this._api);
  final ApiClient _api;

  Future<DashboardStats> fetchStats() async {
    try {
      final res = await _api.dio.get('reports/dashboard');
      final data = (res.data as Map).cast<String, dynamic>();
      return DashboardStats.fromJson(data);
    } on DioException catch (e) {
      final msg = (e.response?.data is Map && (e.response?.data['error'] != null))
          ? e.response?.data['error'].toString()
          : (e.message ?? 'Failed');
      throw ApiFailure(msg ?? 'Failed', statusCode: e.response?.statusCode);
    }
  }
}
