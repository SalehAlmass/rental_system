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

      final map = (res.data as Map).cast<String, dynamic>();

      // يدعم الشكل الجديد: { success, data: { ... } }
      // ويدعم الشكل القديم: { clients, equipment, open_rents, revenue }
      final payload = (map['data'] is Map)
          ? (map['data'] as Map).cast<String, dynamic>()
          : map;

      return DashboardStats.fromJson(payload);
    } on DioException catch (e) {
      final msg = (e.response?.data is Map && (e.response?.data['error'] != null))
          ? e.response?.data['error'].toString()
          : (e.message ?? 'Failed');
      throw ApiFailure(msg ?? 'Failed', statusCode: e.response?.statusCode);
    }
  }
}
