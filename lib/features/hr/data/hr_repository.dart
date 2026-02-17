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

  factory AttendanceLog.fromJson(Map<String, dynamic> json) {
    return AttendanceLog(
      id: int.tryParse('${json['id']}') ?? 0,
      userId: int.tryParse('${json['user_id']}') ?? 0,
      type: json['type']?.toString() ?? '',
      ts: DateTime.tryParse(json['ts']?.toString() ?? '') ?? DateTime.now(),
      method: json['method']?.toString(),
      note: json['note']?.toString(),
    );
  }
}

class AttendanceMe {
  final bool inDuty;
  final double workedHours;
  final List<AttendanceLog> logs;

  AttendanceMe({
    required this.inDuty,
    required this.workedHours,
    required this.logs,
  });
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

  factory PayrollItem.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    return PayrollItem(
      userId: int.tryParse('${json['user_id']}') ?? 0,
      username: json['username']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      workedHours: parseDouble(json['worked_hours']) ?? 0.0,
      amount: parseDouble(json['amount']) ?? 0.0,
      salaryType: json['salary_type']?.toString(),
      hourlyRate: parseDouble(json['hourly_rate']),
      monthlySalary: parseDouble(json['monthly_salary']),
    );
  }
}

class HrMe {
  final int? userId;
  final String? username;
  final String? role;

  HrMe({this.userId, this.username, this.role});

  factory HrMe.fromJson(Map<String, dynamic> json) {
    return HrMe(
      userId: json['user_id'] is num
          ? (json['user_id'] as num).toInt()
          : int.tryParse('${json['user_id']}'),
      username: json['username']?.toString(),
      role: json['role']?.toString(),
    );
  }
}

class HrRepository {
  final ApiClient _api;

  HrRepository(this._api);

  Dio get _dio => _api.dio;

  /// جلب بيانات المستخدم الحالي من السيرفر
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

  /// جلب بيانات الحضور والانصراف الخاصة بالمستخدم الحالي
  Future<AttendanceMe> getMyAttendance({DateTime? from, DateTime? to}) async {
    final query = <String, dynamic>{};
    if (from != null) query['from'] = from.toIso8601String().substring(0, 10);
    if (to != null) query['to'] = to.toIso8601String().substring(0, 10);

    final res = await _dio.get('attendance/me', queryParameters: query);
    final raw = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;

    final logs = (raw['logs'] as List? ?? [])
        .whereType<Map>()
        .map((e) => AttendanceLog.fromJson(e.cast<String, dynamic>()))
        .toList();

    double parseWorkedHours(dynamic val) {
      if (val is num) return val.toDouble();
      return double.tryParse('$val') ?? 0.0;
    }

    return AttendanceMe(
      inDuty: raw['in_duty'] == true,
      workedHours: parseWorkedHours(raw['worked_hours']),
      logs: logs,
    );
  }

  /// تسجيل حضور (Check In)
  Future<void> checkIn({required String method}) async {
    await _dio.post('attendance/checkin', data: {'method': method});
  }

  /// تسجيل انصراف (Check Out)
  Future<void> checkOut({required String method}) async {
    await _dio.post('attendance/checkout', data: {'method': method});
  }

  /// ملخص الرواتب الشهري
  Future<List<PayrollItem>> payrollSummary({required String month}) async {
    final res = await _dio.get('payroll/summary', queryParameters: {'month': month});
    final raw = (res.data is Map && res.data['data'] != null) ? res.data['data'] : res.data;

    final items = (raw['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => PayrollItem.fromJson(e.cast<String, dynamic>()))
        .toList();

    return items;
  }

  /// تحديث إعدادات الرواتب لمستخدم محدد
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
