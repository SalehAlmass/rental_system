import 'package:dio/dio.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/network/failure.dart';
import 'package:rental_app/features/dashboard/domain/entities/models.dart';
import 'package:rental_app/features/rents/domain/entities/models.dart';

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

  Future<List<Rent>> fetchRecentRents({int limit = 10}) async {
    try {
      final res = await _api.dio.get('rents', queryParameters: {'limit': limit});
      dynamic raw = res.data;
      // API may return either a raw list or wrapped
      if (raw is Map) raw = raw['data'] ?? raw['items'] ?? raw['rents'] ?? [];
      if (raw is! List) return const [];
      return raw
          .map((e) => Rent.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      final msg = (e.response?.data is Map && (e.response?.data['error'] != null))
          ? e.response?.data['error'].toString()
          : (e.message ?? 'Failed');
      throw ApiFailure(msg ?? 'Failed', statusCode: e.response?.statusCode);
    }
  }
}
