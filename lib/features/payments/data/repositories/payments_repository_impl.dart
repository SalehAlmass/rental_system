import 'package:dio/dio.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/network/failure.dart';
import 'package:rental_app/features/payments/domain/entities/models.dart';

class PaymentsRepository {
  PaymentsRepository(this._api);
  final ApiClient _api;

  Future<({List<Payment> items, PaymentSummary? summary, int total})> list({
    int? clientId,
    int? rentId,
    bool showVoided = false,
    int? page,
    int? perPage,
    String? query,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final res = await _api.dio.get(
        'payments',
        queryParameters: {
          if (clientId != null) 'client_id': clientId,
          if (rentId != null) 'rent_id': rentId,
          'show_void': showVoided ? 1 : 0,
          if (page != null) 'page': page,
          if (perPage != null) 'per_page': perPage,
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          if (sortBy != null) 'sort_by': sortBy,
          if (sortOrder != null) 'sort_order': sortOrder,
        },
      );

      if (res.data is! Map) {
        throw ApiFailure("Unexpected response: ${res.data}");
      }
      final map = res.data as Map<String, dynamic>;

      final rawList = map['data'] as List? ?? [];
      final items = rawList
          .map((e) => Payment.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

      final summary = map['summary'] != null
          ? PaymentSummary.fromJson((map['summary'] as Map).cast<String, dynamic>())
          : null;
      final total = (map['pagination'] is Map)
          ? ((map['pagination'] as Map)['total'] as num?)?.toInt() ?? items.length
          : items.length;

      return (items: items, summary: summary, total: total);
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  // باقي الدوال كما هي
  Future<int> create({
    required String type, // in|out
    required double amount,
    int? clientId,
    int? rentId,
    int? equipmentId,
    String method = 'cash',
    String? referenceNo,
    String? notes,
    String? idempotencyKey,
  }) async {
    try {
      final res = await _api.dio.post(
        'payments',
        data: {
          'type': type,
          'amount': amount,
          'client_id': clientId,
          'rent_id': rentId,
          'equipment_id': equipmentId,
          'method': method,
          'reference_no': referenceNo,
          'notes': notes,
          if (idempotencyKey != null && idempotencyKey.isNotEmpty)
            'idempotency_key': idempotencyKey,
        },
      );
      final data = (res.data is Map)
          ? (res.data as Map).cast<String, dynamic>()
          : {};
      final rawId = data['id'];
      final id = (rawId is num)
          ? rawId.toInt()
          : int.tryParse(rawId.toString()) ?? 0;
      if (id <= 0) {
        throw ApiFailure("Create payment: invalid id returned: $rawId");
      }
      return id;
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  Future<void> update({
    required int id,
    required double amount,
    int? clientId,
    int? rentId,
    int? equipmentId,
    String method = 'cash',
    String? referenceNo,
    String? notes,
  }) async {
    try {
      await _api.dio.put(
        'payments/$id',
        data: {
          'amount': amount,
          'client_id': clientId,
          'rent_id': rentId,
          'equipment_id': equipmentId,
          'method': method,
          'reference_no': referenceNo,
          'notes': notes,
        },
      );
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  Future<void> voidPayment({required int id, String? reason}) async {
    try {
      await _api.dio.post('payments/$id/void', data: {'reason': reason});
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }
}
