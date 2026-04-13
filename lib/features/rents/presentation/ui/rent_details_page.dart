import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_client.dart';
import '../../../payments/data/repositories/payments_repository_impl.dart';
import '../../../payments/domain/entities/models.dart';
import '../../../payments/presentation/ui/payment_details_page.dart';
import '../../../settings/data/contract_closing_settings_repository.dart';
import '../../data/repositories/rents_repository_impl.dart';
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
  late final RentsRepository _rentsRepo;
  late final ContractClosingSettingsRepository _closingSettingsRepo;

  bool _loading = true;
  bool _closing = false;
  bool _savingFollowup = false;

  Rent? _rent;
  List<Payment> _rentPayments = const [];
  List<Rent> _clientOutstandingRents = const [];
  List<CollectionFollowup> _followups = const [];
  List<CollectionFollowup> _clientFollowups = const [];
  double _total = 0;
  double _paid = 0;
  double _remaining = 0;
  bool _fullyPaid = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _paymentsRepo = PaymentsRepository(_api);
    _rentsRepo = RentsRepository(_api);
    _closingSettingsRepo = ContractClosingSettingsRepository(_api);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await _fetchFinancials();
      await _fetchRentPayments();
      await _fetchClientOutstandingRents();
      await _fetchCollectionFollowups();
      await _fetchClientFollowups();
    } catch (e) {
      if (!mounted) return;
      _snack('فشل تحميل تفاصيل العقد: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchFinancials() async {
    final res = await _api.dio.get('rents/${widget.rentId}/financials');

    dynamic raw = res.data;
    if (raw is Map && raw['data'] != null) raw = raw['data'];
    if (raw is! Map) {
      throw Exception('Unexpected response: ${res.data}');
    }

    final rentJson = (raw['rent'] is Map)
        ? (raw['rent'] as Map).cast<String, dynamic>()
        : null;
    if (rentJson == null) {
      throw Exception('financials: rent is missing');
    }

    final rent = Rent.fromJson(rentJson);

    double numToDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    final total = numToDouble(raw['total_amount']);
    final paid = numToDouble(raw['paid_amount']);
    final remaining = numToDouble(raw['remaining_amount'] ?? raw['remaining']);
    final isPaidServer = (raw['is_paid'] == true) || (raw['is_fully_paid'] == true);

    final status = (rent.status ?? '').toLowerCase();
    final isOpen = status == 'open';
    final fullyPaidSafe = isOpen ? false : isPaidServer;

    setState(() {
      _rent = rent;
      _total = total;
      _paid = paid;
      _remaining = remaining < 0 ? 0 : remaining;
      _fullyPaid = fullyPaidSafe;
    });
  }

  Future<void> _fetchRentPayments() async {
    final items = await _paymentsRepo.list(rentId: widget.rentId, showVoided: true);
    if (!mounted) return;
    setState(() => _rentPayments = items);
  }

  Future<void> _fetchClientOutstandingRents() async {
    final rent = _rent;
    if (rent == null) return;

    final items = await _rentsRepo.list(clientId: rent.clientId);
    final outstanding = items.where((item) {
      if (item.id == rent.id) return false;
      final remaining = _remainingFor(item);
      return remaining > 0.009 && (item.status ?? '').toLowerCase() != 'cancelled';
    }).toList();

    if (!mounted) return;
    setState(() => _clientOutstandingRents = outstanding);
  }

  Future<void> _fetchCollectionFollowups() async {
    final res = await _api.dio.get('rents/${widget.rentId}/collection-followups');
    dynamic raw = res.data;
    if (raw is Map) raw = raw['data'] ?? raw['items'] ?? raw['followups'] ?? [];
    if (raw is! List) raw = [];
    final items = raw
        .whereType<Map>()
        .map((e) => CollectionFollowup.fromJson(e.cast<String, dynamic>()))
        .toList();
    if (!mounted) return;
    setState(() => _followups = items);
  }


  Future<void> _fetchClientFollowups() async {
    final rent = _rent;
    if (rent == null) return;
    final res = await _api.dio.get('clients/${rent.clientId}/collection-followups');
    dynamic raw = res.data;
    if (raw is Map) raw = raw['data'] ?? raw['items'] ?? raw['followups'] ?? [];
    if (raw is! List) raw = [];
    final items = raw
        .whereType<Map>()
        .map((e) => CollectionFollowup.fromJson(e.cast<String, dynamic>()))
        .toList();
    if (!mounted) return;
    setState(() => _clientFollowups = items);
  }

  Future<void> _createCollectionFollowup(_CollectionFollowupDraft draft, {bool allowDuplicateToday = false}) async {
    final rent = _rent;
    if (rent == null || _savingFollowup) return;
    setState(() => _savingFollowup = true);
    try {
      await _api.dio.post(
        'rents/${rent.id}/collection-followups',
        data: {
          'contact_type': draft.contactType,
          'outcome': draft.outcome,
          'note': draft.note,
          'next_followup_at': draft.nextFollowupAt?.toIso8601String(),
          'allow_duplicate_today': allowDuplicateToday,
        },
      );
      await _fetchCollectionFollowups();
      await _fetchClientFollowups();
      if (!mounted) return;
      _snack('تم حفظ متابعة التحصيل');
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final msg = data is Map && data['error'] != null ? data['error'].toString() : e.message ?? e.toString();
      _snack('فشل حفظ متابعة التحصيل: $msg');
    } catch (e) {
      if (!mounted) return;
      _snack('فشل حفظ متابعة التحصيل: $e');
    } finally {
      if (mounted) setState(() => _savingFollowup = false);
    }
  }


  String _followupActor(CollectionFollowup item) {
    final name = item.createdByName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'الموظف #${item.createdByUserId ?? '-'}';
  }

  Future<void> _openCollectionFollowupDialog() async {
    final todays = _todayClientFollowup;
    if (todays != null) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم التواصل اليوم مع هذا العميل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('آخر متابعة اليوم كانت ${_fmtDateTime(todays.createdAt)}'),
              const SizedBox(height: 8),
              Text('النوع: ${todays.contactTypeLabel}'),
              Text('النتيجة: ${todays.outcomeLabel}'),
              Text('الموظف: ${_followupActor(todays)}'),
              if ((todays.note ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('ملاحظة: ${todays.note!.trim()}'),
              ],
              const SizedBox(height: 12),
              const Text('حتى لا يتكرر التواصل مع نفس العميل في نفس اليوم، راجع المتابعة السابقة أولاً.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            OutlinedButton(onPressed: () {
              Navigator.pop(context, false);
              _showFollowupsSheet(context);
            }, child: const Text('عرض السجل')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إضافة متابعة إضافية')),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final draft = await showDialog<_CollectionFollowupDraft>(
      context: context,
      builder: (_) => _CollectionFollowupDialog(initialHint: todays == null ? null : 'تم التواصل اليوم بواسطة ${_followupActor(todays)} • ${todays.contactTypeLabel} • ${todays.outcomeLabel}'),
    );
    if (draft == null) return;
    await _createCollectionFollowup(draft, allowDuplicateToday: todays != null);
  }

  Future<void> _closeContract() async {
    final rent = _rent;
    if (rent == null || _closing) return;

    try {
      final settings = await _closingSettingsRepo.fetch();
      if (!mounted) return;

      final result = await showDialog<_CloseContractResult>(
        context: context,
        builder: (_) => _CloseContractDialog(
          rent: rent,
          settings: settings,
          currentPaid: _paid,
        ),
      );

      if (result == null) return;

      setState(() => _closing = true);
      await _rentsRepo.closeRent(
        rentId: rent.id,
        endDatetime: DateTime.now().toIso8601String(),
        applySpecialPricing: result.applySpecialPricing,
        paidAmount: result.paidAmount,
        paymentMethod: result.paymentMethod,
        createReceipt: result.createReceipt,
        paymentNotes: result.paymentNotes,
        idempotencyKey: 'rent_close_${rent.id}_${DateTime.now().millisecondsSinceEpoch}',
      );

      await _load();
      if (!mounted) return;
      _snack('تم إغلاق العقد بنجاح');
    } catch (e) {
      if (!mounted) return;
      _snack('فشل إغلاق العقد: $e');
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Future<void> _showPayDialog({required Rent rent}) async {
    if (!mounted) return;

    await _fetchFinancials();

    final status = (rent.status ?? '').toLowerCase();
    final isOpen = status == 'open';

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
        unlimitedWhenOpen: isOpen && (_total <= 0.0001),
        onPay: (amount, method, notes) async {
          final idemKey = 'rent_${rent.id}_${DateTime.now().microsecondsSinceEpoch}';
          await _paymentsRepo.create(
            type: 'in',
            amount: amount,
            clientId: rent.clientId,
            rentId: rent.id,
            method: method,
            notes: notes,
            idempotencyKey: idemKey,
          );
        },
      ),
    );

    await _fetchFinancials();
    await _fetchRentPayments();
  }

  double _remainingFor(Rent rent) {
    final direct = rent.remainingAmount;
    if (direct != null) return direct < 0 ? 0 : direct;
    final total = rent.totalAmount ?? 0;
    final paid = rent.paidAmount ?? rent.closingPaidAmount ?? 0;
    final remaining = total - paid;
    return remaining > 0 ? remaining : 0;
  }

  Payment? get _lastPayment {
    final valid = _rentPayments.where((p) => !p.isVoid).toList();
    if (valid.isEmpty) return null;
    valid.sort((a, b) {
      final ad = DateTime.tryParse((a.createdAt ?? '').replaceFirst(' ', 'T')) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse((b.createdAt ?? '').replaceFirst(' ', 'T')) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return valid.first;
  }

  CollectionFollowup? get _latestFollowup => _followups.isEmpty ? null : _followups.first;
  CollectionFollowup? get _latestClientFollowup => _clientFollowups.isEmpty ? null : _clientFollowups.first;
  CollectionFollowup? get _todayClientFollowup {
    for (final item in _clientFollowups) {
      final dt = _tryParse(item.createdAt);
      if (dt == null) continue;
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return item;
      }
    }
    return null;
  }

  DateTime? _tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }

  bool get _hasDeferredPayment => _remaining > 0.009;

  bool get _isCollectionDelayed {
    if (!_hasDeferredPayment) return false;
    final status = (_rent?.status ?? '').toLowerCase();
    if (status != 'closed') return false;
    final closedAt = DateTime.tryParse((_rent?.closedAt ?? '').replaceFirst(' ', 'T'));
    if (closedAt == null) return false;
    return DateTime.now().difference(closedAt).inDays >= 3;
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
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
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
                            _kv('بداية', _fmtDateTime(rent.startDatetime)),
                            _kv('نهاية', rent.endDatetime == null ? '-' : _fmtDateTime(rent.endDatetime!)),
                            const Divider(height: 18),
                            _kv('الإجمالي', isOpen && _total <= 0.0001 ? 'غير نهائي (العقد جاري)' : '${_total.toStringAsFixed(2)} ر.س'),
                            _kv('المدفوع', '${_paid.toStringAsFixed(2)} ر.س'),
                            _kv('المتبقي', isOpen && _total <= 0.0001 ? '-' : '${_remaining.toStringAsFixed(2)} ر.س'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _card(
                        title: 'معلومات الإغلاق',
                        child: Column(
                          children: [
                            _kv('وقت الإغلاق', rent.closedAt == null ? '-' : _fmtDateTime(rent.closedAt!)),
                            _kv('رقم المستخدم', rent.closedByUserId?.toString() ?? '-'),
                            _kv('المبلغ عند الإغلاق', '${(rent.closingPaidAmount ?? 0).toStringAsFixed(2)} ر.س'),
                            _kv('طريقة الدفع', _paymentMethodText(rent.closingPaymentMethod)),
                            _kv('حالة السند', _receiptStatusText(rent.closingPaymentStatus)),
                            _kv('رقم السند', rent.closingPaymentId?.toString() ?? '-'),
                            _kv('طريقة الاحتساب', rent.pricingRuleLabel ?? 'الاحتساب القياسي'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _card(
                        title: 'حالة التحصيل',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_hasDeferredPayment) _buildCollectionBanner(context),
                            _buildFinancialStrip(isOpen: isOpen),
                            const SizedBox(height: 12),
                            _buildLastPaymentCard(context),
                            const SizedBox(height: 12),
                            _buildFollowupCard(context),
                            if (_clientOutstandingRents.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildOtherOutstandingBanner(),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => _showPayDialog(rent: rent),
                                  icon: const Icon(Icons.add_card_outlined),
                                  label: const Text('إضافة دفعة'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _rentPayments.isEmpty
                                      ? null
                                      : () => _showPaymentsSheet(context),
                                  icon: const Icon(Icons.receipt_long_outlined),
                                  label: Text(_rentPayments.isEmpty ? 'لا توجد سندات' : 'عرض السندات (${_rentPayments.length})'),
                                ),
                                if (isOpen)
                                  FilledButton.tonalIcon(
                                    onPressed: _closing ? null : _closeContract,
                                    icon: Icon(_closing ? Icons.hourglass_top : Icons.lock_outline),
                                    label: Text(_closing ? 'جاري الإغلاق...' : 'إغلاق العقد'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCollectionBanner(BuildContext context) {
    final color = _isCollectionDelayed ? Colors.red : Colors.orange;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(
            _isCollectionDelayed ? Icons.warning_amber_rounded : Icons.account_balance_wallet_outlined,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCollectionDelayed ? 'تأخر في السداد لهذا العقد' : 'يوجد مبلغ متبقٍ على العميل',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text('المتبقي الحالي: ${_remaining.toStringAsFixed(2)} ر.س'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialStrip({required bool isOpen}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: _miniMetric('إجمالي العقد', isOpen && _total <= 0.0001 ? 'جاري' : '${_total.toStringAsFixed(2)} ر.س')),
          const SizedBox(width: 8),
          Expanded(child: _miniMetric('المدفوع', '${_paid.toStringAsFixed(2)} ر.س')),
          const SizedBox(width: 8),
          Expanded(child: _miniMetric('المتبقي', isOpen && _total <= 0.0001 ? '-' : '${_remaining.toStringAsFixed(2)} ر.س')),
        ],
      ),
    );
  }

  Widget _buildLastPaymentCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('آخر دفعة', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (_lastPayment == null)
            Text('لا توجد دفعات مسجلة حتى الآن', style: Theme.of(context).textTheme.bodyMedium)
          else ...[
            _kv('تاريخ آخر دفعة', _fmtDateTime(_lastPayment!.createdAt)),
            _kv('آخر مبلغ مدفوع', '${_lastPayment!.amount.toStringAsFixed(2)} ر.س'),
            _kv('رقم آخر سند', '#${_lastPayment!.id}'),
            _kv('طريقة التحصيل الأخيرة', _paymentMethodText(_lastPayment!.method)),
          ],
        ],
      ),
    );
  }

  Widget _buildFollowupCard(BuildContext context) {
    final latest = _latestFollowup;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'متابعة التحصيل',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _savingFollowup ? null : _openCollectionFollowupDialog,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('إضافة متابعة'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_todayClientFollowup != null) ...[
            _buildTodayContactBanner(_todayClientFollowup!),
            const SizedBox(height: 10),
          ],
          if (latest == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('لا توجد متابعة تحصيل مسجلة لهذا العقد حتى الآن'),
            )
          else ...[
            _kv('آخر تواصل', _fmtDateTime(latest.createdAt)),
            _kv('نوع المتابعة', latest.contactTypeLabel),
            _kv('النتيجة', latest.outcomeLabel),
            _kv('الموظف', _followupActor(latest)),
            _kv('الملاحظة', latest.note?.trim().isEmpty ?? true ? '-' : latest.note!.trim()),
            _kv('المتابعة القادمة', latest.nextFollowupAt == null ? '-' : _fmtDateTime(latest.nextFollowupAt)),
            if (_followups.length > 1) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showFollowupsSheet(context),
                icon: const Icon(Icons.history),
                label: Text('عرض كل المتابعات (${_followups.length})'),
              ),
            ],
          ],
        ],
      ),
    );
  }


  Widget _buildTodayContactBanner(CollectionFollowup item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تم التواصل مع هذا العميل اليوم', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('بواسطة: ${_followupActor(item)} • ${_fmtDateTime(item.createdAt)}'),
          Text('النوع: ${item.contactTypeLabel} • النتيجة: ${item.outcomeLabel}'),
          if ((item.note ?? '').trim().isNotEmpty)
            Text('الملاحظة: ${item.note!.trim()}'),
        ],
      ),
    );
  }

  Widget _buildOtherOutstandingBanner() {
    final totalOutstanding = _clientOutstandingRents.fold<double>(0, (sum, item) => sum + _remainingFor(item));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️ هذا العميل لديه عقود أخرى غير مسددة', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('عدد العقود الأخرى: ${_clientOutstandingRents.length} • إجمالي المتبقي: ${totalOutstanding.toStringAsFixed(2)} ر.س'),
        ],
      ),
    );
  }

  Future<void> _showPaymentsSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('سندات العقد', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _rentPayments.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final payment = _rentPayments[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: payment.isVoid ? Colors.red.withOpacity(0.12) : Colors.green.withOpacity(0.12),
                        child: Icon(payment.isVoid ? Icons.block : Icons.receipt, color: payment.isVoid ? Colors.red : Colors.green),
                      ),
                      title: Text('#${payment.id} • ${payment.amount.toStringAsFixed(2)} ر.س'),
                      subtitle: Text('${_paymentMethodText(payment.method)} • ${_fmtDateTime(payment.createdAt)}'),
                      trailing: payment.isVoid ? const Text('ملغي', style: TextStyle(color: Colors.red)) : null,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          this.context,
                          MaterialPageRoute(builder: (_) => PaymentDetailsPage(paymentId: payment.id , payment: payment,)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFollowupsSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('سجل متابعات التحصيل', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _followups.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final item = _followups[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.withOpacity(0.12),
                        child: const Icon(Icons.phone_in_talk_outlined, color: Colors.orange),
                      ),
                      title: Text('${item.contactTypeLabel} • ${item.outcomeLabel}'),
                      subtitle: Text('${_fmtDateTime(item.createdAt)}\n${item.note?.trim().isEmpty ?? true ? 'بدون ملاحظة' : item.note!.trim()}'),
                      isThreeLine: true,
                      trailing: item.createdByName == null ? null : Text(item.createdByName!, style: const TextStyle(fontSize: 12)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _statusText(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'open':
        return 'مفتوح (جاري)';
      case 'closed':
        return _fullyPaid ? 'مغلق - مسدد' : 'مغلق - عليه متبقٍ';
      case 'cancelled':
        return 'ملغي';
      default:
        return s ?? '-';
    }
  }

  String _paymentMethodText(String? method) {
    switch ((method ?? '').toLowerCase()) {
      case 'cash':
        return 'نقد';
      case 'bank':
        return 'تحويل';
      case 'card':
        return 'بطاقة';
      default:
        return method == null || method.isEmpty ? '-' : method;
    }
  }

  String _receiptStatusText(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'created':
        return 'تم إنشاء سند';
      case 'manual':
        return 'تم يدويًا';
      case 'not_created':
        return 'لم يتم إنشاء سند';
      default:
        return status == null || status.isEmpty ? '-' : status;
    }
  }

  String _fmtDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final dt = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (dt == null) return raw;
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 126, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
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

class CollectionFollowup {
  const CollectionFollowup({
    required this.id,
    required this.rentId,
    required this.clientId,
    required this.contactType,
    required this.createdAt,
    this.outcome,
    this.note,
    this.nextFollowupAt,
    this.createdByUserId,
    this.createdByName,
  });

  final int id;
  final int rentId;
  final int clientId;
  final String contactType;
  final String createdAt;
  final String? outcome;
  final String? note;
  final String? nextFollowupAt;
  final int? createdByUserId;
  final String? createdByName;

  factory CollectionFollowup.fromJson(Map<String, dynamic> json) {
    int toI(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    int? toINull(dynamic v) {
      if (v == null) return null;
      final x = toI(v);
      return x == 0 ? null : x;
    }
    return CollectionFollowup(
      id: toI(json['id']),
      rentId: toI(json['rent_id']),
      clientId: toI(json['client_id']),
      contactType: (json['contact_type'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      outcome: json['outcome']?.toString(),
      note: json['note']?.toString(),
      nextFollowupAt: json['next_followup_at']?.toString(),
      createdByUserId: toINull(json['created_by_user_id']),
      createdByName: json['created_by_name']?.toString(),
    );
  }

  String get contactTypeLabel {
    switch (contactType.toLowerCase()) {
      case 'call':
        return 'اتصال';
      case 'whatsapp':
        return 'واتساب';
      case 'visit':
        return 'زيارة';
      case 'verbal':
        return 'تذكير شفهي';
      case 'no_answer':
        return 'لم يتم الرد';
      default:
        return contactType.isEmpty ? '-' : contactType;
    }
  }

  String get outcomeLabel {
    switch ((outcome ?? '').toLowerCase()) {
      case 'promise_to_pay':
        return 'وعد بالسداد';
      case 'follow_up_later':
        return 'متابعة لاحقة';
      case 'paid':
        return 'تم التحصيل';
      case 'customer_requested_delay':
        return 'تأجيل بطلب العميل';
      case 'no_answer':
        return 'لا يرد';
      case 'other':
        return 'أخرى';
      default:
        return outcome == null || outcome!.isEmpty ? '-' : outcome!;
    }
  }
}

class _CollectionFollowupDraft {
  const _CollectionFollowupDraft({
    required this.contactType,
    required this.outcome,
    required this.note,
    this.nextFollowupAt,
  });

  final String contactType;
  final String outcome;
  final String note;
  final DateTime? nextFollowupAt;
}

class _CloseContractResult {
  const _CloseContractResult({
    required this.applySpecialPricing,
    required this.paidAmount,
    required this.paymentMethod,
    required this.createReceipt,
    this.paymentNotes,
  });

  final bool applySpecialPricing;
  final double paidAmount;
  final String paymentMethod;
  final bool createReceipt;
  final String? paymentNotes;
}

class _CloseContractDialog extends StatefulWidget {
  const _CloseContractDialog({
    required this.rent,
    required this.settings,
    required this.currentPaid,
  });

  final Rent rent;
  final ContractClosingSettings settings;
  final double currentPaid;

  @override
  State<_CloseContractDialog> createState() => _CloseContractDialogState();
}

class _CloseContractDialogState extends State<_CloseContractDialog> {
  late final TextEditingController _paidCtrl;
  late final TextEditingController _notesCtrl;
  late bool _applySpecialPricing;
  late bool _createReceipt;
  String _method = 'cash';

  @override
  void initState() {
    super.initState();
    _paidCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    final hours = _hoursSpent;
    _applySpecialPricing = hours > 0 && hours <= 24;
    _createReceipt = widget.settings.shouldAutoCreateReceipt;
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _hoursSpent {
    final start = DateTime.tryParse(widget.rent.startDatetime);
    if (start == null) return widget.rent.hours ?? 0;
    final diff = DateTime.now().difference(start).inMinutes / 60.0;
    return diff < 0 ? 0 : diff;
  }

  String get _suggestedPricingText {
    if (_hoursSpent <= 0 || _hoursSpent > 24) {
      return 'سيتم استخدام الاحتساب القياسي الحالي';
    }
    if (_hoursSpent < 3) {
      return 'الاحتساب المقترح: أقل من 3 ساعات = ثلثي السعر اليومي';
    }
    return 'الاحتساب المقترح: 3 ساعات فأكثر = يوم كامل';
  }

  void _submit() {
    final paidAmount = double.tryParse(_paidCtrl.text.trim()) ?? 0;
    Navigator.pop(
      context,
      _CloseContractResult(
        applySpecialPricing: _applySpecialPricing,
        paidAmount: paidAmount,
        paymentMethod: _method,
        createReceipt: _createReceipt && paidAmount > 0,
        paymentNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shouldAskPricing = widget.settings.shouldAskForSpecialPricing;
    final shouldAskReceipt = widget.settings.shouldAskForReceipt;

    return AlertDialog(
      title: const Text('إغلاق العقد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('مدة العقد الحالية: ${_hoursSpent.toStringAsFixed(2)} ساعة'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_suggestedPricingText),
            ),
            const SizedBox(height: 12),
            if (shouldAskPricing)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _applySpecialPricing,
                title: const Text('تفعيل احتساب الساعات الخاص'),
                subtitle: const Text('يمكن للموظف تفعيله أو إلغاؤه حسب سياسة المدير'),
                onChanged: (v) => setState(() => _applySpecialPricing = v),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.verified_outlined),
                title: const Text('طريقة احتساب الساعات'),
                subtitle: Text(_applySpecialPricing ? 'مفعلة تلقائيًا' : 'احتساب قياسي تلقائي'),
              ),
            const Divider(height: 20),
            TextField(
              controller: _paidCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'المبلغ المدفوع عند الإغلاق',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _method,
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('نقد')),
                DropdownMenuItem(value: 'bank', child: Text('تحويل')),
                DropdownMenuItem(value: 'card', child: Text('بطاقة')),
              ],
              onChanged: (v) => setState(() => _method = v ?? 'cash'),
              decoration: const InputDecoration(
                labelText: 'طريقة الدفع',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (shouldAskReceipt)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _createReceipt,
                title: const Text('إنشاء سند قبض'),
                subtitle: const Text('هذا الخيار إشعار اختياري حسب صلاحية المدير'),
                onChanged: (v) => setState(() => _createReceipt = v),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_long),
                title: const Text('سند القبض'),
                subtitle: Text(widget.settings.shouldAutoCreateReceipt ? 'سيتم إنشاؤه تلقائيًا عند وجود مبلغ مدفوع' : 'لن يتم إنشاؤه تلقائيًا'),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'ملاحظة السند أو الإغلاق',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.lock_outline),
          label: const Text('اعتماد الإغلاق'),
        ),
      ],
    );
  }
}

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
    _amountCtrl.text = widget.unlimitedWhenOpen ? '' : widget.maxPayable.toStringAsFixed(2);
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
      await widget.onPay(amount, _method, _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim());
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
            widget.unlimitedWhenOpen ? 'المتبقي: غير نهائي (العقد جاري)' : 'المتبقي: ${widget.maxPayable.toStringAsFixed(2)} ر.س',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: widget.unlimitedWhenOpen ? 'مبلغ التسديد' : 'مبلغ التسديد (حتى المتبقي)'),
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
        TextButton(onPressed: _loading ? null : () => Navigator.pop(context), child: const Text('لاحقًا')),
        FilledButton(onPressed: _loading ? null : _pay, child: Text(_loading ? 'جاري...' : 'تسديد')),
      ],
    );
  }
}

class _CollectionFollowupDialog extends StatefulWidget {
  const _CollectionFollowupDialog({this.initialHint});

  final String? initialHint;

  @override
  State<_CollectionFollowupDialog> createState() => _CollectionFollowupDialogState();
}

class _CollectionFollowupDialogState extends State<_CollectionFollowupDialog> {
  final TextEditingController _noteCtrl = TextEditingController();
  String _contactType = 'call';
  String _outcome = 'follow_up_later';
  DateTime? _nextFollowupAt;

  DateTime _smartBaseDate(int days, {int hour = 9, int minute = 0}) {
    final now = DateTime.now();
    final base = now.add(Duration(days: days));
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  void _applySuggestedSchedule(DateTime? value, {String? note}) {
    setState(() {
      _nextFollowupAt = value;
      if (note != null && _noteCtrl.text.trim().isEmpty) {
        _noteCtrl.text = note;
      }
    });
  }

  void _applyOutcomeSuggestion(String outcome) {
    switch (outcome) {
      case 'promise_to_pay':
        _applySuggestedSchedule(_smartBaseDate(1, hour: 10), note: 'وعد العميل بالسداد غدًا');
        break;
      case 'customer_requested_delay':
        _applySuggestedSchedule(_smartBaseDate(2, hour: 10), note: 'طلب العميل مهلة قصيرة قبل السداد');
        break;
      case 'follow_up_later':
        _applySuggestedSchedule(_smartBaseDate(1, hour: 16));
        break;
      case 'no_answer':
        _applySuggestedSchedule(_smartBaseDate(0, hour: DateTime.now().hour + 2 > 20 ? 20 : DateTime.now().hour + 2, minute: 0), note: 'لم يرد العميل، تحتاج إعادة محاولة');
        break;
      case 'paid':
        _applySuggestedSchedule(null);
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickNextDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      initialDate: now,
      lastDate: DateTime(now.year + 3),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (!mounted) return;
    setState(() {
      _nextFollowupAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 9,
        time?.minute ?? 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة متابعة تحصيل'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.initialHint != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(widget.initialHint!),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              value: _contactType,
              items: const [
                DropdownMenuItem(value: 'call', child: Text('اتصال')),
                DropdownMenuItem(value: 'whatsapp', child: Text('واتساب')),
                DropdownMenuItem(value: 'visit', child: Text('زيارة')),
                DropdownMenuItem(value: 'verbal', child: Text('تذكير شفهي')),
                DropdownMenuItem(value: 'no_answer', child: Text('لم يتم الرد')),
              ],
              onChanged: (v) => setState(() => _contactType = v ?? 'call'),
              decoration: const InputDecoration(labelText: 'نوع المتابعة', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _outcome,
              items: const [
                DropdownMenuItem(value: 'promise_to_pay', child: Text('وعد بالسداد')),
                DropdownMenuItem(value: 'follow_up_later', child: Text('متابعة لاحقة')),
                DropdownMenuItem(value: 'paid', child: Text('تم التحصيل')),
                DropdownMenuItem(value: 'customer_requested_delay', child: Text('تأجيل بطلب العميل')),
                DropdownMenuItem(value: 'no_answer', child: Text('لا يرد')),
                DropdownMenuItem(value: 'other', child: Text('أخرى')),
              ],
              onChanged: (v) {
                final next = v ?? 'follow_up_later';
                setState(() => _outcome = next);
                _applyOutcomeSuggestion(next);
              },
              decoration: const InputDecoration(labelText: 'النتيجة', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ملاحظة المتابعة',
                border: OutlineInputBorder(),
                hintText: 'مثال: تم التواصل مع العميل ووعد بالسداد غدًا',
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'جدولة ذكية للمتابعة',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.today_outlined, size: 18),
                  label: const Text('اليوم مساءً'),
                  onPressed: () => _applySuggestedSchedule(_smartBaseDate(0, hour: 18), note: 'متابعة مسائية مجدولة'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.wb_sunny_outlined, size: 18),
                  label: const Text('غدًا'),
                  onPressed: () => _applySuggestedSchedule(_smartBaseDate(1, hour: 10), note: 'متابعة مجدولة للغد'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.event_repeat_outlined, size: 18),
                  label: const Text('بعد يومين'),
                  onPressed: () => _applySuggestedSchedule(_smartBaseDate(2, hour: 10), note: 'متابعة مجدولة بعد يومين'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_view_week_outlined, size: 18),
                  label: const Text('الأسبوع القادم'),
                  onPressed: () => _applySuggestedSchedule(_smartBaseDate(7, hour: 10), note: 'متابعة مجدولة للأسبوع القادم'),
                ),
                if (_nextFollowupAt != null)
                  ActionChip(
                    avatar: const Icon(Icons.clear, size: 18),
                    label: const Text('مسح الموعد'),
                    onPressed: () => _applySuggestedSchedule(null),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('موعد المتابعة القادمة'),
              subtitle: Text(_nextFollowupAt == null ? 'غير محدد' : '${_nextFollowupAt!.year}-${_nextFollowupAt!.month.toString().padLeft(2, '0')}-${_nextFollowupAt!.day.toString().padLeft(2, '0')} ${_nextFollowupAt!.hour.toString().padLeft(2, '0')}:${_nextFollowupAt!.minute.toString().padLeft(2, '0')}'),
              trailing: TextButton(onPressed: _pickNextDate, child: const Text('تحديد')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              _CollectionFollowupDraft(
                contactType: _contactType,
                outcome: _outcome,
                note: _noteCtrl.text.trim(),
                nextFollowupAt: _nextFollowupAt,
              ),
            );
          },
          child: const Text('حفظ المتابعة'),
        ),
      ],
    );
  }
}
