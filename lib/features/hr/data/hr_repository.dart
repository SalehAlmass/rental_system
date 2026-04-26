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

  factory AttendanceLog.fromJson(Map<String, dynamic> j) {
        int asInt(dynamic v) {
          if (v is int) return v;
          if (v is num) return v.toInt();
          return int.tryParse(v?.toString() ?? '') ?? 0;
        }

        return AttendanceLog(
          id: asInt(j['id']),
          userId: asInt(j['user_id'] ?? j['userId']),
          type: (j['type'] ?? '').toString(),
          ts: DateTime.tryParse((j['ts'] ?? j['created_at'] ?? '').toString()) ?? DateTime.now(),
          method: j['method']?.toString(),
          note: j['note']?.toString(),
        );
      }
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

  // Attendance metrics (admin monitoring)
  final int? workDays;
  final int? presentDays;
  final int? absentDays;
  final int? lateMinutes;

  // Salary breakdown
  final double? baseAmount;
  final double? deductions;
  final double? netAmount;
  final double? absenceDeduction;
  final double? lateDeduction;

  PayrollItem({
    required this.userId,
    required this.username,
    required this.role,
    required this.workedHours,
    required this.amount,
    this.salaryType,
    this.hourlyRate,
    this.monthlySalary,
    this.workDays,
    this.presentDays,
    this.absentDays,
    this.lateMinutes,
    this.baseAmount,
    this.deductions,
    this.netAmount,
    this.absenceDeduction,
    this.lateDeduction,
  });

  factory PayrollItem.fromJson(Map<String, dynamic> j) {
        int asInt(dynamic v) {
          if (v is int) return v;
          if (v is num) return v.toInt();
          return int.tryParse(v?.toString() ?? '') ?? 0;
        }

        double asDouble(dynamic v) {
          if (v is double) return v;
          if (v is int) return v.toDouble();
          if (v is num) return v.toDouble();
          return double.tryParse(v?.toString() ?? '') ?? 0.0;
        }

        return PayrollItem(
        userId: asInt(j['user_id'] ?? j['userId']),
        username: (j['username'] ?? '').toString(),
        role: (j['role'] ?? '').toString(),
        workedHours: asDouble(j['worked_hours']),
        amount: asDouble(j['amount']),
        salaryType: j['salary_type']?.toString(),
        hourlyRate: j['hourly_rate'] == null ? null : asDouble(j['hourly_rate']),
        monthlySalary: j['monthly_salary'] == null ? null : asDouble(j['monthly_salary']),
        workDays: j['work_days'] == null ? null : asInt(j['work_days']),
        presentDays: j['present_days'] == null ? null : asInt(j['present_days']),
        absentDays: j['absent_days'] == null ? null : asInt(j['absent_days']),
        lateMinutes: j['late_minutes'] == null ? null : asInt(j['late_minutes']),
        baseAmount: j['base_amount'] == null ? null : asDouble(j['base_amount']),
        deductions: j['deductions'] == null ? null : asDouble(j['deductions']),
        netAmount: j['net_amount'] == null ? null : asDouble(j['net_amount']),
        absenceDeduction: j['absence_deduction'] == null ? null : asDouble(j['absence_deduction']),
        lateDeduction: j['late_deduction'] == null ? null : asDouble(j['late_deduction']),
      );
      }
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
      inDuty: (raw['in_duty'] == true) ||
          (raw['in_duty'] is num && (raw['in_duty'] as num) == 1) ||
          (raw['in_duty']?.toString() == '1'),
      workedHours: (raw['worked_hours'] is num) ? (raw['worked_hours'] as num).toDouble() : double.tryParse('${raw['worked_hours']}') ?? 0,
      logs: logs,
    );
  }

  Future<void> checkIn({required String method, required String shift}) async {
    await _dio.post('attendance/checkin', data: {'method': method, 'shift': shift});
  }

  Future<void> checkOut({required String method, required String shift}) async {
    await _dio.post('attendance/checkout', data: {'method': method, 'shift': shift});
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

  /// Admin: monitor attendance + salary estimation with filters.
  /// filter: all | present | absent | late
  Future<List<PayrollItem>> adminAttendanceSummary({required String month, String filter = 'all'}) async {
    final res = await _dio.get('attendance/admin', queryParameters: {
      'month': month,
      'filter': filter,
    });
    final raw = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;
    final items = (raw['items'] as List? ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .map(PayrollItem.fromJson)
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
