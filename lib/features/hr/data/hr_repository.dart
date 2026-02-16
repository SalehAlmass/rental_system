import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

class AttendanceLog {
  final int id;
  final int userId;
  final String type; // in/out
  final DateTime ts;
  final String? method;
  final String? note;

  AttendanceLog({
    required this.id,
    required this.userId,
    required this.type,
    required this.ts,
    this.method,
    this.note,
  });

  factory AttendanceLog.fromJson(Map<String, dynamic> j) => AttendanceLog(
        id: (j['id'] as num).toInt(),
        userId: (j['user_id'] as num).toInt(),
        type: (j['type'] ?? '').toString(),
        ts: DateTime.tryParse((j['ts'] ?? '').toString()) ?? DateTime.now(),
        method: j['method']?.toString(),
        note: j['note']?.toString(),
      );
}

class AttendanceMe {
  final bool inDuty;
  final double workedHours;
  final List<AttendanceLog> logs;

  AttendanceMe({required this.inDuty, required this.workedHours, required this.logs});
}

class PayrollItem {
  final int userId;
  final String username;
  final String role;
  final double workedHours;
  final double amount;
  final String? salaryType;
  final double? hourlyRate;
  final double? monthlySalary;

  PayrollItem({
    required this.userId,
    required this.username,
    required this.role,
    required this.workedHours,
    required this.amount,
    this.salaryType,
    this.hourlyRate,
    this.monthlySalary,
  });

  factory PayrollItem.fromJson(Map<String, dynamic> j) => PayrollItem(
        userId: (j['user_id'] as num).toInt(),
        username: (j['username'] ?? '').toString(),
        role: (j['role'] ?? '').toString(),
        workedHours: (j['worked_hours'] is num) ? (j['worked_hours'] as num).toDouble() : double.tryParse('${j['worked_hours']}') ?? 0,
        amount: (j['amount'] is num) ? (j['amount'] as num).toDouble() : double.tryParse('${j['amount']}') ?? 0,
        salaryType: j['salary_type']?.toString(),
        hourlyRate: (j['hourly_rate'] is num) ? (j['hourly_rate'] as num).toDouble() : double.tryParse('${j['hourly_rate']}'),
        monthlySalary: (j['monthly_salary'] is num) ? (j['monthly_salary'] as num).toDouble() : double.tryParse('${j['monthly_salary']}'),
      );
}

class HrMe {
  final int? userId;
  final String? username;
  final String? role;

  HrMe({this.userId, this.username, this.role});

  factory HrMe.fromJson(Map<String, dynamic> j) => HrMe(
        userId: j['user_id'] is num ? (j['user_id'] as num).toInt() : int.tryParse('${j['user_id']}'),
        username: j['username']?.toString(),
        role: j['role']?.toString(),
      );
}

// ملاحظة: لا تضع هنا دوال top-level تعتمد على متغيرات غير موجودة.
// تم نقل me() داخل HrRepository.

class HrRepository {
  HrRepository(this._api);

  final ApiClient _api;

  Dio get _dio => _api.dio;

  /// ✅ مصدر الحقيقة لصلاحيات المستخدم من السيرفر.
  /// في هذا المشروع يوجد endpoint جاهز: GET auth/profile
  Future<HrMe> me() async {
    final res = await _dio.get('auth/profile');
    dynamic raw = res.data;
    if (raw is Map && raw['data'] != null) raw = raw['data'];
    if (raw is! Map) {
      return HrMe(userId: 0, username: '', role: '');
    }

    final mapped = <String, dynamic>{
      'user_id': raw['user_id'] ?? raw['id'],
      'username': raw['username'] ?? raw['name'],
      'role': raw['role'],
    };
    return HrMe.fromJson(mapped);
  }

  Future<AttendanceMe> getMyAttendance({DateTime? from, DateTime? to}) async {
    final q = <String, dynamic>{};
    if (from != null) q['from'] = from.toIso8601String().substring(0, 10);
    if (to != null) q['to'] = to.toIso8601String().substring(0, 10);
    final res = await _dio.get('attendance/me', queryParameters: q);
    final raw = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;
    final logs = (raw['logs'] as List? ?? []).whereType<Map>().map((e) => AttendanceLog.fromJson(e.cast<String, dynamic>())).toList();
    return AttendanceMe(
      inDuty: raw['in_duty'] == true,
      workedHours: (raw['worked_hours'] is num) ? (raw['worked_hours'] as num).toDouble() : double.tryParse('${raw['worked_hours']}') ?? 0,
      logs: logs,
    );
  }

  Future<void> checkIn({required String method}) async {
    await _dio.post('attendance/checkin', data: {'method': method});
  }

  Future<void> checkOut({required String method}) async {
    await _dio.post('attendance/checkout', data: {'method': method});
  }

  Future<List<PayrollItem>> payrollSummary({required String month}) async {
    final res = await _dio.get('payroll/summary', queryParameters: {'month': month});
    final raw = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;
    final items = (raw['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => PayrollItem.fromJson(e.cast<String, dynamic>()))
        .toList();
    return items;
  }

  Future<void> updatePayrollSettings({
    required int userId,
    String? salaryType,
    double? hourlyRate,
    double? monthlySalary,
  }) async {
    await _dio.put('payroll/user/$userId', data: {
      if (salaryType != null) 'salary_type': salaryType,
      if (hourlyRate != null) 'hourly_rate': hourlyRate,
      if (monthlySalary != null) 'monthly_salary': monthlySalary,
    });
  }
}
