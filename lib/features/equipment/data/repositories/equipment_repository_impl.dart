import 'package:dio/dio.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/network/failure.dart';
import 'package:rental_app/features/equipment/domain/entities/models.dart';

class EquipmentRepository {
  EquipmentRepository(this._api);
  final ApiClient _api;

  Future<List<Equipment>> list({String? query, String? status, int? page, int? perPage, String? sortBy, String? sortOrder}) async {
    try {
      final res = await _api.dio.get(
        'equipment',
        queryParameters: {
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          if (status != null && status.isNotEmpty) 'status': status,
          if (page != null) 'page': page,
          if (perPage != null) 'per_page': perPage,
          if (sortBy != null) 'sort_by': sortBy,
          if (sortOrder != null) 'sort_order': sortOrder,
        },
      );
      dynamic raw = res.data;
      if (raw is Map) raw = raw['data'] ?? raw['items'] ?? raw['equipment'] ?? [];
      if (raw is! List) throw ApiFailure('Unexpected response: ${res.data}');
      return raw.map((e) => Equipment.fromJson((e as Map).cast<String, dynamic>())).toList();
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null) ? data['error'].toString() : (e.message ?? 'Failed');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<Equipment> getById(int id) async {
    try {
      final res = await _api.dio.get('equipment/$id');
      dynamic raw = res.data;
      if (raw is Map) {
        final data = raw['data'] ?? raw;
        return Equipment.fromJson((data as Map).cast<String, dynamic>());
      }
      throw ApiFailure('Unexpected response: ${res.data}');
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null) ? data['error'].toString() : (e.message ?? 'Failed');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<int> create({
    required String name,
    String? model,
    String? serialNo,
    String status = 'available',
    double dailyRate = 0,
    double depreciationRate = 0,
    String? lastMaintenanceDate,
    bool isActive = true,
    double purchasePrice = 0,
    double salvageValue = 0,
    int usefulLifeMonths = 60,
    String? depreciationStartDate,
    int estimatedUsageDays = 365,
    int seriesCount = 1,
  }) async {
    try {
      final res = await _api.dio.post('equipment', data: {
        'name': name,
        'model': model,
        'serial_no': serialNo,
        'status': status,
        'daily_rate': dailyRate,
        'hourly_rate': dailyRate,
        'depreciation_rate': depreciationRate,
        'last_maintenance_date': lastMaintenanceDate,
        'is_active': isActive ? 1 : 0,
        'purchase_price': purchasePrice,
        'salvage_value': salvageValue,
        'useful_life_months': usefulLifeMonths,
        'depreciation_start_date': depreciationStartDate,
        'estimated_usage_days': estimatedUsageDays,
        'series_count': seriesCount < 1 ? 1 : seriesCount,
      });
      final data = (res.data is Map) ? (res.data as Map).cast<String, dynamic>() : <String, dynamic>{};
      final rawId = data['id'];
      final id = (rawId is num) ? rawId.toInt() : int.tryParse(rawId.toString()) ?? 0;
      if (id <= 0) throw ApiFailure('Invalid id returned: $rawId');
      return id;
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null) ? data['error'].toString() : (e.message ?? 'Failed');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<void> update({
    required int id,
    required String name,
    String? model,
    String? serialNo,
    String status = 'available',
    double dailyRate = 0,
    double depreciationRate = 0,
    String? lastMaintenanceDate,
    bool isActive = true,
    double purchasePrice = 0,
    double salvageValue = 0,
    int usefulLifeMonths = 60,
    String? depreciationStartDate,
    int estimatedUsageDays = 365,
    int seriesCount = 1,
  }) async {
    try {
      await _api.dio.put('equipment/$id', data: {
        'name': name,
        'model': model,
        'serial_no': serialNo,
        'status': status,
        'daily_rate': dailyRate,
        'hourly_rate': dailyRate,
        'depreciation_rate': depreciationRate,
        'last_maintenance_date': lastMaintenanceDate,
        'is_active': isActive ? 1 : 0,
        'purchase_price': purchasePrice,
        'salvage_value': salvageValue,
        'useful_life_months': usefulLifeMonths,
        'depreciation_start_date': depreciationStartDate,
        'estimated_usage_days': estimatedUsageDays,
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null) ? data['error'].toString() : (e.message ?? 'Failed');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _api.dio.delete('equipment/$id');
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null) ? data['error'].toString() : (e.message ?? 'Failed');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }
}
