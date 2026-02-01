import 'package:dio/dio.dart';

import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/network/failure.dart';
import 'package:rental_app/features/shifts/domain/entities/shift_closing.dart';

class ShiftsRepository {
  ShiftsRepository(this._api);
  final ApiClient _api;

  Future<List<ShiftClosing>> list({String? from, String? to}) async {
    try {
      final res = await _api.dio.get('shifts', queryParameters: {
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      });

      dynamic raw = res.data;
      if (raw is Map) raw = raw['data'] ?? raw['items'] ?? [];
      if (raw is! List) throw ApiFailure('Unexpected response: ${res.data}');

      return raw
          .map((e) => ShiftClosing.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Failed');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }

  Future<ShiftClosing> close({
    String? shiftDate, // YYYY-MM-DD
    required double cashTotal,
    required double transferTotal,
    required double cashInDrawer,
    String? note,
  }) async {
    try {
      final res = await _api.dio.post('shifts/close', data: {
        if (shiftDate != null && shiftDate.isNotEmpty) 'shift_date': shiftDate,
        'cash_total': cashTotal,
        'transfer_total': transferTotal,
        'cash_in_drawer': cashInDrawer,
        'note': note,
      });

      dynamic raw = res.data;
      if (raw is Map) raw = raw['data'] ?? raw;
      if (raw is! Map) throw ApiFailure('Unexpected response: ${res.data}');
      return ShiftClosing.fromJson(raw.cast<String, dynamic>());
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : (e.message ?? 'Failed');
      throw ApiFailure(msg, statusCode: e.response?.statusCode);
    }
  }
}
