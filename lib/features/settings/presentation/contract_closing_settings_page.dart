import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/features/settings/data/contract_closing_settings_repository.dart';

class ContractClosingSettingsPage extends StatefulWidget {
  const ContractClosingSettingsPage({super.key});

  @override
  State<ContractClosingSettingsPage> createState() => _ContractClosingSettingsPageState();
}

class _ContractClosingSettingsPageState extends State<ContractClosingSettingsPage> {
  late final ContractClosingSettingsRepository _repo;
  bool _loading = true;
  bool _saving = false;
  String _hourPricingMode = 'ask';
  String _paymentReceiptMode = 'auto';

  @override
  void initState() {
    super.initState();
    _repo = ContractClosingSettingsRepository(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settings = await _repo.fetch();
      if (!mounted) return;
      setState(() {
        _hourPricingMode = settings.hourPricingMode;
        _paymentReceiptMode = settings.paymentReceiptMode;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تحميل الإعدادات: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final settings = await _repo.save(
        hourPricingMode: _hourPricingMode,
        paymentReceiptMode: _paymentReceiptMode,
      );
      if (!mounted) return;
      setState(() {
        _hourPricingMode = settings.hourPricingMode;
        _paymentReceiptMode = settings.paymentReceiptMode;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات الإغلاق بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سياسة إغلاق العقود'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('احتساب الساعات عند الإغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        RadioListTile<String>(
                          value: 'auto',
                          groupValue: _hourPricingMode,
                          onChanged: (v) => setState(() => _hourPricingMode = v ?? 'auto'),
                          title: const Text('تلقائي'),
                          subtitle: const Text('يطبق النظام احتساب الساعات الخاص تلقائيًا عند الإغلاق'),
                        ),
                        RadioListTile<String>(
                          value: 'ask',
                          groupValue: _hourPricingMode,
                          onChanged: (v) => setState(() => _hourPricingMode = v ?? 'ask'),
                          title: const Text('إشعار اختياري'),
                          subtitle: const Text('يظهر للموظف تنبيه يمكنه من تفعيل أو إلغاء الاحتساب الخاص'),
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('سند القبض عند الإغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        RadioListTile<String>(
                          value: 'auto',
                          groupValue: _paymentReceiptMode,
                          onChanged: (v) => setState(() => _paymentReceiptMode = v ?? 'auto'),
                          title: const Text('تلقائي'),
                          subtitle: const Text('إذا تم إدخال مبلغ مدفوع، يُنشأ سند قبض تلقائيًا'),
                        ),
                        RadioListTile<String>(
                          value: 'ask',
                          groupValue: _paymentReceiptMode,
                          onChanged: (v) => setState(() => _paymentReceiptMode = v ?? 'ask'),
                          title: const Text('إشعار اختياري'),
                          subtitle: const Text('يظهر للموظف خيار إنشاء السند أو تجاهله حسب الصلاحية'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'جاري الحفظ...' : 'حفظ السياسات'),
                ),
              ],
            ),
    );
  }
}
