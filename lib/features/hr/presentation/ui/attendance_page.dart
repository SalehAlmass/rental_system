import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/permission_guard.dart';
import '../../../../features/profile/profile_cubit.dart';
import '../../data/hr_repository.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late final HrRepository _repo;
  Timer? _timer;

  bool _loading = true;
  bool _working = false;
  String _selectedShift = 'morning';

  // Employee details parsed from GET attendance/me
  double _hours = 0; // Month total
  List<AttendanceLog> _logs = const [];
  String _currentStatus = 'out';
  DateTime? _activeBreakStart;
  DateTime? _checkInTime;
  DateTime? _expectedCheckoutTime;
  String? _currentShift;

  int _todayWorkedSeconds = 0;
  int _todayBreakSeconds = 0;
  int _todayLateMinutes = 0;

  Map<String, dynamic> _stats = const {};
  List<dynamic> _calendarData = const [];

  // Manager dashboard state
  bool _canAccessDashboard = false;
  String _month = _monthStr(DateTime.now());
  String _adminFilter = 'all';
  final String _roleFilter = '';
  String _searchQuery = '';
  List<dynamic> _managerItems = const [];
  Map<String, dynamic> _managerCounts = const {};
  bool _managerLoading = false;

  @override
  void initState() {
    super.initState();
    _repo = HrRepository(context.read<ApiClient>());
    _boot();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _monthStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  String getPlatformName() {
    if (kIsWeb) return 'web';
    try {
      if (io.Platform.isAndroid) return 'android';
      if (io.Platform.isIOS) return 'ios';
      if (io.Platform.isWindows) return 'windows';
      return 'desktop';
    } catch (_) {
      return 'unknown';
    }
  }

  Map<String, dynamic> _getDeviceInfo() {
    return {
      'device_timezone': DateTime.now().timeZoneName,
      'device_platform': getPlatformName(),
      'device_app_version': '8.1.0',
      'device_name': kIsWeb ? 'Browser User' : 'Handheld Device',
    };
  }

  Future<void> _boot() async {
    setState(() => _loading = true);
    try {
      final pstate = context.read<ProfileCubit>().state;
      _canAccessDashboard = pstate.hasScreenPermission('hr') ||
          pstate.hasScreenPermission('attendance_dashboard') ||
          pstate.hasScreenPermission('attendance_manage');

      await _load();
      if (_canAccessDashboard) {
        await _loadManagerDashboard();
      }
    } catch (e) {
      if (mounted) _snack('فشل تحميل الصفحة: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    try {
      final res = await _repo.getMyAttendance(month: _month);
      if (!mounted) return;
      setState(() {
        _hours = res.workedHours;
        _logs = res.logs;
        _currentStatus = res.currentStatus;
        _activeBreakStart = res.activeBreakStart;
        _checkInTime = res.checkInTime;
        _expectedCheckoutTime = res.expectedCheckoutTime;
        _currentShift = res.currentShift;
        _todayWorkedSeconds = res.todayWorkedSeconds;
        _todayBreakSeconds = res.todayBreakSeconds;
        _todayLateMinutes = res.todayLateMinutes;
        _stats = res.stats;
        _calendarData = res.calendar;

        if (_currentShift != null) {
          _selectedShift = _currentShift!;
        }
      });
      _startTimer();
    } catch (e) {
      if (mounted) _snack('فشل تحميل الحضور: $e');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_currentStatus == 'out') return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_currentStatus == 'working') {
          _todayWorkedSeconds++;
        } else if (_currentStatus == 'break') {
          _todayBreakSeconds++;
        }
      });
    });
  }

  Future<void> _loadManagerDashboard() async {
    setState(() => _managerLoading = true);
    try {
      final res = await _repo.adminAttendanceSummary(
        month: _month,
        filter: _adminFilter,
        role: _roleFilter.isEmpty ? null : _roleFilter,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
      if (!mounted) return;
      setState(() {
        _managerItems = res['items'] as List? ?? [];
        _managerCounts = res['counts'] as Map<String, dynamic>? ?? {};
      });
    } catch (e) {
      if (mounted) _snack('فشل تحميل بيانات المدير: $e');
    } finally {
      if (mounted) setState(() => _managerLoading = false);
    }
  }

  Future<bool> _confirmManual(String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'أدخل PIN لتأكيد الهوية',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim().isNotEmpty),
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );
    return ok == true;
  }

  Future<void> _checkIn() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final ok = await _confirmManual('تسجيل حضور جديد');
      if (!ok) return;

      await _repo.checkIn(
        method: 'manual',
        shift: _selectedShift,
        metadata: _getDeviceInfo(),
      );
      _snack('تم تسجيل حضور الدوام بنجاح');
      await _load();
      if (_canAccessDashboard) _loadManagerDashboard();
    } catch (e) {
      _snack('فشل تسجيل الحضور: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _checkOut() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final ok = await _confirmManual('تسجيل انصراف');
      if (!ok) return;

      await _repo.checkOut(
        method: 'manual',
        shift: _selectedShift,
        metadata: _getDeviceInfo(),
      );
      _snack('تم تسجيل الانصراف بنجاح');
      await _load();
      if (_canAccessDashboard) _loadManagerDashboard();
    } catch (e) {
      final errMsg = e.toString();
      if (errMsg.contains('shift_not_closed') || errMsg.contains('إجراءات لم يتم إنهاؤها')) {
        _showShiftNotClosedDialog();
      } else {
        _snack('فشل تسجيل الانصراف: $e');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showShiftNotClosedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.orange, size: 48),
        title: const Text('تنصيب تسوية النقدية'),
        content: const Text(
          'يوجد لديك إجراءات لم يتم إنهاؤها قبل تسجيل الانصراف. الرجاء إغلاق الوردية المالية وتسوية المبالغ قبل تسجيل المغادرة.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          )
        ],
      ),
    );
  }

  Future<void> _startBreak() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final ok = await _confirmManual('بدء الاستراحة');
      if (!ok) return;

      await _repo.startBreak(metadata: _getDeviceInfo());
      _snack('تم بدء الاستراحة');
      await _load();
    } catch (e) {
      _snack('فشل بدء الاستراحة: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _endBreak() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final ok = await _confirmManual('إنهاء الاستراحة');
      if (!ok) return;

      await _repo.endBreak(metadata: _getDeviceInfo());
      _snack('تم إنهاء الاستراحة والعودة للعمل');
      await _load();
    } catch (e) {
      _snack('فشل إنهاء الاستراحة: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  String _formatDuration(int seconds) {
    final h = (seconds / 3600).floor().toString().padLeft(2, '0');
    final m = ((seconds % 3600) / 60).floor().toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  double get _shiftProgress {
    final expectedSec = _selectedShift == 'evening' ? 5 * 3600 : 6 * 3600;
    return (_todayWorkedSeconds / expectedSec).clamp(0.0, 1.0);
  }

  void _showDayDetailsDialog(Map<String, dynamic> item) {
    final date = item['date']?.toString() ?? '';
    final statusStr = item['status']?.toString() ?? '';
    final metrics = item['metrics'] ?? {};
    final dayLogs = item['logs'] as List? ?? [];

    String statusLabel = 'غياب';
    Color statusColor = Colors.red;
    if (statusStr == 'present') {
      statusLabel = 'حضور';
      statusColor = Colors.green;
    } else if (statusStr == 'late') {
      statusLabel = 'تأخر';
      statusColor = Colors.orange;
    } else if (statusStr == 'weekend') {
      statusLabel = 'إجازة نهاية الأسبوع';
      statusColor = Colors.grey;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('تفاصيل يوم $date'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (metrics['worked_hours'] != null) Text('ساعات العمل: ${metrics['worked_hours']} ساعة'),
            if (metrics['break_minutes'] != null && metrics['break_minutes'] > 0) Text('الاستراحات: ${metrics['break_minutes']} دقيقة'),
            if (metrics['late_minutes'] != null && metrics['late_minutes'] > 0) Text('التأخير: ${metrics['late_minutes']} دقيقة'),
            if (metrics['early_leave_minutes'] != null && metrics['early_leave_minutes'] > 0) Text('الانصراف المبكر: ${metrics['early_leave_minutes']} دقيقة'),
            if (metrics['overtime_minutes'] != null && metrics['overtime_minutes'] > 0) Text('العمل الإضافي: ${metrics['overtime_minutes']} دقيقة'),
            const SizedBox(height: 12),
            const Text('سجل الحركات:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (dayLogs.isEmpty)
              const Text('لا توجد سجلات لهذا اليوم')
            else
              SizedBox(
                height: 120,
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: dayLogs.length,
                  itemBuilder: (ctx, i) {
                    final l = dayLogs[i];
                    final time = l['ts']?.toString().substring(11, 16) ?? '';
                    String typeL = 'حضور';
                    if (l['type'] == 'out') typeL = 'انصراف';
                    if (l['type'] == 'break_start') typeL = 'بداية استراحة';
                    if (l['type'] == 'break_end') typeL = 'نهاية استراحة';
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(l['type'] == 'in' ? Icons.login : Icons.logout, size: 16),
                      title: Text('$typeL ($time)'),
                      subtitle: Text(l['note']?.toString() ?? ''),
                    );
                  },
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          )
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final now = DateTime.now();
    final todayLogs = _logs
        .where((l) => l.ts.year == now.year && l.ts.month == now.month && l.ts.day == now.day)
        .toList()
        .reversed
        .toList();

    if (todayLogs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('لا توجد حركات حضور مسجلة اليوم')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'مخطط الحركات اليومي',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...todayLogs.map((l) {
              final isLast = todayLogs.indexOf(l) == todayLogs.length - 1;
              final time = DateFormat('hh:mm a').format(l.ts.toLocal());
              IconData icon = Icons.login;
              Color color = Colors.green;
              String title = 'تسجيل حضور';

              if (l.type == 'out') {
                icon = Icons.logout;
                color = Colors.red;
                title = 'تسجيل انصراف';
              } else if (l.type == 'break_start') {
                icon = Icons.pause;
                color = Colors.orange;
                title = 'بدء استراحة';
              } else if (l.type == 'break_end') {
                icon = Icons.play_arrow;
                color = Colors.blue;
                title = 'إنهاء استراحة';
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 16),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 30,
                          color: Colors.grey.shade300,
                        )
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(time, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                        if (l.note != null && l.note!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(l.note!, style: const TextStyle(color: Colors.black54, fontSize: 11)),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final parts = _month.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;

    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final daysCount = lastDay.day;
    final startOffset = (firstDay.weekday % 7); // Sun=0

    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س']
              .map((e) => Expanded(
                    child: Center(
                      child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: daysCount + startOffset,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (ctx, index) {
            if (index < startOffset) return const SizedBox();

            final dayNum = index - startOffset + 1;
            final dayStr = '$year-${month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';

            final calItem = _calendarData.firstWhere(
              (element) => element['date'] == dayStr,
              orElse: () => null,
            );

            final status = calItem?['status'] ?? 'future';
            Color color = Colors.grey.shade100;
            Color textColor = Colors.black87;

            if (status == 'present') {
              color = Colors.green.shade100;
              textColor = Colors.green.shade900;
            } else if (status == 'late') {
              color = Colors.yellow.shade100;
              textColor = Colors.orange.shade900;
            } else if (status == 'absent') {
              color = Colors.red.shade100;
              textColor = Colors.red.shade900;
            } else if (status == 'weekend') {
              color = Colors.grey.shade200;
              textColor = Colors.grey.shade600;
            }

            final isToday = dayStr == todayStr;

            return InkWell(
              onTap: calItem == null ? null : () => _showDayDetailsDialog(calItem),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: isToday ? Border.all(color: Colors.blueAccent, width: 2) : null,
                ),
                child: Center(
                  child: Text(
                    '$dayNum',
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Status Color
    Color statusColor = Colors.grey;
    String statusTitle = 'خارج الدوام';
    IconData statusIcon = Icons.pause_circle_filled;
    if (_currentStatus == 'working') {
      statusColor = Colors.green;
      statusTitle = 'داخل الدوام';
      statusIcon = Icons.check_circle;
    } else if (_currentStatus == 'break') {
      statusColor = Colors.orange;
      statusTitle = 'في استراحة';
      statusIcon = Icons.free_breakfast;
    }

    final employeeDashboard = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current Status & Live Timer
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 28),
                          const SizedBox(width: 8),
                          Text(statusTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                      if (_currentStatus != 'out')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _selectedShift == 'evening' ? 'وردية مسائية' : 'وردية صباحية',
                            style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('مدة العمل', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(_formatDuration(_todayWorkedSeconds),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, fontFamily: 'monospace')),
                        ],
                      ),
                      Container(width: 1, height: 40, color: Colors.grey.shade300),
                      Column(
                        children: [
                          const Text('مدة الاستراحة', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(_formatDuration(_todayBreakSeconds),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.orange, fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Shift bounds display
                  if (_checkInTime != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('تسجيل الدخول: ${DateFormat('hh:mm a').format(_checkInTime!.toLocal())}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        if (_expectedCheckoutTime != null)
                          Text('الخروج المتوقع: ${DateFormat('hh:mm a').format(_expectedCheckoutTime!.toLocal())}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (_activeBreakStart != null)
                      Text(
                        'بدأت الاستراحة في: ${DateFormat('hh:mm a').format(_activeBreakStart!.toLocal())}',
                        style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    if (_todayLateMinutes > 0)
                      Text(
                        'التأخير اليوم: $_todayLateMinutes دقيقة',
                        style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    const SizedBox(height: 12),
                  ],

                  // Shift progress
                  if (_currentStatus != 'out') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('تقدم الدوام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('${(_shiftProgress * 100).toInt()}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: _shiftProgress,
                      backgroundColor: Colors.grey.shade200,
                      color: Colors.green,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_currentStatus == 'out') ...[
                    DropdownButtonFormField<String>(
                      value: _selectedShift,
                      decoration: const InputDecoration(
                        labelText: 'اختر الوردية للتحضير',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'morning', child: Text('وردية صباحية (06:00 ص - 12:00 م)')),
                        DropdownMenuItem(value: 'evening', child: Text('وردية مسائية (04:00 م - 09:00 م)')),
                      ],
                      onChanged: (v) => setState(() => _selectedShift = v ?? 'morning'),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Quick Action Buttons
                  Row(
                    children: [
                      if (_currentStatus == 'out')
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _working ? null : _checkIn,
                            icon: const Icon(Icons.login),
                            label: const Text('تسجيل حضور'),
                          ),
                        ),
                      if (_currentStatus == 'working') ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _working ? null : _startBreak,
                            icon: const Icon(Icons.pause),
                            label: const Text('بدء استراحة'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _working ? null : _checkOut,
                            icon: const Icon(Icons.logout),
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            label: const Text('تسجيل انصراف'),
                          ),
                        ),
                      ],
                      if (_currentStatus == 'break') ...[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _working ? null : _endBreak,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('إنهاء استراحة'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _working ? null : _checkOut,
                            icon: const Icon(Icons.logout),
                            label: const Text('تسجيل انصراف'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Daily Timeline
          _buildTimeline(),
          const SizedBox(height: 12),

          // Monthly Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إحصائيات الشهر الحالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem('أيام العمل', '${_stats['working_days'] ?? 0}'),
                      _statItem('أيام الحضور', '${_stats['present_days'] ?? 0}', Colors.green),
                      _statItem('أيام الغياب', '${_stats['absent_days'] ?? 0}', Colors.red),
                      _statItem('أيام التأخر', '${_stats['late_days'] ?? 0}', Colors.orange),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem('ساعات مسجلة', '$_hoursس'),
                      _statItem('الإضافي', '${_stats['total_overtime_minutes'] ?? 0}د', Colors.blue),
                      _statItem('نسبة الحضور', '${_stats['attendance_percentage'] ?? 0}%', Colors.purple),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem('متوسط الوصول', _stats['avg_arrival_time']?.toString() ?? '--:--'),
                      _statItem('متوسط المغادرة', _stats['avg_checkout_time']?.toString() ?? '--:--'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Monthly Calendar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('تقويم الحضور لشهر $_month', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 16),
                  _buildCalendarGrid(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );

    // Manager View
    final managerDashboard = RefreshIndicator(
      onRefresh: _loadManagerDashboard,
      child: Column(
        children: [
          // Live Counts Card
          Container(
            color: Colors.blue.shade50.withOpacity(0.2),
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _countBadge('الكل', '${_managerCounts['total'] ?? 0}', Colors.black87),
                _countBadge('يعملون', '${_managerCounts['working'] ?? 0}', Colors.green),
                _countBadge('استراحة', '${_managerCounts['break'] ?? 0}', Colors.orange),
                _countBadge('غائبين', '${_managerCounts['absent'] ?? 0}', Colors.red),
                _countBadge('متأخرين', '${_managerCounts['late'] ?? 0}', Colors.purple),
              ],
            ),
          ),

          // Filters header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      hintText: 'ابحث باسم الموظف...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) {
                      _searchQuery = v.trim();
                      _loadManagerDashboard();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _adminFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('الكل')),
                    DropdownMenuItem(value: 'present', child: Text('حاضرين اليوم')),
                    DropdownMenuItem(value: 'working', child: Text('على رأس العمل')),
                    DropdownMenuItem(value: 'break', child: Text('في استراحة')),
                    DropdownMenuItem(value: 'late', child: Text('متأخرين')),
                    DropdownMenuItem(value: 'absent', child: Text('غائبين')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _adminFilter = v);
                    _loadManagerDashboard();
                  },
                ),
              ],
            ),
          ),

          // Employee logs list
          Expanded(
            child: _managerLoading
                ? const Center(child: CircularProgressIndicator())
                : _managerItems.isEmpty
                    ? const Center(child: Text('لا توجد سجلات مطابقة'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _managerItems.length,
                        itemBuilder: (ctx, idx) {
                          final item = _managerItems[idx];
                          final username = item['username'] ?? 'مجهول';
                          final status = item['status'] ?? 'out';
                          final checkin = item['check_in_time'] != null
                              ? item['check_in_time'].toString().substring(11, 16)
                              : '--:--';
                          final checkout = item['check_out_time'] != null
                              ? item['check_out_time'].toString().substring(11, 16)
                              : '--:--';

                          Color badgeColor = Colors.grey;
                          String badgeLabel = 'خارج الدوام';
                          if (status == 'working') {
                            badgeColor = Colors.green;
                            badgeLabel = 'يعمل حالياً';
                          } else if (status == 'break') {
                            badgeColor = Colors.orange;
                            badgeLabel = 'في استراحة';
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person)),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      badgeLabel,
                                      style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'الحضور: $checkin • الانصراف: $checkout\n'
                                  'العمل: ${item['worked_hours'] ?? 0.0}س • الاستراحة: ${item['break_minutes'] ?? 0}د • التأخر: ${item['late_minutes'] ?? 0}د',
                                  style: const TextStyle(fontSize: 11, height: 1.4),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'الحضور والانصراف والمتابعة',
          centerTitle: true,
          showShadow: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_month),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2025),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() {
                    _month = _monthStr(date);
                  });
                  _load();
                  if (_canAccessDashboard) _loadManagerDashboard();
                }
              },
            )
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : !_canAccessDashboard
                ? employeeDashboard
                : DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const Material(
                          color: Colors.white,
                          elevation: 1,
                          child: TabBar(
                            labelColor: Colors.blueAccent,
                            unselectedLabelColor: Colors.black54,
                            indicatorColor: Colors.blueAccent,
                            tabs: [
                              Tab(text: 'حضوري الشخصي'),
                              Tab(text: 'متابعة الموظفين'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [employeeDashboard, managerDashboard],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _statItem(String title, String val, [Color? color]) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _countBadge(String label, String count, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
          ),
        )
      ],
    );
  }
}
