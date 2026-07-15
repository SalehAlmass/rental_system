import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/failure.dart';
import '../../domain/entities/financial_reports.dart';
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

  Future<PaymentsReport> paymentsReport({String? from, String? to, String type = 'all', String? sortBy, String? sortOrder, int? page, int? perPage}) async {
    try {
      final res = await _api.dio.get(
        'reports/payments',
        queryParameters: {
          if (from != null) 'from': from,
          if (to != null) 'to': to,
          if (type != 'all') 'type': type,
          if (sortBy != null) 'sort_by': sortBy,
          if (sortOrder != null) 'sort_order': sortOrder,
          if (page != null) 'page': page,
          if (perPage != null) 'per_page': perPage,
        },
      );

      final m = _asMap(res.data);
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

  Future<List<EquipmentProfitRowV2>> equipmentProfitV2({String? from, String? to}) async {
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
      return list.map(EquipmentProfitRowV2.fromJson).toList();
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

  // ── Phase 7 Financial Reports ──────────────────────────────────────────────

  Future<FinancialSummary> financialSummary({
    String? from,
    String? to,
    bool compare = false,
  }) async {
    try {
      final res = await _api.dio.get(
        'reports/financial-summary',
        queryParameters: {
          if (from != null) 'from_date': from,
          if (to != null) 'to_date': to,
          if (compare) 'compare': 'true',
        },
      );
      return FinancialSummary.fromJson(_asMap(res.data));
    } on DioException catch (e) {
      throw _dioFailure(e, 'Failed to load financial summary');
    }
  }

  Future<ProfitLoss> profitLoss({String? from, String? to}) async {
    try {
      final res = await _api.dio.get(
        'reports/profit-loss',
        queryParameters: {
          if (from != null) 'from_date': from,
          if (to != null) 'to_date': to,
        },
      );
      return ProfitLoss.fromJson(_asMap(res.data));
    } on DioException catch (e) {
      throw _dioFailure(e, 'Failed to load profit & loss');
    }
  }

  Future<CashFlow> cashFlow({String? from, String? to}) async {
    try {
      final res = await _api.dio.get(
        'reports/cash-flow',
        queryParameters: {
          if (from != null) 'from_date': from,
          if (to != null) 'to_date': to,
        },
      );
      return CashFlow.fromJson(_asMap(res.data));
    } on DioException catch (e) {
      throw _dioFailure(e, 'Failed to load cash flow');
    }
  }

  Future<List<EmployeePerformanceRow>> employeePerformance({String? from, String? to}) async {
    try {
      final res = await _api.dio.get(
        'reports/employee-performance',
        queryParameters: {
          if (from != null) 'from_date': from,
          if (to != null) 'to_date': to,
        },
      );
      final m = _asMap(res.data);
      final list = _asListOfMap(m['data'] ?? m['rows'] ?? m['items'] ?? []);
      return list.map(EmployeePerformanceRow.fromJson).toList();
    } on DioException catch (e) {
      throw _dioFailure(e, 'Failed to load employee performance');
    }
  }

  Future<List<RevenueByUserSummaryRow>> revenueByUserSummary({String? from, String? to}) async {
    try {
      final res = await _api.dio.get(
        'reports/revenue-by-user-summary',
        queryParameters: {
          if (from != null) 'from_date': from,
          if (to != null) 'to_date': to,
        },
      );
      final m = _asMap(res.data);
      final list = _asListOfMap(m['data'] ?? m['rows'] ?? m['items'] ?? []);
      return list.map(RevenueByUserSummaryRow.fromJson).toList();
    } on DioException catch (e) {
      throw _dioFailure(e, 'Failed to load revenue by user summary');
    }
  }
}
