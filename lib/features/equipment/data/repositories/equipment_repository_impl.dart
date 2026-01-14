import 'package:dio/dio.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/network/failure.dart';
import 'package:rental_app/features/equipment/domain/entities/models.dart';

class EquipmentRepository {
  EquipmentRepository(this._api);
  final ApiClient _api;

  Future<List<Equipment>> list() async {
    try {
      final res = await _api.dio.get('equipment');
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

  Future<int> create({
    required String name,
    String? model,
    String? serialNo,
    String status = 'available',
    double hourlyRate = 0,
    double depreciationRate = 0,
    String? lastMaintenanceDate,
    bool isActive = true,
  }) async {
    try {
      final res = await _api.dio.post('equipment', data: {
        'name': name,
        'model': model,
        'serial_no': serialNo,
        'status': status,
        'hourly_rate': hourlyRate,
        'depreciation_rate': depreciationRate,
        'last_maintenance_date': lastMaintenanceDate,
        'is_active': isActive ? 1 : 0,
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
    double hourlyRate = 0,
    double depreciationRate = 0,
    String? lastMaintenanceDate,
    bool isActive = true,
  }) async {
    try {
      await _api.dio.put('equipment/$id', data: {
        'name': name,
        'model': model,
        'serial_no': serialNo,
        'status': status,
        'hourly_rate': hourlyRate,
        'depreciation_rate': depreciationRate,
        'last_maintenance_date': lastMaintenanceDate,
        'is_active': isActive ? 1 : 0,
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
