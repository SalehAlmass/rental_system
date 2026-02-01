import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/failure.dart';
import '../../domain/entities/payment_report.dart';
import '../../domain/entities/report_dashboard.dart';
import '../../domain/entities/smart_reports.dart';

class ReportsRepository {
  ReportsRepository(this._api);

  final ApiClient _api;

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asListOfMap(dynamic v) {
    if (v is List) {
      return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return const [];
  }

  ApiFailure _dioFailure(DioException e, String fallback) {
    final data = e.response?.data;
    final msg = (data is Map && data['error'] != null)
        ? data['error'].toString()
        : (e.message ?? fallback);
    return ApiFailure(msg, statusCode: e.response?.statusCode);
  }

  Future<ReportDashboard> dashboard({String? from, String? to}) async {
    try {
      final res = await _api.dio.get(
        'reports/dashboard',
        queryParameters: {
          if (from != null) 'from': from,
          if (to != null) 'to': to,
        },
      );
      final data = _asMap(res.data);
      return ReportDashboard.fromJson(data);
    } on DioException catch (e) {
      throw _dioFailure(e, 'Failed to load dashboard');
    }
  }

  Future<PaymentsReport> paymentsReport({String? from, String? to, String type = 'all'}) async {
    try {
      final res = await _api.dio.get(
        'reports/payments',
        queryParameters: {
          if (from != null) 'from': from,
          if (to != null) 'to': to,
          if (type != 'all') 'type': type,
        },
      );

      final m = _asMap(res.data);
      // keep compatibility: some APIs might still return "data" instead of "rows"
      if (m['rows'] == null && m['data'] != null) {
        m['rows'] = m['data'];
      }
      if (m['from'] == null && m['filter'] is Map) {
        final f = (m['filter'] as Map).cast<String, dynamic>();
        m['from'] = f['from'];
        m['to'] = f['to'];
        m['type'] = f['type'] ?? m['type'];
      }
      return PaymentsReport.fromJson(m);
    } on DioException catch (e) {
      throw _dioFailure(e, 'Failed to load payments report');
    }
  }

  Future<List<EquipmentProfitRow>> equipmentProfit({String? from, String? to}) async {
    try {
      final res = await _api.dio.get(
        'reports/equipment-profit',
        queryParameters: {
          if (from != null) 'from': from,
          if (to != null) 'to': to,
        },
      );
      final m = _asMap(res.data);
      final list = _asListOfMap(m['data'] ?? m['rows'] ?? m['items']);
      return list.map(EquipmentProfitRow.fromJson).toList();
    } on DioException catch (e) {
      throw _dioFailure(e, 'Failed to load equipment profit');
    }
  }

  Future<List<TopEquipmentRow>> topEquipment({String? from, String? to, int limit = 10}) async {
    try {
      final res = await _api.dio.get(
        'reports/top-equipment',
        queryParameters: {
          if (from != null) 'from': from,
          if (to != null) 'to': to,
          'limit': limit,
        },
      );
      final m = _asMap(res.data);
      final list = _asListOfMap(m['data'] ?? m['rows'] ?? m['items']);
      return list.map(TopEquipmentRow.fromJson).toList();
    } on DioException catch (e) {
      throw _dioFailure(e, 'Failed to load top equipment');
    }
  }

  Future<List<TopClientRow>> topClients({String? from, String? to, int limit = 10}) async {
    try {
      final res = await _api.dio.get(
        'reports/top-clients',
        queryParameters: {
          if (from != null) 'from': from,
          if (to != null) 'to': to,
          'limit': limit,
        },
      );
      final m = _asMap(res.data);
      final list = _asListOfMap(m['data'] ?? m['rows'] ?? m['items']);
      return list.map(TopClientRow.fromJson).toList();
    } on DioException catch (e) {
      throw _dioFailure(e, 'Failed to load top clients');
    }
  }

  Future<List<LateClientRow>> lateClients({String? from, String? to, int limit = 10}) async {
    try {
      final res = await _api.dio.get(
        'reports/late-clients',
        queryParameters: {
          if (from != null) 'from': from,
          if (to != null) 'to': to,
          'limit': limit,
        },
      );
      final m = _asMap(res.data);
      final list = _asListOfMap(m['data'] ?? m['rows'] ?? m['items']);
      return list.map(LateClientRow.fromJson).toList();
    } on DioException catch (e) {
      throw _dioFailure(e, 'Failed to load late clients');
    }
  }

  Future<List<RevenueRow>> revenue({required String group, String? from, String? to}) async {
    try {
      final res = await _api.dio.get(
        'reports/revenue',
        queryParameters: {
          'group': group,
          if (from != null) 'from': from,
          if (to != null) 'to': to,
        },
      );
      final m = _asMap(res.data);
      final list = _asListOfMap(m['data'] ?? m['rows'] ?? m['items']);
      return list.map(RevenueRow.fromJson).toList();
    } on DioException catch (e) {
      throw _dioFailure(e, 'Failed to load revenue');
    }
  }

  Future<List<RevenueByUserRow>> revenueByUser({String? from, String? to}) async {
    try {
      final res = await _api.dio.get(
        'reports/revenue-by-user',
        queryParameters: {
          if (from != null) 'from': from,
          if (to != null) 'to': to,
        },
      );
      final m = _asMap(res.data);
      final list = _asListOfMap(m['data'] ?? m['rows'] ?? m['items']);
      return list.map(RevenueByUserRow.fromJson).toList();
    } on DioException catch (e) {
      throw _dioFailure(e, 'Failed to load revenue by user');
    }
  }
}
