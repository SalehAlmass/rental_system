import 'package:dio/dio.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/network/failure.dart';
import 'package:rental_app/features/rents/domain/entities/models.dart';

class RentsRepository {
  RentsRepository(this._api);
  final ApiClient _api;

  /// List rents.
  ///
  /// Supported (optional) filters:
  /// - [clientId]
  /// - [status] : open | closed | cancelled
  /// - [limit]
  Future<Rent> get(int id) async {
  try {
    final res = await _api.dio.get('rents/$id');

    final raw = (res.data is Map ? res.data : {});
    final data = (raw is Map)
        ? (raw['data'] ?? raw['rent'] ?? raw)
        : raw;

    if (data is! Map) {
      throw ApiFailure('بيانات العقد غير صالحة');
    }

    return Rent.fromJson(data.cast<String, dynamic>());
  } on DioException catch (e) {
    final msg = (e.response?.data is Map && e.response?.data['error'] != null)
        ? e.response!.data['error'].toString()
        : (e.message ?? 'فشل جلب العقد');
    throw ApiFailure(msg, statusCode: e.response?.statusCode);
  }
}

  Future<List<Rent>> list({int? clientId, String? status, int? limit}) async {
    try {
      final res = await _api.dio.get(
        'rents',
        queryParameters: {
          if (clientId != null) 'client_id': clientId,
          if (status != null && status.isNotEmpty) 'status': status,
          if (limit != null && limit > 0) 'limit': limit,
        },
      );

      dynamic raw = (res.data is Map ? res.data : {});
      if (raw is Map) raw = raw['data'] ?? raw['items'] ?? raw['rents'] ?? [];
      if (raw is! List) throw ApiFailure("Unexpected response: ${(res.data is Map ? res.data : {})}");

      return raw
          .map((e) => Rent.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Failed to load rents');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  // باقي الدوال كما هي
  Future<int> openRent({
    required int clientId,
    required String startDatetime,
    List<Map<String, dynamic>>? items,
    int? equipmentId,
    double dailyRate = 0,
    String? notes,
  }) async {
    try {
      final res = await _api.dio.post(
        'rents',
        data: {
          'client_id': clientId,
          'start_datetime': startDatetime,
          if (items != null && items.isNotEmpty) 'items': items,
          if (equipmentId != null) 'equipment_id': equipmentId,
          if (dailyRate > 0) 'rate': dailyRate,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );

    final root = ((res.data is Map ? res.data : {}) is Map)
        ? ((res.data is Map ? res.data : {}) as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    final data = (root['data'] is Map)
        ? (root['data'] as Map).cast<String, dynamic>()
        : root;

    final rawId = data['id'];
    final id = rawId is num
        ? rawId.toInt()
        : int.tryParse(rawId?.toString() ?? '') ?? 0;

    if (id <= 0) {
      throw ApiFailure('فشل فتح العقد: لم يتم إرجاع رقم صحيح');
    }

    return id;
  } on DioException catch (e) {
    final data = e.response?.data;
    final msg = (data is Map && data['error'] != null)
        ? data['error'].toString()
        : (e.message ?? 'فشل فتح العقد');
    throw ApiFailure(msg, statusCode: e.response?.statusCode);
  }
}
  
  
  Future<void> updateNotes({required int rentId, required String notes}) async {
    try {
      await _api.dio.put('rents/$rentId', data: {'notes': notes});
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Failed to update rent');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<void> replaceEquipment({
    required int rentId,
    required int oldEquipmentId,
    required int newEquipmentId,
    String? notes,
  }) async {
    try {
      await _api.dio.post('rents/$rentId/replace_item', data: {
        'old_equipment_id': oldEquipmentId,
        'new_equipment_id': newEquipmentId,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Failed to replace equipment');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  /// Close a rent and return calculated totals from the backend.
  Future<Map<String, dynamic>> closeRent({
    required int rentId,
    required String endDatetime,
    bool applySpecialPricing = false,
    double paidAmount = 0,
    double discountAmount = 0,
    String? discountNote,
    String paymentMethod = 'cash',
    bool createReceipt = false,
    String? paymentNotes,
    String? idempotencyKey,
  }) async {
    try {
      final res = await _api.dio.post('rents/$rentId/close', data: {
        'end_datetime': endDatetime,
        'apply_special_pricing': applySpecialPricing,
        'paid_amount': paidAmount,
        'discount_amount': discountAmount,
        if (discountNote != null && discountNote.trim().isNotEmpty) 'discount_note': discountNote.trim(),
        'payment_method': paymentMethod,
        'create_receipt': createReceipt,
        if (paymentNotes != null && paymentNotes.trim().isNotEmpty) 'payment_notes': paymentNotes.trim(),
        if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty) 'idempotency_key': idempotencyKey.trim(),
      });
      final data = ((res.data is Map ? res.data : {}) is Map) ? ((res.data is Map ? res.data : {}) as Map).cast<String, dynamic>() : <String, dynamic>{};
      final payload = (data['data'] is Map) ? (data['data'] as Map).cast<String, dynamic>() : <String, dynamic>{};
      return payload;
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Failed to close rent');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<void> cancelRent({required int rentId, String? reason}) async {
    try {
      await _api.dio.post('rents/$rentId/cancel', data: {'reason': reason});
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Failed to cancel rent');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }
}
