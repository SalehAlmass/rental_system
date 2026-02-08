import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../payments/data/repositories/payments_repository_impl.dart';
import '../../domain/entities/models.dart';

class RentDetailsPage extends StatefulWidget {
  const RentDetailsPage({super.key, required this.rentId});
  final int rentId;

  @override
  State<RentDetailsPage> createState() => _RentDetailsPageState();
}

class _RentDetailsPageState extends State<RentDetailsPage> {
  late final ApiClient _api;
  late final PaymentsRepository _paymentsRepo;

  bool _loading = true;
  bool _closing = false;

  Rent? _rent;

  // ماليّات العقد (من Endpoint)
  double _total = 0;
  double _paid = 0;
  double _remaining = 0;
  bool _fullyPaid = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _paymentsRepo = PaymentsRepository(_api);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await _fetchFinancials();
    } catch (e) {
      if (!mounted) return;
      _snack('فشل تحميل تفاصيل العقد: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// ✅ Endpoint: GET rents/{id}/financials
  /// يرجع rent + total/paid/remaining/is_fully_paid
  Future<void> _fetchFinancials() async {
    final res = await _api.dio.get('rents/${widget.rentId}/financials');

    dynamic raw = res.data;
    if (raw is Map && raw['data'] != null) raw = raw['data'];

    if (raw is! Map) {
      throw Exception('Unexpected response: ${res.data}');
    }

    // rent
    final rentJson = (raw['rent'] is Map) ? (raw['rent'] as Map).cast<String, dynamic>() : null;
    if (rentJson == null) {
      throw Exception('financials: rent is missing');
    }

    final rent = Rent.fromJson(rentJson);

    // totals
    double numToDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    final total = numToDouble(raw['total_amount']);
    final paid = numToDouble(raw['paid_amount']);
    final remaining = numToDouble(raw['remaining']);
    final isFullyPaidServer = (raw['is_fully_paid'] == true);

    // ✅ أهم سطر: لا تسمح يظهر FullyPaid إذا العقد OPEN حتى لو السيرفر غلط
    final status = (rent.status ?? '').toLowerCase();
    final isOpen = status == 'open';
    final fullyPaidSafe = isOpen ? false : isFullyPaidServer;

    setState(() {
      _rent = rent;
      _total = total;
      _paid = paid;
      _remaining = remaining < 0 ? 0 : remaining;
      _fullyPaid = fullyPaidSafe;
    });
  }

  Future<void> _closeAndMaybePay() async {
    final rent = _rent;
    if (rent == null || _closing) return;

    setState(() => _closing = true);
    try {
      // ✅ إغلاق العقد
      await _api.dio.post(
        'rents/${rent.id}/close',
        data: {'end_datetime': DateTime.now().toIso8601String()},
      );

      // ✅ بعد الإغلاق: حدّث الماليّات من السيرفر
      await _fetchFinancials();

      if (!mounted) return;

      // إذا مازال فيه متبقي افتح الدفع
      if (_remaining > 0.0001) {
        await _showPayDialog(rent: rent);
      } else {
        _snack('تم إغلاق العقد وهو مسدد بالكامل');
      }
    } catch (e) {
      if (!mounted) return;
      _snack('فشل إغلاق العقد: $e');
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Future<void> _showPayDialog({required Rent rent}) async {
    if (!mounted) return;

    // ✅ تحديث قبل فتح الدفع (أمان)
    await _fetchFinancials();

    final status = (rent.status ?? '').toLowerCase();
    final isOpen = status == 'open';

    // ✅ منع الدفع إذا مسدد بالكامل (فقط بعد الإغلاق)
    if (!isOpen && _remaining <= 0.0001) {
      _snack('هذا العقد مسدد بالكامل ولا يمكن إنشاء سند جديد');
      return;
    }

    final maxPayable = _remaining;

    await showDialog(
      context: context,
      builder: (_) => _PayNowDialog(
        total: _total,
        alreadyPaid: _paid,
        maxPayable: maxPayable <= 0 ? 0 : maxPayable,
        // إذا العقد Open والسيرفر يرسل remaining=0 لأن الإجمالي غير نهائي
        // اسمح بالدفع بدون سقف إذا total/remaining غير منطقي
        unlimitedWhenOpen: isOpen && (_total <= 0.0001),
        onPay: (amount, method, notes) async {
          await _paymentsRepo.create(
            type: 'in',
            amount: amount,
            clientId: rent.clientId,
            rentId: rent.id,
            method: method,
            notes: notes,
          );
        },
      ),
    );

    // ✅ بعد إنشاء السند: حدّث الماليّات
    await _fetchFinancials();
  }

  @override
  Widget build(BuildContext context) {
    final rent = _rent;
    final status = ((rent?.status ?? '')).toLowerCase();
    final isOpen = status == 'open';

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل العقد'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (rent == null)
              ? const Center(child: Text('تعذر تحميل العقد'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _card(
                      title: 'معلومات العقد',
                      child: Column(
                        children: [
                          _kv('رقم العقد', '#${rent.id}'),
                          _kv('العميل', rent.clientName ?? rent.clientId.toString()),
                          _kv('المعدة', rent.equipmentName ?? rent.equipmentId.toString()),
                          _kv('الحالة', _statusText(rent.status)),
                          _kv('بداية', rent.startDatetime ?? '-'),
                          _kv('نهاية', rent.endDatetime ?? '-'),
                          const Divider(height: 18),
                          _kv('الإجمالي', '${_total.toStringAsFixed(2)} ر.س'),
                          _kv('المدفوع', '${_paid.toStringAsFixed(2)} ر.س'),
                          _kv('المتبقي', '${_remaining.toStringAsFixed(2)} ر.س'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ✅ Open: إغلاق + تسديد
                    if (isOpen)
                      FilledButton.icon(
                        onPressed: _closing ? null : _closeAndMaybePay,
                        icon: _closing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.lock),
                        label: Text(_closing ? 'جاري الإغلاق...' : 'إغلاق العقد + تسديد'),
                      ),

                    // ✅ Closed: تسديد المتبقي فقط، وتعطيل لو fullyPaid
                    if (!isOpen)
                      FilledButton.icon(
                        onPressed: _fullyPaid ? null : () => _showPayDialog(rent: rent),
                        icon: const Icon(Icons.payments_outlined),
                        label: Text(_fullyPaid ? 'العقد مسدد بالكامل' : 'تسديد المتبقي فقط'),
                      ),
                  ],
                ),
    );
  }

  String _statusText(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'open':
        return 'مفتوح (جاري)';
      case 'closed':
        return 'مغلق';
      case 'cancelled':
        return 'ملغي';
      default:
        return s ?? '-';
    }
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/* -------------------- PAY DIALOG -------------------- */

class _PayNowDialog extends StatefulWidget {
  const _PayNowDialog({
    required this.total,
    required this.alreadyPaid,
    required this.maxPayable,
    required this.onPay,
    this.unlimitedWhenOpen = false,
  });

  final double total;
  final double alreadyPaid;
  final double maxPayable;
  final bool unlimitedWhenOpen;

  final Future<void> Function(double amount, String method, String? notes) onPay;

  @override
  State<_PayNowDialog> createState() => _PayNowDialogState();
}

class _PayNowDialogState extends State<_PayNowDialog> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _method = 'cash';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // الافتراضي = المتبقي (أو صفر إذا unlimited)
    _amountCtrl.text = widget.unlimitedWhenOpen
        ? ''
        : widget.maxPayable.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_loading) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    if (amount <= 0) {
      _snack('أدخل مبلغ صحيح');
      return;
    }

    if (!widget.unlimitedWhenOpen && amount > widget.maxPayable + 0.0001) {
      _snack('لا يمكن تسديد أكثر من المتبقي على العقد');
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.onPay(
        amount,
        _method,
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      _snack('تم إنشاء سند القبض');
    } catch (e) {
      if (!mounted) return;
      _snack('فشل إنشاء السند: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تسديد العقد'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('إجمالي العقد: ${widget.total.toStringAsFixed(2)} ر.س'),
          Text('المدفوع سابقًا: ${widget.alreadyPaid.toStringAsFixed(2)} ر.س'),
          Text(
            widget.unlimitedWhenOpen
                ? 'المتبقي: غير نهائي (العقد جاري)'
                : 'المتبقي: ${widget.maxPayable.toStringAsFixed(2)} ر.س',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: widget.unlimitedWhenOpen ? 'مبلغ التسديد' : 'مبلغ التسديد (حتى المتبقي)',
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _method,
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('نقدًا')),
              DropdownMenuItem(value: 'bank', child: Text('تحويل بنكي')),
              DropdownMenuItem(value: 'card', child: Text('بطاقة')),
            ],
            onChanged: (v) => setState(() => _method = v ?? 'cash'),
            decoration: const InputDecoration(labelText: 'الطريقة'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('لاحقًا'),
        ),
        FilledButton(
          onPressed: _loading ? null : _pay,
          child: Text(_loading ? 'جاري...' : 'تسديد'),
        ),
      ],
    );
  }
}
