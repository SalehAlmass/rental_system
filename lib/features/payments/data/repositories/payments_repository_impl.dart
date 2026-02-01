import 'package:dio/dio.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/network/failure.dart';
import 'package:rental_app/features/payments/domain/entities/models.dart';

class PaymentsRepository {
  PaymentsRepository(this._api);
  final ApiClient _api;

  // تعديل: إضافة clientId كـ parameter اختياري
  Future<List<Payment>> list({int? clientId, bool showVoided = false}) async {
    try {
      final res = await _api.dio.get(
        'payments',
        queryParameters: {
          if (clientId != null) 'client_id': clientId,
          'show_void': showVoided ? 1 : 0,
        },
      );

      dynamic raw = res.data;
      if (raw is Map) raw = raw['data'] ?? raw['items'] ?? raw['payments'] ?? [];
      if (raw is! List) throw ApiFailure("Unexpected response: ${res.data}");

      return raw
          .map((e) => Payment.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Failed to load payments');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  // باقي الدوال كما هي
  Future<int> create({
    required String type, // in|out
    required double amount,
    int? clientId,
    int? rentId,
    String method = 'cash',
    String? referenceNo,
    String? notes,
  }) async {
    try {
      final res = await _api.dio.post('payments', data: {
        'type': type,
        'amount': amount,
        'client_id': clientId,
        'rent_id': rentId,
        'method': method,
        'reference_no': referenceNo,
        'notes': notes,
      });
      final data = (res.data is Map) ? (res.data as Map).cast<String, dynamic>() : {};
      final rawId = data['id'];
      final id = (rawId is num) ? rawId.toInt() : int.tryParse(rawId.toString()) ?? 0;
      if (id <= 0) throw ApiFailure("Create payment: invalid id returned: $rawId");
      return id;
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Failed to create payment');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<void> update({
    required int id,
    required double amount,
    int? clientId,
    int? rentId,
    String method = 'cash',
    String? referenceNo,
    String? notes,
  }) async {
    try {
      await _api.dio.put('payments/$id', data: {
        'amount': amount,
        'client_id': clientId,
        'rent_id': rentId,
        'method': method,
        'reference_no': referenceNo,
        'notes': notes,
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Failed to update payment');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<void> voidPayment({required int id, String? reason}) async {
    try {
      await _api.dio.post('payments/$id/void', data: {'reason': reason});
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Failed to void payment');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }
}
