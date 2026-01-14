import 'package:dio/dio.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/network/failure.dart';
import 'package:rental_app/features/rents/domain/entities/models.dart';

class RentsRepository {
  RentsRepository(this._api);
  final ApiClient _api;

  Future<List<Rent>> list() async {
    try {
      final res = await _api.dio.get('rents');
      dynamic raw = res.data;
      if (raw is Map) raw = raw['data'] ?? raw['items'] ?? raw['rents'] ?? [];
      if (raw is! List) throw ApiFailure("Unexpected response: ${res.data}");
      return raw.map((e) => Rent.fromJson((e as Map).cast<String, dynamic>())).toList();
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null) ? data['error'].toString() : (e.message ?? 'Failed to load rents');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<int> openRent({
    required int clientId,
    required int equipmentId,
    required String startDatetime, // "YYYY-MM-DD HH:MM:SS"
    double hourlyRate = 0,
    String? notes,
  }) async {
    try {
      final res = await _api.dio.post('rents', data: {
        'client_id': clientId,
        'equipment_id': equipmentId,
        'start_datetime': startDatetime,
        if (hourlyRate > 0) 'rate': hourlyRate,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      });
      final data = (res.data is Map) ? (res.data as Map).cast<String, dynamic>() : {};
      final rawId = data['id'];
      final id = (rawId is num) ? rawId.toInt() : int.tryParse(rawId.toString()) ?? 0;
      if (id <= 0) throw ApiFailure("Open rent: invalid id returned: $rawId");
      return id;
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null) ? data['error'].toString() : (e.message ?? 'Failed to open rent');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<void> updateNotes({required int rentId, required String notes}) async {
    try {
      await _api.dio.put('rents/$rentId', data: {'notes': notes});
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null) ? data['error'].toString() : (e.message ?? 'Failed to update rent');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<void> closeRent({required int rentId, required String endDatetime}) async {
    try {
      await _api.dio.post('rents/$rentId/close', data: {'end_datetime': endDatetime});
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null) ? data['error'].toString() : (e.message ?? 'Failed to close rent');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<void> cancelRent({required int rentId, String? reason}) async {
    try {
      await _api.dio.post('rents/$rentId/cancel', data: {'reason': reason});
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null) ? data['error'].toString() : (e.message ?? 'Failed to cancel rent');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }
}
