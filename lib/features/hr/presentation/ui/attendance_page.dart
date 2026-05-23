import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../data/hr_repository.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late final HrRepository _repo;

  bool _loading = true;
  bool _working = false;
  String _selectedShift = 'morning';

  bool _inDuty = false;
  double _hours = 0;
  List<AttendanceLog> _logs = const [];

  bool _isAdmin = false;
  String _month = _monthStr(DateTime.now());
  String _adminFilter = 'all';
  List<PayrollItem> _adminItems = const [];

  @override
  void initState() {
    super.initState();
    _repo = HrRepository(context.read<ApiClient>());
    _boot();
  }

  static String _monthStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  Future<void> _boot() async {
    setState(() => _loading = true);
    try {
      final me = await _repo.me();
      _isAdmin = (me.role ?? '').toLowerCase() == 'admin';
      await _load();
      if (_isAdmin) await _loadAdmin();
    } catch (e) {
      if (mounted) _snack('فشل تحميل الصفحة: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    try {
      final res = await _repo.getMyAttendance();
      if (!mounted) return;
      setState(() {
        _inDuty = res.inDuty;
        _hours = res.workedHours;
        _logs = res.logs;
      });
    } catch (e) {
      if (mounted) _snack('فشل تحميل الحضور: $e');
    }
  }

  Future<void> _loadAdmin() async {
    try {
      final items = await _repo.adminAttendanceSummary(month: _month, filter: _adminFilter);
      if (!mounted) return;
      setState(() => _adminItems = items);
    } catch (e) {
      if (mounted) _snack('فشل تحميل حضور الموظفين: $e');
    }
  }

  /// ✅ تحضير يدوي: تأكيد سريع (PIN/كلمة مرور داخلية)
  /// ملاحظة: هذا التحقق محلي (UI) فقط.
  /// إذا تريد تحقق حقيقي: نخليه على السيرفر (verify-pin) لاحقًا.
  Future<bool> _confirmManual() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('تأكيد تسجيل الحضور/الانصراف'),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'أدخل PIN (أي رقم للتأكيد)',
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
    if (_inDuty) {
      _snack('أنت داخل الدوام بالفعل');
      return;
    }

    setState(() => _working = true);
    try {
      final ok = await _confirmManual();
      if (!ok) return;

      await _repo.checkIn(method: 'manual', shift: _selectedShift);
      if (mounted) {
        setState(() => _inDuty = true);
      }
      await _load();
      _snack('تم تسجيل دخول الدوام');
    } catch (e) {
      _snack('فشل تسجيل الدخول: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _checkOut() async {
    if (_working) return;
    if (!_inDuty) {
      _snack('أنت خارج الدوام');
      return;
    }

    setState(() => _working = true);
    try {
      final ok = await _confirmManual();
      if (!ok) return;

      await _repo.checkOut(method: 'manual', shift: _selectedShift);
      if (mounted) {
        setState(() => _inDuty = false);
      }
      await _load();
      _snack('تم تسجيل خروج الدوام');
    } catch (e) {
      _snack('فشل تسجيل الخروج: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myView = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _inDuty ? Icons.play_circle_fill : Icons.pause_circle_filled,
                        color: _inDuty ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _inDuty ? 'داخل الدوام' : 'خارج الدوام',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('ساعات العمل هذا الشهر: ${_hours.round()} ساعة'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedShift,
                    decoration: const InputDecoration(
                      labelText: 'اختيار وقت الدوام',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'morning', child: Text('صباحي 6:00 ص - 12:00 ظهرًا')),
                      DropdownMenuItem(value: 'evening', child: Text('مسائي 4:00 م - 9:00 م')),
                    ],
                    onChanged: _inDuty ? null : (v) => setState(() => _selectedShift = v ?? 'morning'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: (_working || _inDuty) ? null : _checkIn,
                          icon: const Icon(Icons.login),
                          label: Text(_working ? '...' : 'تسجيل حضور'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: (_working || !_inDuty) ? null : _checkOut,
                          icon: const Icon(Icons.logout),
                          label: Text(_working ? '...' : 'تسجيل انصراف'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('ملاحظة: الدوام الصباحي من 6:00 ص إلى 12:00 ظهرًا، والمسائي من 4:00 م إلى 9:00 م، والجمعة إجازة افتراضيًا.',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('آخر الحركات', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_logs.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد حركات')))
          else
            ..._logs.take(30).map(
                  (l) => Card(
                    child: ListTile(
                      leading: Icon(
                        l.type == 'in' ? Icons.login : Icons.logout,
                        color: l.type == 'in' ? Colors.green : Colors.red,
                      ),
                      title: Text(l.type == 'in' ? 'دخول' : 'خروج'),
                      subtitle: Text(l.ts.toString()),
                      trailing: Text(l.method ?? '-'),
                    ),
                  ),
                ),
          const SizedBox(height: 80),
        ],
      ),
    );

    final adminView = RefreshIndicator(
      onRefresh: _loadAdmin,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _month,
                  decoration: const InputDecoration(
                    labelText: 'الشهر (YYYY-MM)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => _month = v.trim(),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _adminFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('الكل')),
                  DropdownMenuItem(value: 'present', child: Text('حضور')),
                  DropdownMenuItem(value: 'absent', child: Text('غياب')),
                  DropdownMenuItem(value: 'late', child: Text('متأخر')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _adminFilter = v);
                  _loadAdmin();
                },
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loadAdmin,
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('مراقبة الموظفين', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_adminItems.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد بيانات')))
          else
            ..._adminItems.map(
              (it) => Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(it.username),
                  subtitle: Text(
                    'حضور: ${it.presentDays ?? 0} • غياب: ${it.absentDays ?? 0} • تأخير: ${it.lateMinutes ?? 0}د\n'
                    'ساعات: ${it.workedHours.round()} • خصومات: ${(it.deductions ?? 0).round()}',
                  ),
                  trailing: Text(
                    '${(it.netAmount ?? it.amount).round()} ر.ي',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );

    return Scaffold(
      appBar: CustomAppBar(title: 'الحضور والانصراف', centerTitle: true, showShadow: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_isAdmin
              ? myView
              : DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const Material(
                        color: Colors.transparent,
                        child: TabBar(
                          tabs: [
                            Tab(text: 'حضوري'),
                            Tab(text: 'الموظفين'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [myView, adminView],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
