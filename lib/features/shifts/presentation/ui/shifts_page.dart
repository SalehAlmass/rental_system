import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rental_app/features/shifts/domain/entities/shift_closing.dart';
import 'package:rental_app/features/shifts/presentation/bloc/shifts_bloc.dart';

class ShiftsPage extends StatelessWidget {
  const ShiftsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => ShiftsRepository(context.read<ApiClient>()),
      child: BlocProvider(
        create: (ctx) => ShiftsBloc(ctx.read<ShiftsRepository>())..add(const ShiftsRequested()),
        child: const _ShiftsView(),
      ),
    );
  }
}

class _ShiftsView extends StatefulWidget {
  const _ShiftsView();

  @override
  State<_ShiftsView> createState() => _ShiftsViewState();
}

class _ShiftsViewState extends State<_ShiftsView> {
  String _period = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إغلاق الدوام والصندوق'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.point_of_sale_rounded),
        label: const Text('إغلاق دوام'),
        onPressed: () => _openCloseDialog(context),
      ),
      body: BlocConsumer<ShiftsBloc, ShiftsState>(
        listener: (context, state) {
          if (state.error != null && state.error!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!)),
            );
          }
        },
        builder: (context, state) {
          if (state.status == ShiftsStatus.loading && state.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = _applyPeriod(state.items);
          final summary = _ShiftSummary.from(items);

          return RefreshIndicator(
            onRefresh: () async {
              context.read<ShiftsBloc>().add(const ShiftsRequested());
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _HeaderCard(summary: summary),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PeriodChip(
                      label: 'الكل',
                      selected: _period == 'all',
                      onTap: () => setState(() => _period = 'all'),
                    ),
                    _PeriodChip(
                      label: 'اليوم',
                      selected: _period == 'today',
                      onTap: () => setState(() => _period = 'today'),
                    ),
                    _PeriodChip(
                      label: 'آخر 7 أيام',
                      selected: _period == 'week',
                      onTap: () => setState(() => _period = 'week'),
                    ),
                    _PeriodChip(
                      label: 'فروقات فقط',
                      selected: _period == 'issues',
                      onTap: () => setState(() => _period = 'issues'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  _EmptyState(onCloseShift: () => _openCloseDialog(context))
                else ...[
                  Text(
                    'سجل إغلاقات الدوام',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...items.map((s) => _ShiftCard(shift: s)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  List<ShiftClosing> _applyPeriod(List<ShiftClosing> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return items.where((item) {
      final date = DateTime.tryParse(item.shiftDate);
      switch (_period) {
        case 'today':
          return date != null && DateTime(date.year, date.month, date.day) == today;
        case 'week':
          return date != null && !date.isBefore(today.subtract(const Duration(days: 6)));
        case 'issues':
          return item.difference.abs() > 0.009;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _openCloseDialog(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<ShiftsBloc>(),
        child: const _CloseShiftDialog(),
      ),
    );
    if (ok == true && context.mounted) {
      context.read<ShiftsBloc>().add(const ShiftsRequested());
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.summary});
  final _ShiftSummary summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.surfaceContainerHighest],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'متابعة الصندوق اليومية',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'هذه الشاشة توثق المقبوض المتوقع، الفعلي داخل الصندوق، والفرق لكل موظف ولكل يوم.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryPill(label: 'عدد الإغلاقات', value: '${summary.count}'),
              _SummaryPill(label: 'المتوقع', value: summary.expected),
              _SummaryPill(label: 'الفعلي', value: summary.actual),
              _SummaryPill(label: 'إجمالي الفرق', value: summary.difference, highlight: summary.diffValue.abs() > 0.009),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCloseShift});
  final VoidCallback onCloseShift;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 42),
          const SizedBox(height: 12),
          Text(
            'لا توجد عمليات إغلاق دوام حتى الآن',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'ابدأ بإغلاق أول شفت لحفظ المقبوض الفعلي ومقارنته بقيمة المقبوض المتوقع داخل النظام.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onCloseShift,
            icon: const Icon(Icons.lock_clock_outlined),
            label: const Text('إغلاق دوام الآن'),
          ),
        ],
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.shift});
  final ShiftClosing shift;

  @override
  Widget build(BuildContext context) {
    final diff = shift.difference;
    final diffColor = diff == 0
        ? Theme.of(context).colorScheme.outline
        : (diff > 0 ? Colors.green : Colors.red);
    final currency = NumberFormat('#,##0.00');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shift.username?.isNotEmpty == true ? shift.username! : 'المستخدم #${shift.userId}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text('تاريخ الإغلاق: ${shift.shiftDate}'),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: diff == 0 ? Theme.of(context).colorScheme.secondaryContainer : diffColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  diff == 0 ? 'مطابق' : (diff > 0 ? 'زيادة' : 'عجز'),
                  style: TextStyle(fontWeight: FontWeight.w800, color: diff == 0 ? null : diffColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricBox(label: 'نقد النظام', value: currency.format(shift.cashTotal)),
              _MetricBox(label: 'تحويل النظام', value: currency.format(shift.transferTotal)),
              _MetricBox(label: 'المتوقع', value: currency.format(shift.expectedAmount)),
              _MetricBox(label: 'الفعلي بالصندوق', value: currency.format(shift.actualAmount)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded, size: 18),
              const SizedBox(width: 6),
              Text(
                'الفرق: ${currency.format(diff)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: diffColor,
                    ),
              ),
            ],
          ),
          if ((shift.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('ملاحظة: ${shift.notes}'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 135),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CloseShiftDialog extends StatefulWidget {
  const _CloseShiftDialog();

  @override
  State<_CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends State<_CloseShiftDialog> {
  final _drawer = TextEditingController();
  final _note = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  bool _submitting = false;
  bool _loadingSummary = true;
  double _systemCash = 0;
  double _systemTransfer = 0;

  double get _drawerValue => double.tryParse(_drawer.text.trim()) ?? 0;
  double get _expected => _systemCash + _systemTransfer;
  double get _difference => _drawerValue - _expected;

  @override
  void initState() {
    super.initState();
    _fetchTodaySummary();
  }

  Future<void> _fetchTodaySummary() async {
    setState(() => _loadingSummary = true);
    try {
      final api = context.read<ApiClient>();
      final dateStr = DateFormat('yyyy-MM-dd').format(_date);
      final res = await api.dio.get('shifts/today-summary?date=$dateStr');
      final data = res.data is Map ? (res.data['data'] ?? res.data) : {};
      if (mounted) {
        setState(() {
          _systemCash = (data['cash_total'] is num) ? (data['cash_total'] as num).toDouble() : 0;
          _systemTransfer = (data['transfer_total'] is num) ? (data['transfer_total'] as num).toDouble() : 0;
          _loadingSummary = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  @override
  void dispose() {
    _drawer.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0.00');
    final diff = _difference;
    return AlertDialog(
      title: const Text('إغلاق الدوام'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month),
                  title: Text(DateFormat('yyyy-MM-dd').format(_date)),
                  subtitle: const Text('تاريخ الإقفال'),
                  trailing: TextButton(
                    onPressed: () async {
                      await _pickDate();
                      _fetchTodaySummary();
                    },
                    child: const Text('تغيير'),
                  ),
                ),
                const SizedBox(height: 8),
                // ✅ حقول النظام - للقراءة فقط
                if (_loadingSummary)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lock_outlined, size: 16, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text('بيانات النظام (للقراءة فقط)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _calcRow('النقد حسب النظام', currency.format(_systemCash)),
                        const SizedBox(height: 6),
                        _calcRow('التحويلات حسب النظام', currency.format(_systemTransfer)),
                        const SizedBox(height: 6),
                        const Divider(),
                        _calcRow('الإجمالي المتوقع', currency.format(_expected),
                            valueStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                // ✅ الحقل الوحيد القابل للتعديل
                TextFormField(
                  controller: _drawer,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ الفعلي الموجود في الصندوق',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.point_of_sale_outlined),
                    helperText: 'أدخل المبلغ النقدي الفعلي الذي قمت بعده',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'مطلوب';
                    final n = double.tryParse(v);
                    if (n == null || n < 0) return 'قيمة غير صحيحة';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: diff == 0
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : (diff > 0 ? Colors.green.withOpacity(0.08) : Colors.red.withOpacity(0.08)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _calcRow('الفرق', currency.format(diff),
                      valueStyle: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: diff == 0 ? null : (diff > 0 ? Colors.green : Colors.red),
                      )),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة الإقفال أو سبب الفرق',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.save_outlined),
          label: const Text('حفظ الإغلاق'),
          onPressed: _submitting || _loadingSummary ? null : _submit,
        ),
      ],
    );
  }

  Widget _calcRow(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: valueStyle ?? const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    context.read<ShiftsBloc>().add(
          ShiftClosed(
            shiftDate: DateFormat('yyyy-MM-dd').format(_date),
            cashTotal: _systemCash,
            transferTotal: _systemTransfer,
            cashInDrawer: _drawerValue,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          ),
        );
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) Navigator.pop(context, true);
    });
  }
}

class _ShiftSummary {
  const _ShiftSummary({
    required this.count,
    required this.expected,
    required this.actual,
    required this.difference,
    required this.diffValue,
  });

  final int count;
  final String expected;
  final String actual;
  final String difference;
  final double diffValue;

  factory _ShiftSummary.from(List<ShiftClosing> items) {
    final formatter = NumberFormat('#,##0.00');
    final expectedValue = items.fold<double>(0, (sum, item) => sum + item.expectedAmount);
    final actualValue = items.fold<double>(0, (sum, item) => sum + item.actualAmount);
    final diffValue = items.fold<double>(0, (sum, item) => sum + item.difference);
    return _ShiftSummary(
      count: items.length,
      expected: formatter.format(expectedValue),
      actual: formatter.format(actualValue),
      difference: formatter.format(diffValue),
      diffValue: diffValue,
    );
  }
}
