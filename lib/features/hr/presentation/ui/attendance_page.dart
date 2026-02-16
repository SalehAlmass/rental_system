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

  bool _inDuty = false;
  double _hours = 0;
  List<AttendanceLog> _logs = const [];

  @override
  void initState() {
    super.initState();
    _repo = HrRepository(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
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
    } finally {
      if (mounted) setState(() => _loading = false);
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

      await _repo.checkIn(method: 'manual');
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

      await _repo.checkOut(method: 'manual');
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
    return Scaffold(
      appBar: CustomAppBar(title: 'الحضور والانصراف', centerTitle: true, showShadow: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
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
                          Text('ساعات العمل هذا الشهر: ${_hours.toStringAsFixed(2)} ساعة'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _working ? null : _checkIn,
                                  icon: const Icon(Icons.login),
                                  label: Text(_working ? '...' : 'تسجيل حضور'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: _working ? null : _checkOut,
                                  icon: const Icon(Icons.logout),
                                  label: Text(_working ? '...' : 'تسجيل انصراف'),
                                ),
                              ),
                            ],
                          ),
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
            ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
