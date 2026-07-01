import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../data/hr_repository.dart';

class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key});

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  late final HrRepository _repo;

  bool _loading = true;
  bool _isAdmin = false;

  String _month = _monthStr(DateTime.now());
  List<PayrollItem> _items = const [];

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
      // ✅ مصدر الحقيقة: السيرفر يحدد صلاحية المستخدم
      final me = await _repo.me(); // {role: 'admin' ...}
      _isAdmin = (me.role ?? '').toLowerCase() == 'admin';

      if (_isAdmin) {
        final items = await _repo.payrollSummary(month: _month);
        _items = items;
      }
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (mounted) _snack('فشل تحميل الصفحة: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _repo.payrollSummary(month: _month);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (mounted) _snack('فشل تحميل الرواتب: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'الرواتب', centerTitle: true, showShadow: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (!_isAdmin)
              ? const Center(child: Text('هذه الصفحة للمدير فقط'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
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
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('تحديث'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _items.isEmpty
                          ? const Center(child: Text('لا توجد بيانات'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _items.length,
                              itemBuilder: (context, i) {
                                final it = _items[i];
                                return Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.person),
                                    title: Text(it.username),
                                    subtitle: Text(
                                      'ساعات: ${it.workedHours.round()} • غياب: ${it.absentDays ?? 0} • تأخير: ${it.lateMinutes ?? 0}د\n'
                                      'خصومات: ${(it.deductions ?? 0).round()} • نوع: ${it.salaryType ?? '-'}',
                                    ),
                                    trailing: Text(
                                      '${(it.netAmount ?? it.amount).round()} ${AppConfig.currencySymbol}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    onTap: () => _openEdit(it),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _openEdit(PayrollItem it) async {
    final typeCtrl = ValueNotifier<String>(it.salaryType ?? 'hourly');
    final hourlyCtrl =
        TextEditingController(text: (it.hourlyRate ?? 0).round().toString());
    final monthlyCtrl =
        TextEditingController(text: (it.monthlySalary ?? 0).round().toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('إعدادات راتب: ${it.username}'),
        content: ValueListenableBuilder<String>(
          valueListenable: typeCtrl,
          builder: (_, t, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: t,
                decoration: const InputDecoration(labelText: 'نوع الراتب'),
                items: const [
                  DropdownMenuItem(value: 'hourly', child: Text('بالساعة')),
                  DropdownMenuItem(value: 'monthly', child: Text('شهري')),
                ],
                onChanged: (v) => typeCtrl.value = v ?? 'hourly',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hourlyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'أجر الساعة'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: monthlyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'راتب شهري (اختياري)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _repo.updatePayrollSettings(
        userId: it.userId,
        salaryType: typeCtrl.value,
        hourlyRate: double.tryParse(hourlyCtrl.text.trim()),
        monthlySalary: double.tryParse(monthlyCtrl.text.trim()),
      );
      if (!mounted) return;
      _snack('تم الحفظ');
      await _load();
    } catch (e) {
      if (mounted) _snack('فشل الحفظ: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
