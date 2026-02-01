import 'package:dio/dio.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/network/failure.dart';
import 'package:rental_app/features/clients/domain/entities/models.dart';

class ClientsRepository {
  ClientsRepository(this._api);
  final ApiClient _api;

  Future<List<Client>> list() async {
    try {
      final res = await _api.dio.get('clients');
      dynamic raw = res.data;
      if (raw is Map) raw = raw['data'] ?? raw['items'] ?? raw['clients'] ?? [];
      if (raw is! List) throw ApiFailure('Unexpected response: ${res.data}');
      return raw.map((e) => Client.fromJson((e as Map).cast<String, dynamic>())).toList();
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null) ? data['error'].toString() : (e.message ?? 'Failed to load clients');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<int> create({
    required String name,
    String? nationalId,
    String? phone,
    String? address,
    double creditLimit = 0,
    int isFrozen = 0,
  }) async {
    try {
      final res = await _api.dio.post('clients', data: {
        'name': name,
        'national_id': nationalId,
        'phone': phone,
        'address': address,
        'credit_limit': creditLimit,
        'is_frozen': isFrozen,
      });
      final data = (res.data is Map) ? (res.data as Map).cast<String, dynamic>() : <String, dynamic>{};
      final rawId = data['id'];
      final id = (rawId is num) ? rawId.toInt() : int.tryParse(rawId.toString()) ?? 0;
      if (id <= 0) throw ApiFailure('Invalid id returned: $rawId');
      return id;
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null) ? data['error'].toString() : (e.message ?? 'Failed to create client');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<void> update({
    required int id,
    required String name,
    String? nationalId,
    String? phone,
    String? address,
    double creditLimit = 0,
    int isFrozen = 0,
  }) async {
    try {
      await _api.dio.put('clients/$id', data: {
        'name': name,
        'national_id': nationalId,
        'phone': phone,
        'address': address,
        'credit_limit': creditLimit,
        'is_frozen': isFrozen,
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null) ? data['error'].toString() : (e.message ?? 'Failed to update client');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _api.dio.delete('clients/$id');
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null) ? data['error'].toString() : (e.message ?? 'Failed to delete client');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }
}
