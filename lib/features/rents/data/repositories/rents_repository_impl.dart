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
      throw ApiFailure.fromDio(e);
    }
}

  Future<List<Rent>> list({int? clientId, String? status, int? limit, bool archivedOnly = false}) async {
    try {
      final res = await _api.dio.get(
        'rents',
        queryParameters: {
          if (clientId != null) 'client_id': clientId,
          if (status != null && status.isNotEmpty && status != 'archived') 'status': status,
          if (limit != null && limit > 0) 'limit': limit,
          if (archivedOnly || status == 'archived') 'archived_only': 1,
        },
      );

      dynamic raw = (res.data is Map ? res.data : {});
      if (raw is Map) raw = raw['data'] ?? raw['items'] ?? raw['rents'] ?? [];
      if (raw is! List) throw ApiFailure("Unexpected response: ${(res.data is Map ? res.data : {})}");

      return raw
          .map((e) => Rent.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  Future<({List<Rent> items, int total})> listPaginated({
    int? clientId,
    String? status,
    int page = 1,
    int perPage = 20,
    String searchQuery = '',
    bool archivedOnly = false,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final res = await _api.dio.get(
        'rents',
        queryParameters: {
          if (clientId != null) 'client_id': clientId,
          if (status != null && status.isNotEmpty && status != 'archived') 'status': status,
          'page': page,
          'per_page': perPage,
          if (searchQuery.isNotEmpty) 'q': searchQuery,
          if (archivedOnly || status == 'archived') 'archived_only': 1,
          if (sortBy != null) 'sort_by': sortBy,
          if (sortOrder != null) 'sort_order': sortOrder,
        },
      );

      if (res.data is! Map) {
        throw ApiFailure("Unexpected response structure");
      }
      final map = res.data as Map<String, dynamic>;
      
      dynamic rawList = map['data'] ?? map['items'] ?? map['rents'] ?? [];
      if (rawList is! List) {
        throw ApiFailure("Unexpected rents list structure");
      }

      final items = rawList
          .map((e) => Rent.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

      final total = (map['pagination'] is Map)
          ? ((map['pagination'] as Map)['total'] as num?)?.toInt() ?? items.length
          : items.length;

      return (items: items, total: total);
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
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
      throw ApiFailure.fromDio(e);
    }
}
  
  
  Future<void> updateNotes({required int rentId, required String notes}) async {
    try {
      await _api.dio.put('rents/$rentId', data: {'notes': notes});
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
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
      throw ApiFailure.fromDio(e);
    }
  }

  Future<void> returnEquipment({
    required int rentId,
    required int equipmentId,
  }) async {
    try {
      await _api.dio.post('rents/$rentId/return_item', data: {
        'equipment_id': equipmentId,
      });
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
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
      throw ApiFailure.fromDio(e);
    }
  }

  Future<void> cancelRent({required int rentId, String? reason}) async {
    try {
      await _api.dio.post('rents/$rentId/cancel', data: {'reason': reason});
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  /// Archive all closed & fully-paid rents (admin only).
  /// Returns the number of archived contracts.
  Future<int> archiveClosed() async {
    try {
      final res = await _api.dio.post('rents/archive-closed');
      final data = (res.data is Map) ? res.data as Map : {};
      final payload = (data['data'] is Map) ? data['data'] as Map : data;
      return (payload['archived_count'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }
}
