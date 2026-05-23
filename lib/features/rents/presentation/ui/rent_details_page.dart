import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:rental_app/features/rents/presentation/bloc/rents_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/failure.dart';
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

  final Map<String, String> _sectionErrors = {};

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
    if (mounted) setState(() => _loading = true);
    _sectionErrors.clear();

    try {
      await _runSection('financials', _fetchFinancials, fatal: true);

      await Future.wait([
        _runSection('payments', _fetchRentPayments),
        _runSection('outstanding', _fetchClientOutstandingRents),
        _runSection('followups', _fetchCollectionFollowups),
        _runSection('client_followups', _fetchClientFollowups),
      ]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runSection(
    String key,
    Future<void> Function() task, {
    bool fatal = false,
  }) async {
    try {
      await task();
      if (!mounted) return;
      setState(() => _sectionErrors.remove(key));
    } catch (e) {
      if (!mounted) return;
      final msg = _friendlyError(e);
      setState(() => _sectionErrors[key] = msg);
      if (fatal) _snack(msg);
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('Unexpected token') ||
        text.contains('FormatException') ||
        text.contains('is not valid JSON')) {
      return 'السيرفر أعاد استجابة غير صالحة بدل JSON. راجع ملف API أو سجل أخطاء PHP.';
    }
    if (text.contains('404')) return 'المسار المطلوب غير موجود في API.';
    return text.replaceFirst('Exception: ', '');
  }

  dynamic _unwrapResponseData(dynamic raw) {
    if (raw is String) {
      final s = raw.trimLeft();
      if (s.startsWith('<')) {
        throw ApiFailure('API returned HTML instead of JSON: $s');
      }
      throw ApiFailure('API returned plain text instead of JSON: $s');
    }

    if (raw is Map) {
      return raw['data'] ?? raw['items'] ?? raw['rent'] ?? raw['followups'] ?? raw;
    }

    return raw;
  }

  double _numToDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  Future<void> _fetchFinancials() async {
    try {
      final res = await _api.dio.get('rents/${widget.rentId}/financials');
      final raw = _unwrapResponseData(res.data);

      if (raw is! Map) throw ApiFailure('financials payload is invalid');

      final rentJson =
          (raw['rent'] is Map) ? (raw['rent'] as Map).cast<String, dynamic>() : null;

      if (rentJson == null) {
        throw ApiFailure('financials: rent is missing');
      }

      final rent = Rent.fromJson(rentJson);
      final total = _numToDouble(raw['total_amount']);
      final paid = _numToDouble(raw['paid_amount']);
      final remaining = _numToDouble(raw['remaining_amount'] ?? raw['remaining']);
      final isPaidServer =
          (raw['is_paid'] == true) || (raw['is_fully_paid'] == true);

      final status = (rent.status ?? '').toLowerCase();
      final fullyPaidSafe = status == 'open' ? false : isPaidServer;

      if (!mounted) return;
      setState(() {
        _rent = rent;
        _total = total;
        _paid = paid;
        _remaining = remaining < 0 ? 0 : remaining;
        _fullyPaid = fullyPaidSafe;
      });
    } catch (_) {
      final rent = await _rentsRepo.get(widget.rentId);
      if (!mounted) return;

      setState(() {
        _rent = rent;
        _total = rent.totalAmount ?? 0;
        _paid = rent.paidAmount ?? rent.closingPaidAmount ?? 0;
        _remaining = _remainingFor(rent);
        _fullyPaid = (rent.status ?? '').toLowerCase() == 'open'
            ? false
            : (rent.isPaid ?? false);
      });
    }
  }

  Future<void> _fetchRentPayments() async {
    final items = await _paymentsRepo.list(
      rentId: widget.rentId,
      showVoided: true,
    );
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
      return remaining > 0.009 &&
          (item.status ?? '').toLowerCase() != 'cancelled';
    }).toList();

    if (!mounted) return;
    setState(() => _clientOutstandingRents = outstanding);
  }

  Future<void> _fetchCollectionFollowups() async {
    final res = await _api.dio.get('rents/${widget.rentId}/collection-followups');
    dynamic raw = _unwrapResponseData(res.data);
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
    dynamic raw = _unwrapResponseData(res.data);
    if (raw is! List) raw = [];

    final items = raw
        .whereType<Map>()
        .map((e) => CollectionFollowup.fromJson(e.cast<String, dynamic>()))
        .toList();

    if (!mounted) return;
    setState(() => _clientFollowups = items);
  }

  Future<void> _createCollectionFollowup(
    _CollectionFollowupDraft draft, {
    bool allowDuplicateToday = false,
  }) async {
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
      final msg = data is Map && data['error'] != null
          ? data['error'].toString()
          : e.message ?? e.toString();
      _snack('فشل حفظ متابعة التحصيل: $msg');
    } catch (e) {
      if (!mounted) return;
      _snack('فشل حفظ متابعة التحصيل: ${_friendlyError(e)}');
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
              const Text(
                'حتى لا يتكرر التواصل مع نفس العميل في نفس اليوم، راجع المتابعة السابقة أولاً.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context, false);
                _showFollowupsSheet(context);
              },
              child: const Text('عرض السجل'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إضافة متابعة إضافية'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    final draft = await showDialog<_CollectionFollowupDraft>(
      context: context,
      builder: (_) => _CollectionFollowupDialog(
        initialHint: todays == null
            ? null
            : 'تم التواصل اليوم بواسطة ${_followupActor(todays)} • ${todays.contactTypeLabel} • ${todays.outcomeLabel}',
        clientName: _rent?.clientName,
        clientPhone: null, // سيتم جلبه من API لاحقاً إن وُجد
        rentNo: _rent?.id,
      ),
    );

    if (draft == null) return;
    await _createCollectionFollowup(
      draft,
      allowDuplicateToday: todays != null,
    );
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
          totalAmount: _effectiveTotal,
          remainingAmount: _effectiveRemaining,
        ),
      );

      if (result == null) return;

      setState(() => _closing = true);

      await _rentsRepo.closeRent(
        rentId: rent.id,
        endDatetime: DateTime.now().toIso8601String(),
        applySpecialPricing: result.applySpecialPricing,
        paidAmount: result.paidAmount,
        discountAmount: result.discountAmount,
        discountNote: result.discountNote,
        paymentMethod: result.paymentMethod,
        createReceipt: result.createReceipt,
        paymentNotes: result.paymentNotes,
        idempotencyKey:
            'rent_close_${rent.id}_${DateTime.now().millisecondsSinceEpoch}',
      );

      await _load();
      if (!mounted) return;
      _snack('تم إغلاق العقد بنجاح');
    } catch (e) {
      if (!mounted) return;
      _snack('فشل إغلاق العقد: ${_friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Future<void> _showPayDialog({required Rent rent}) async {
    if (!mounted) return;

    await _runSection('financials', _fetchFinancials);

    final status = (rent.status ?? '').toLowerCase();
    final isOpen = status == 'open';

    if (!isOpen && _remaining <= 0.0001) {
      _snack('هذا العقد مسدد بالكامل ولا يمكن إنشاء سند جديد');
      return;
    }

    final maxPayable = _remaining > 0 ? _remaining : _effectiveRemaining;
    final initialAmount = maxPayable > 0 ? maxPayable : _effectiveTotal;

    await showDialog(
      context: context,
      builder: (_) => _PayNowDialog(
        total: _effectiveTotal,
        alreadyPaid: _paid,
        maxPayable: maxPayable <= 0 ? 0 : maxPayable,
        unlimitedWhenOpen: isOpen && (_effectiveTotal <= 0.0001),
        initialAmount: initialAmount,
        onPay: (amount, method, notes) async {
          final idemKey =
              'rent_${rent.id}_${DateTime.now().microsecondsSinceEpoch}';
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

    await _runSection('financials', _fetchFinancials);
    await _runSection('payments', _fetchRentPayments);
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
      final ad = DateTime.tryParse(
            (a.createdAt ?? '').replaceFirst(' ', 'T'),
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse(
            (b.createdAt ?? '').replaceFirst(' ', 'T'),
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    return valid.first;
  }

  CollectionFollowup? get _latestFollowup =>
      _followups.isEmpty ? null : _followups.first;

  CollectionFollowup? get _latestClientFollowup =>
      _clientFollowups.isEmpty ? null : _clientFollowups.first;

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

  double get _liveOpenTotal {
    final rent = _rent;
    if (rent == null) return 0;

    final savedTotal = _total > 0 ? _total : (rent.totalAmount ?? 0);
    if (savedTotal > 0) return savedTotal;

    final status = (rent.status ?? '').toLowerCase();
    if (status != 'open') return 0;

    final dailyRate = rent.rate ?? 0;
    if (dailyRate <= 0) return 0;

    final start = _tryParse(rent.startDatetime);
    if (start == null) return 0;

    final minutes = DateTime.now().difference(start).inMinutes;
    if (minutes <= 0) return 0;

    final hours = minutes / 60.0;

    double total;
    if (hours < 3) {
      total = dailyRate * (2 / 3);
    } else {
      final billableDays = (hours / 24.0).ceil();
      total = dailyRate * (billableDays < 1 ? 1 : billableDays);
    }

    return total.round().toDouble();
  }

  double get _effectiveTotal => _liveOpenTotal;

  double get _effectiveRemaining {
    final status = (_rent?.status ?? '').toLowerCase();
    final total = _effectiveTotal;

    if (status == 'open' && total > 0) {
      final remaining = total - _paid;
      return remaining > 0 ? remaining : 0;
    }

    return _remaining > 0 ? _remaining : 0;
  }

  bool get _hasDeferredPayment => _effectiveRemaining > 0.009;

  bool get _isCollectionDelayed {
    if (!_hasDeferredPayment) return false;

    final status = (_rent?.status ?? '').toLowerCase();
    if (status != 'closed') return false;

    final closedAt =
        DateTime.tryParse((_rent?.closedAt ?? '').replaceFirst(' ', 'T'));
    if (closedAt == null) return false;

    return DateTime.now().difference(closedAt).inDays >= 3;
  }

  @override
  Widget build(BuildContext context) {
    final rent = _rent;
    final status = (rent?.status ?? '').toLowerCase();
    final isOpen = status == 'open';

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل العقد'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : rent == null
              ? Center(
                  child: Text(
                    _sectionErrors['financials'] ?? 'تعذر تحميل العقد',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (!isOpen && rent.closedAt != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'تم إغلاق العقد بتاريخ: ${_fmtDateTime(rent.closedAt!)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      _card(
                        title: 'معلومات العقد',
                        child: Column(
                          children: [
                            _kv('رقم العقد', '#${rent.id}'),
                            _kv('العميل', rent.clientName ?? rent.clientId.toString()),
                            _kv('الحالة', _statusText(rent.status)),
                            _kv('بداية', _fmtDateTime(rent.startDatetime)),
                            _kv(
                              'نهاية',
                              rent.endDatetime == null
                                  ? '-'
                                  : _fmtDateTime(rent.endDatetime!),
                            ),
                            const Divider(height: 18),
                            _kv(
                              'الإجمالي بعد الخصم',
                              isOpen && _effectiveTotal <= 0.0001
                                  ? 'غير نهائي (العقد جاري)'
                                  : '${_effectiveTotal.round()} ر.ي',
                            ),
                            if ((rent.discountAmount ?? 0) > 0) ...[
                              _kv('الخصم', '${(rent.discountAmount ?? 0).round()} ر.ي'),
                              if ((rent.discountNote ?? '').trim().isNotEmpty)
                                _kv('سبب الخصم', rent.discountNote!.trim()),
                            ],
                            _kv('المدفوع', '${_paid.round()} ر.ي'),
                            _kv(
                              'المتبقي',
                              isOpen && _effectiveTotal <= 0.0001
                                  ? '-'
                                  : '${_effectiveRemaining.round()} ر.ي',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _card(
                        title: 'المعدات المستأجرة',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (rent.items.isEmpty)
                              const Text('لا توجد معدات مسجلة (بيانات قديمة)'),
                            ...rent.items.map((it) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _kv('المعدة', '${it.equipmentName ?? it.equipmentId}${it.serialNo != null && it.serialNo!.isNotEmpty ? ' (S/N: ${it.serialNo})' : ''}${it.internalCode != null && it.internalCode!.isNotEmpty ? ' (Code: ${it.internalCode})' : ''}'),
                                  if (it.rate != null && it.rate! > 0)
                                    _kv('السعر اليومي', '${it.rate!.round()} ر.ي'),
                                  if (it.notes != null && it.notes!.trim().isNotEmpty)
                                    _kv('ملاحظات', it.notes!),
                                  _kv('الحالة', _statusText(it.status)),
                                  if (it.startDatetime != null)
                                    _kv('بداية', _fmtDateTime(it.startDatetime!)),
                                  if (it.endDatetime != null)
                                    _kv('نهاية', _fmtDateTime(it.endDatetime!)),
                                  if (isOpen && it.status == 'open')
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.swap_horiz, size: 16),
                                        label: const Text('استبدال'),
                                        onPressed: () => _replaceEquipment(context, it),
                                      ),
                                    ),
                                  const Divider(),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _card(
                        title: 'معلومات الإغلاق',
                        child: Column(
                          children: [
                            _kv(
                              'وقت الإغلاق',
                              rent.closedAt == null ? '-' : _fmtDateTime(rent.closedAt!),
                            ),
                            _kv('رقم المستخدم', rent.closedByUserId?.toString() ?? '-'),
                            _kv(
                              'المبلغ عند الإغلاق',
                              '${(rent.closingPaidAmount ?? 0).toStringAsFixed(2)} ر.ي',
                            ),
                            _kv(
                              'طريقة الدفع',
                              _paymentMethodText(rent.closingPaymentMethod),
                            ),
                            _kv(
                              'حالة السند',
                              _receiptStatusText(rent.closingPaymentStatus),
                            ),
                            _kv('رقم السند', rent.closingPaymentId?.toString() ?? '-'),
                            _kv(
                              'طريقة الاحتساب',
                              rent.pricingRuleLabel ?? 'الاحتساب القياسي',
                            ),
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
                            _buildLastPaymentCard(),
                            const SizedBox(height: 12),
                            _buildFollowupCard(),
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
                                  label: Text(
                                    _rentPayments.isEmpty
                                        ? 'لا توجد سندات'
                                        : 'عرض السندات (${_rentPayments.length})',
                                  ),
                                ),
                                if (isOpen)
                                  FilledButton.tonalIcon(
                                    onPressed: _closing ? null : _closeContract,
                                    icon: Icon(
                                      _closing
                                          ? Icons.hourglass_top
                                          : Icons.lock_outline,
                                    ),
                                    label: Text(
                                      _closing ? 'جاري الإغلاق...' : 'إغلاق العقد',
                                    ),
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
    final msg = _isCollectionDelayed
        ? 'تأخر في السداد لهذا العقد'
        : 'يوجد مبلغ متبقٍ على العميل';

    final bg = _isCollectionDelayed
        ? Colors.red.withOpacity(0.08)
        : Colors.amber.withOpacity(0.10);

    final bd = _isCollectionDelayed
        ? Colors.red.withOpacity(0.25)
        : Colors.amber.withOpacity(0.30);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bd),
      ),
      child: Row(
        children: [
          Icon(
            _isCollectionDelayed
                ? Icons.warning_amber_rounded
                : Icons.info_outline,
            color: _isCollectionDelayed ? Colors.red : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(fontWeight: FontWeight.w700),
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
        color: const Color(0xFFEFF5F3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _miniMetric(
              'إجمالي العقد',
              isOpen && _effectiveTotal <= 0.0001
                  ? 'جاري'
                  : '${_effectiveTotal.toStringAsFixed(2)} ر.ي',
            ),
          ),
          Expanded(
            child: _miniMetric(
              'المدفوع',
              '${_paid.toStringAsFixed(2)} ر.ي',
            ),
          ),
          Expanded(
            child: _miniMetric(
              'المتبقي',
              isOpen && _effectiveTotal <= 0.0001
                  ? '-'
                  : '${_effectiveRemaining.toStringAsFixed(2)} ر.ي',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastPaymentCard() {
    final payment = _lastPayment;
    if (payment == null) {
      return _emptyInfo('لا توجد دفعات مسجلة لهذا العقد حتى الآن.');
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'آخر دفعة',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _kv('التاريخ', _fmtDateTime(payment.createdAt)),
          _kv('المبلغ', '${payment.amount.toStringAsFixed(2)} ر.ي'),
          _kv('رقم السند', payment.id.toString()),
          _kv('طريقة الدفع', _paymentMethodText(payment.method)),
        ],
      ),
    );
  }

  Widget _buildFollowupCard() {
    final latest = _latestClientFollowup ?? _latestFollowup;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'آخر تواصل',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: _savingFollowup ? null : _openCollectionFollowupDialog,
                icon: const Icon(Icons.add_ic_call_outlined),
                label: const Text('إضافة متابعة'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (latest == null)
            _emptyInfo('لا توجد متابعة تحصيل مسجلة لهذا العقد أو العميل.')
          else ...[
            _kv('النوع', latest.contactTypeLabel),
            _kv('النتيجة', latest.outcomeLabel),
            _kv('الموظف', _followupActor(latest)),
            _kv('التاريخ', _fmtDateTime(latest.createdAt)),
            _kv('الموعد القادم', _fmtDateTime(latest.nextFollowupAt)),
            if ((latest.note ?? '').trim().isNotEmpty)
              _kv('الملاحظة', latest.note!.trim()),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: (_followups.isEmpty && _clientFollowups.isEmpty)
                  ? null
                  : () => _showFollowupsSheet(context),
              icon: const Icon(Icons.history),
              label: Text(
                'عرض كل المتابعات (${_followups.length + _clientFollowups.length})',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherOutstandingBanner() {
    final total = _clientOutstandingRents.fold<double>(
      0,
      (sum, r) => sum + _remainingFor(r),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'هذا العميل لديه عقود أخرى غير مسددة',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text('عدد العقود: ${_clientOutstandingRents.length}'),
          Text('إجمالي المتبقي: ${total.toStringAsFixed(2)} ر.ي'),
        ],
      ),
    );
  }

  void _showPaymentsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'السندات المرتبطة بالعقد',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final p in _rentPayments)
              Card(
                child: ListTile(
                  leading: Icon(
                    p.type == 'out'
                        ? Icons.call_made
                        : Icons.call_received,
                    color: p.type == 'out' ? Colors.red : Colors.green,
                  ),
                  title: Text('${p.amount.toStringAsFixed(2)} ر.ي'),
                  subtitle: Text(
                    '${_paymentMethodText(p.method)} • ${_fmtDateTime(p.createdAt)}',
                  ),
                  trailing: p.isVoid ? const Chip(label: Text('ملغي')) : null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentDetailsPage(
                        payment: p,
                        paymentId: p.id,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFollowupsSheet(BuildContext context) {
    final merged = [..._clientFollowups];
    merged.sort(
      (a, b) => (_tryParse(b.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(
        _tryParse(a.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'سجل متابعات التحصيل',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final f in merged)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.phone_in_talk_outlined),
                  title: Text('${f.contactTypeLabel} • ${f.outcomeLabel}'),
                  subtitle: Text(
                    '${_fmtDateTime(f.createdAt)} ${(f.note ?? '').trim().isEmpty ? '-' : f.note!.trim()}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.black.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
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
          Expanded(
            child: Text(
              k,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _emptyInfo(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
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

  String _paymentMethodText(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'cash':
        return 'نقد';
      case 'transfer':
        return 'تحويل';
      case 'card':
        return 'بطاقة';
      default:
        return (s == null || s.isEmpty) ? '-' : s;
    }
  }

  String _receiptStatusText(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'created':
        return 'تم إنشاء السند';
      case 'not_created':
        return 'لم يُنشأ';
      default:
        return (s == null || s.isEmpty) ? '-' : s;
    }
  }

  String _fmtDateTime(String? s) {
    final dt = _tryParse(s);
    if (dt == null) return '-';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _replaceEquipment(BuildContext context, RentItem item) async {
    final equipmentRepo = context.read<EquipmentRepository>();
    final available = (await equipmentRepo.list()).where((e) => e.status != 'rented').toList();

    if (!mounted) return;
    if (available.isEmpty) {
      _snack('لا توجد معدات متاحة للاستبدال', isError: true);
      return;
    }

    int? selectedId = available.first.id;
    final notesCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('استبدال معدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('المعدة الحالية: ${item.equipmentName ?? item.equipmentId}'),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedId,
                items: available.map((e) => DropdownMenuItem(value: e.id, child: Text('${e.name} - ${e.serialNo ?? "-"}'))).toList(),
                onChanged: (v) => setDialogState(() => selectedId = v),
                decoration: const InputDecoration(labelText: 'المعدة الجديدة', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('استبدال'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedId != null) {
      context.read<RentsBloc>().add(
        RentEquipmentReplaced(
          rentId: widget.rentId,
          oldEquipmentId: item.equipmentId,
          newEquipmentId: selectedId!,
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        )
      );
      _snack('جاري استبدال المعدة...');
    }
  }
}

class _CollectionFollowupDraft {
  _CollectionFollowupDraft({
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

class _CollectionFollowupDialog extends StatefulWidget {
  const _CollectionFollowupDialog({this.initialHint, this.clientName, this.clientPhone, this.rentNo});
  final String? initialHint;
  final String? clientName;
  final String? clientPhone;
  final int? rentNo;

  @override
  State<_CollectionFollowupDialog> createState() =>
      _CollectionFollowupDialogState();
}

class _CollectionFollowupDialogState extends State<_CollectionFollowupDialog> {
  String _contactType = 'call';
  String _outcome = 'follow_up_later';
  final _noteCtrl = TextEditingController();
  DateTime? _nextFollowupAt;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _applySmartSchedule(String outcome) {
    final now = DateTime.now();
    switch (outcome) {
      case 'promise_to_pay':
        _nextFollowupAt = now.add(const Duration(days: 1));
        break;
      case 'customer_requested_delay':
        _nextFollowupAt = now.add(const Duration(days: 2));
        break;
      case 'follow_up_later':
        _nextFollowupAt = now.add(const Duration(days: 1));
        break;
      case 'no_answer':
        _nextFollowupAt = now.add(const Duration(hours: 6));
        break;
      case 'paid':
        _nextFollowupAt = null;
        break;
      default:
        break;
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;

    setState(() {
      _nextFollowupAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return 'لا يوجد';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة متابعة'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // بيانات العميل والعقد
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.clientName != null)
                      Row(children: [
                        const Icon(Icons.person, size: 16, color: Colors.blue),
                        const SizedBox(width: 6),
                        Expanded(child: Text('العميل: ${widget.clientName}', style: const TextStyle(fontWeight: FontWeight.bold))),
                      ]),
                    if (widget.clientPhone != null && widget.clientPhone!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.phone, size: 16, color: Colors.green),
                        const SizedBox(width: 6),
                        Text('الهاتف: ${widget.clientPhone}'),
                      ]),
                    ],
                    if (widget.rentNo != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.receipt_long, size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text('رقم العقد: #${widget.rentNo}'),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if ((widget.initialHint ?? '').trim().isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.25)),
                  ),
                  child: Text(widget.initialHint!),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                initialValue: _contactType,
                decoration: const InputDecoration(
                  labelText: 'نوع المتابعة',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'call', child: Text('اتصال')),
                  DropdownMenuItem(value: 'whatsapp', child: Text('واتساب')),
                  DropdownMenuItem(value: 'visit', child: Text('زيارة')),
                  DropdownMenuItem(value: 'verbal', child: Text('شفهي')),
                  DropdownMenuItem(value: 'no_answer', child: Text('لم يتم الرد')),
                ],
                onChanged: (v) => setState(() => _contactType = v ?? 'call'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _outcome,
                decoration: const InputDecoration(
                  labelText: 'النتيجة',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'promise_to_pay', child: Text('وعد بالسداد')),
                  DropdownMenuItem(value: 'follow_up_later', child: Text('متابعة لاحقة')),
                  DropdownMenuItem(value: 'paid', child: Text('تم التحصيل')),
                  DropdownMenuItem(
                    value: 'customer_requested_delay',
                    child: Text('تأجيل بطلب العميل'),
                  ),
                  DropdownMenuItem(value: 'no_answer', child: Text('لا يرد')),
                  DropdownMenuItem(value: 'other', child: Text('أخرى')),
                ],
                onChanged: (v) {
                  final value = v ?? 'follow_up_later';
                  setState(() {
                    _outcome = value;
                    _applySmartSchedule(value);
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'الملاحظة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('الموعد القادم'),
                subtitle: Text(_fmt(_nextFollowupAt)),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      onPressed: _pickDateTime,
                      icon: const Icon(Icons.event),
                    ),
                    if (_nextFollowupAt != null)
                      IconButton(
                        onPressed: () => setState(() => _nextFollowupAt = null),
                        icon: const Icon(Icons.clear),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            if (_noteCtrl.text.trim().isEmpty && _outcome.trim().isEmpty) return;
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
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _CloseContractResult {
  _CloseContractResult({
    required this.applySpecialPricing,
    required this.paidAmount,
    required this.paymentMethod,
    required this.createReceipt,
    this.paymentNotes,
    this.discountAmount = 0,
    this.discountNote,
  });

  final bool applySpecialPricing;
  final double paidAmount;
  final String paymentMethod;
  final bool createReceipt;
  final String? paymentNotes;
  final double discountAmount;
  final String? discountNote;
}

class _CloseContractDialog extends StatefulWidget {
  const _CloseContractDialog({
    required this.rent,
    required this.settings,
    required this.currentPaid,
    required this.totalAmount,
    required this.remainingAmount,
  });

  final Rent rent;
  final dynamic settings;
  final double currentPaid;
  final double totalAmount;
  final double remainingAmount;

  @override
  State<_CloseContractDialog> createState() => _CloseContractDialogState();
}

class _CloseContractDialogState extends State<_CloseContractDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _paidCtrl;
  late final TextEditingController _discountCtrl;
  final _discountNoteCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _applySpecialPricing = false;
  bool _createReceipt = true;
  String _paymentMethod = 'cash';

  bool get _allowSpecialPricing {
    final s = widget.settings;
    if (s is Map<String, dynamic>) {
      final mode =
          (s['hour_pricing_mode'] ?? s['special_pricing_mode'] ?? '')
              .toString()
              .toLowerCase();
      return mode == 'auto' || mode == 'prompt' || mode == 'optional';
    }
    return true;
  }

  bool get _allowReceiptToggle {
    final s = widget.settings;
    if (s is Map<String, dynamic>) {
      final mode = (s['receipt_mode'] ?? s['closing_receipt_mode'] ?? '')
          .toString()
          .toLowerCase();
      return mode != 'forced_auto';
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _discountCtrl = TextEditingController(text: '0');
    _paidCtrl = TextEditingController(
      text: _requiredNow().toStringAsFixed(2),
    );
    _discountCtrl.addListener(_applyDiscountToPaidAmount);
  }

  double _discountValue() {
    final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    return discount.clamp(0, widget.totalAmount).toDouble();
  }

  double _requiredNow() {
    final netTotal = (widget.totalAmount - _discountValue()).clamp(0, widget.totalAmount).toDouble();
    final remaining = netTotal - widget.currentPaid;
    return remaining > 0 ? remaining : 0;
  }

  void _applyDiscountToPaidAmount() {
    _paidCtrl.text = _requiredNow().toStringAsFixed(2);
  }

  @override
  void dispose() {
    _discountCtrl.removeListener(_applyDiscountToPaidAmount);
    _paidCtrl.dispose();
    _discountCtrl.dispose();
    _discountNoteCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إغلاق العقد'),
      content: SizedBox(
        width: 430,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إجمالي العقد: ${widget.totalAmount.toStringAsFixed(2)} ر.ي'),
                      Text('المدفوع سابقًا: ${widget.currentPaid.toStringAsFixed(2)} ر.ي'),
                      Text('المتبقي الحالي: ${widget.remainingAmount.toStringAsFixed(2)} ر.ي'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(onPressed: () => _paidCtrl.text = _requiredNow().toStringAsFixed(2), child: const Text('كامل المتبقي')),
                    OutlinedButton(onPressed: () => _paidCtrl.text = (_requiredNow() / 2).toStringAsFixed(2), child: const Text('نصف المتبقي')),
                    OutlinedButton(onPressed: () => _paidCtrl.text = (_requiredNow() * (2 / 3)).toStringAsFixed(2), child: const Text('ثلثين المتبقي')),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _discountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'الخصم من إجمالي العقد',
                    helperText: 'يُخصم من إجمالي المبلغ قبل احتساب المتبقي',
                    border: OutlineInputBorder(),
                    prefixText: 'ر.ي ',
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n < 0) return 'أدخل خصمًا صحيحًا';
                    if (n > widget.totalAmount) return 'الخصم لا يمكن أن يتجاوز الإجمالي';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _discountNoteCtrl,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'سبب الخصم',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0;
                    if (discount > 0 && (v ?? '').trim().isEmpty) {
                      return 'اكتب سبب الخصم';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _paidCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المدفوع الآن',
                    helperText: 'تم تعبئته تلقائيًا بالمتبقي بعد الخصم ويمكنك تعديله',
                    border: OutlineInputBorder(),
                    prefixText: 'ر.ي ',
                  ),
                  readOnly: _paymentMethod == 'deferred',
                  validator: (v) {
                    if (_paymentMethod == 'deferred') return null;
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n < 0) return 'أدخل مبلغًا صحيحًا';
                    final required = _requiredNow();
                    if (required > 0 && n - required > 0.009) {
                      return 'المبلغ أكبر من المطلوب: ${required.toStringAsFixed(2)} ر.ي';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'طريقة الدفع',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('نقد')),
                    DropdownMenuItem(value: 'transfer', child: Text('تحويل')),
                    DropdownMenuItem(value: 'deferred', child: Text('آجل')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _paymentMethod = v ?? 'cash';
                      if (_paymentMethod == 'deferred') {
                        _paidCtrl.text = '0';
                      } else {
                        _paidCtrl.text = _requiredNow().toStringAsFixed(2);
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (_allowReceiptToggle)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _createReceipt,
                    onChanged: (v) => setState(() => _createReceipt = v),
                    title: const Text('إنشاء سند قبض تلقائي'),
                  ),
                TextFormField(
                  controller: _notesCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة الإغلاق / السند',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _CloseContractResult(
                applySpecialPricing: _applySpecialPricing,
                paidAmount: double.tryParse(_paidCtrl.text.trim()) ?? 0,
                paymentMethod: _paymentMethod,
                createReceipt: _createReceipt,
                paymentNotes: _notesCtrl.text.trim().isEmpty
                    ? null
                    : _notesCtrl.text.trim(),
                discountAmount: double.tryParse(_discountCtrl.text.trim()) ?? 0,
                discountNote: _discountNoteCtrl.text.trim().isEmpty
                    ? null
                    : _discountNoteCtrl.text.trim(),
              ),
            );
          },
          child: const Text('إغلاق العقد'),
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
    required this.unlimitedWhenOpen,
    required this.initialAmount,
    required this.onPay,
  });

  final double total;
  final double alreadyPaid;
  final double maxPayable;
  final bool unlimitedWhenOpen;
  final double initialAmount;
  final Future<void> Function(double, String, String?) onPay;

  @override
  State<_PayNowDialog> createState() => _PayNowDialogState();
}

class _PayNowDialogState extends State<_PayNowDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  final _noteCtrl = TextEditingController();
  String _method = 'cash';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.initialAmount > 0
          ? widget.initialAmount.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double _paymentLimit() {
    if (widget.maxPayable > 0) return widget.maxPayable;
    if (widget.total > 0) return widget.total;
    return 0;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) return;

    setState(() => _saving = true);
    try {
      await widget.onPay(
        amount,
        _method,
        _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remainingText = widget.unlimitedWhenOpen
        ? 'العقد مفتوح والإجمالي غير نهائي بعد'
        : 'المتبقي الحالي: ${widget.maxPayable.toStringAsFixed(2)} ر.ي';

    return AlertDialog(
      title: const Text('إضافة دفعة'),
      content: SizedBox(
        width: 430,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إجمالي العقد: ${widget.total.toStringAsFixed(2)} ر.ي'),
                      Text('المدفوع سابقًا: ${widget.alreadyPaid.toStringAsFixed(2)} ر.ي'),
                      Text(remainingText),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(onPressed: () => setState(() => _amountCtrl.text = _paymentLimit().toStringAsFixed(2)), child: const Text('كامل المتبقي')),
                    OutlinedButton(onPressed: () => setState(() => _amountCtrl.text = (_paymentLimit() / 2).toStringAsFixed(2)), child: const Text('نصف المتبقي')),
                    OutlinedButton(onPressed: () => setState(() => _amountCtrl.text = (_paymentLimit() * (2 / 3)).toStringAsFixed(2)), child: const Text('ثلثين المتبقي')),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'مبلغ الدفعة',
                    helperText: 'تم تعبئته تلقائيًا بالمتبقي ويمكنك تعديله',
                    border: OutlineInputBorder(),
                    prefixText: 'ر.ي ',
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'أدخل مبلغًا صحيحًا';
                    final limit = _paymentLimit();
                    if (limit > 0 && n - limit > 0.009) {
                      return 'المبلغ أكبر من المطلوب: ${limit.toStringAsFixed(2)} ر.ي';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _method,
                  decoration: const InputDecoration(
                    labelText: 'طريقة الدفع',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('نقد')),
                    DropdownMenuItem(value: 'transfer', child: Text('تحويل')),
                    DropdownMenuItem(value: 'card', child: Text('بطاقة')),
                  ],
                  onChanged: (v) => setState(() => _method = v ?? 'cash'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'جاري الحفظ...' : 'حفظ الدفعة'),
        ),
      ],
    );
  }
}