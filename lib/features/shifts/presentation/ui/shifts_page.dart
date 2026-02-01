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

class _ShiftsView extends StatelessWidget {
  const _ShiftsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إغلاق الدوام'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.lock_clock),
        label: const Text('إغلاق دوام'),
        onPressed: () => _openCloseDialog(context),
      ),
      body: BlocConsumer<ShiftsBloc, ShiftsState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!)));
          }
        },
        builder: (context, state) {
          if (state.status == ShiftsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = state.items;
          if (items.isEmpty) {
            return const Center(child: Text('لا توجد إغلاقات دوام'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final s = items[i];
              return _ShiftCard(shift: s);
            },
          );
        },
      ),
    );
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

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.shift});
  final ShiftClosing shift;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'التاريخ: ${shift.shiftDate}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (shift.username != null)
                  Text(
                    shift.username!,
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _kv('المتوقع', shift.expectedAmount),
                _kv('الفعلي', shift.actualAmount),
                _kv('الفرق', shift.difference, isDiff: true),
              ],
            ),
            if ((shift.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('ملاحظة: ${shift.notes}', maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, double v, {bool isDiff = false}) {
    final s = v.toStringAsFixed(2);
    return Text(
      '$k: $s',
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: isDiff
            ? (v == 0 ? null : (v > 0 ? Colors.green : Colors.red))
            : null,
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
  final _cash = TextEditingController();
  final _transfer = TextEditingController();
  final _drawer = TextEditingController();
  final _note = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  bool _submitting = false;

  @override
  void dispose() {
    _cash.dispose();
    _transfer.dispose();
    _drawer.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إغلاق الدوام'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month),
                title: Text(DateFormat('yyyy-MM-dd').format(_date)),
                trailing: TextButton(
                  onPressed: _pickDate,
                  child: const Text('تغيير'),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cash,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'إجمالي النقد', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'مطلوب';
                  final n = double.tryParse(v);
                  if (n == null || n < 0) return 'قيمة غير صحيحة';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _transfer,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'إجمالي التحويل', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'مطلوب';
                  final n = double.tryParse(v);
                  if (n == null || n < 0) return 'قيمة غير صحيحة';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _drawer,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المبلغ الفعلي في الصندوق', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'مطلوب';
                  final n = double.tryParse(v);
                  if (n == null) return 'قيمة غير صحيحة';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('حفظ'),
          onPressed: _submitting ? null : _submit,
        ),
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
    final cash = double.tryParse(_cash.text.trim()) ?? 0;
    final transfer = double.tryParse(_transfer.text.trim()) ?? 0;
    final drawer = double.tryParse(_drawer.text.trim()) ?? 0;
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);

    context.read<ShiftsBloc>().add(
          ShiftClosed(
            shiftDate: dateStr,
            cashTotal: cash,
            transferTotal: transfer,
            cashInDrawer: drawer,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          ),
        );

    Navigator.pop(context, true);
  }
}
