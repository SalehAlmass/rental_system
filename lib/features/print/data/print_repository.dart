import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/failure.dart';

class PrintRepository {
  PrintRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> contract(int rentId) async {
    try {
      final res = await _api.dio.get('print/contract', queryParameters: {'id': rentId});
      final data = res.data;
      if (data is! Map) throw ApiFailure('Unexpected response');
      return data.cast<String, dynamic>();
    } on DioException catch (e) {
      final r = e.response;
      final data = r?.data;
      final msg = (data is Map && data['error'] != null) ? data['error'].toString() : (e.message ?? 'Failed');
      throw ApiFailure(msg, statusCode: r?.statusCode);
    }
  }

  Future<Map<String, dynamic>> clientStatement({
    required int clientId,
    String? from,
    String? to,
  }) async {
    try {
      final res = await _api.dio.get(
        'print/client-statement',
        queryParameters: {
          'client_id': clientId,
          if (from != null && from.isNotEmpty) 'from': from,
          if (to != null && to.isNotEmpty) 'to': to,
        },
      );
      final data = res.data;
      if (data is! Map) throw ApiFailure('Unexpected response');
      return data.cast<String, dynamic>();
    } on DioException catch (e) {
      final r = e.response;
      final data = r?.data;
      final msg = (data is Map && data['error'] != null) ? data['error'].toString() : (e.message ?? 'Failed');
      throw ApiFailure(msg, statusCode: r?.statusCode);
    }
  }
}
