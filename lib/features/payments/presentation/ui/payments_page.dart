import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/printing/pdf_service.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/core/widgets/page_entrance.dart';

import 'package:rental_app/features/clients/data/repositories/clients_repository_impl.dart';
import 'package:rental_app/features/clients/domain/entities/models.dart';
import 'package:rental_app/features/payments/data/repositories/payments_repository_impl.dart';
import 'package:rental_app/features/payments/domain/entities/models.dart';
import 'package:rental_app/features/payments/presentation/bloc/payments_bloc.dart';
import 'package:rental_app/features/payments/presentation/ui/payment_details_page.dart';
import 'package:rental_app/features/rents/data/repositories/rents_repository_impl.dart';
import 'package:rental_app/features/rents/domain/entities/models.dart';

/* -------------------- VALIDATION -------------------- */

String? validateAmount(String? value) {
  if (value == null || value.trim().isEmpty) return 'الرجاء إدخال المبلغ';
  final v = double.tryParse(value.trim());
  if (v == null || v <= 0) return 'الرجاء إدخال مبلغ صحيح';
  return null;
}

/* -------------------- PAGE -------------------- */

class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => PaymentsRepository(context.read<ApiClient>())),
        RepositoryProvider(create: (_) => ClientsRepository(context.read<ApiClient>())),
        RepositoryProvider(create: (_) => RentsRepository(context.read<ApiClient>())),
      ],
      child: BlocProvider(
        create: (context) => PaymentsBloc(context.read<PaymentsRepository>())..add(const PaymentsRequested()),
        child: _PaymentsView(showBackButton: Navigator.canPop(context)),
      ),
    );
  }
}

/* -------------------- VIEW -------------------- */

class _PaymentsView extends StatelessWidget {
  const _PaymentsView({required this.showBackButton});
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomAppBar(
                title: 'السندات',
                onIconPressed: showBackButton ? () => Navigator.pop(context) : null,
                actions: [
                  BlocBuilder<PaymentsBloc, PaymentsState>(
                    builder: (context, state) {
                      return IconButton(
                        tooltip: state.showVoided ? 'إخفاء الملغية' : 'إظهار الملغية',
                        icon: Icon(state.showVoided ? Icons.visibility : Icons.visibility_off),
                        color: Colors.white,
                        onPressed: () {
                          context.read<PaymentsBloc>().add(PaymentsRequested(showVoided: !state.showVoided));
                        },
                      );
                    },
                  ),
                ],
              ),
              Material(
                color: Theme.of(context).colorScheme.primary,
                child: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(text: 'سندات العقود'),
                    Tab(text: 'سندات عامة'),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'payments_fab',
          icon: const Icon(Icons.add),
          label: const Text('إضافة سند'),
          onPressed: () => _openDialog(context),
        ),
        body: PageEntrance(
          child: TabBarView(
            children: [
              _PaymentsList(scope: _PaymentsScope.rent, onEdit: (p) => _openDialog(context, edit: p)),
              _PaymentsList(scope: _PaymentsScope.general, onEdit: (p) => _openDialog(context, edit: p)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDialog(BuildContext context, {Payment? edit}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<PaymentsBloc>(),
        child: _PaymentDialog(
          edit: edit,
          clientsRepo: context.read<ClientsRepository>(),
          rentsRepo: context.read<RentsRepository>(),
        ),
      ),
    );

    if (ok == true && context.mounted) {
      context.read<PaymentsBloc>().add(
            PaymentsRequested(showVoided: context.read<PaymentsBloc>().state.showVoided),
          );
    }
  }

  Future<void> _confirmVoid(BuildContext context, Payment p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content: Text('هل تريد إلغاء السند رقم #${p.id}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إلغاء السند'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      context.read<PaymentsBloc>().add(PaymentVoided(id: p.id));
    }
  }
}

/* -------------------- LIST -------------------- */

enum _PaymentsScope { rent, general }

class _PaymentsList extends StatelessWidget {
  const _PaymentsList({required this.scope, required this.onEdit});

  final _PaymentsScope scope;
  final void Function(Payment p) onEdit;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaymentsBloc, PaymentsState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      builder: (context, state) {
        if (state.status == PaymentsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = state.items.where((p) {
          final hasRent = (p.rentId != null) && (p.rentId != 0);
          return scope == _PaymentsScope.rent ? hasRent : !hasRent;
        }).toList();

        if (items.isEmpty) {
          return Center(child: Text(scope == _PaymentsScope.rent ? 'لا توجد سندات عقود' : 'لا توجد سندات عامة'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, index) => _PaymentCard(payment: items[index], onEdit: onEdit),
        );
      },
    );
  }
}

/* -------------------- CARD -------------------- */

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment, required this.onEdit});
  final Payment payment;
  final void Function(Payment p) onEdit;

  @override
  Widget build(BuildContext context) {
    final isIn = (payment.type ?? '').toLowerCase() == 'in';
    final isVoided = payment.isVoid;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PaymentDetailsPage(payment: payment)),
        ),
        leading: CircleAvatar(
          backgroundColor: isIn ? Colors.green : Colors.red,
          child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: Colors.white),
        ),
        title: Text(
          '#${payment.id} • ${(payment.amount ?? 0).toStringAsFixed(0)} ر.س',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isIn ? 'قبض' : 'صرف'),
              Text('العميل: ${payment.clientName ?? '-'}'),
              Text('العقد: ${payment.rentNo ?? '-'}'),
              if (!isVoided && isIn && (payment.rentId ?? 0) != 0) const Text('الحالة: مسدد', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        trailing: isVoided
            ? const Chip(label: Text('ملغي'), backgroundColor: Colors.grey)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'طباعة السند',
                    icon: const Icon(Icons.print),
                    onPressed: () async {
                      try {
                        await PdfService().printPaymentVoucher(payment: payment);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الطباعة: $e')));
                        }
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'مشاركة PDF',
                    icon: const Icon(Icons.share),
                    onPressed: () async {
                      try {
                        await PdfService().sharePaymentVoucher(payment: payment);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل المشاركة: $e')));
                        }
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'تعديل',
                    icon: const Icon(Icons.edit),
                    onPressed: () => onEdit(payment),
                  ),
                  IconButton(
                    tooltip: 'إلغاء السند',
                    icon: const Icon(Icons.block),
                    color: Colors.red,
                    onPressed: () {
                      context.findAncestorWidgetOfExactType<_PaymentsView>()!._confirmVoid(context, payment);
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

/* -------------------- DIALOG -------------------- */

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.clientsRepo,
    required this.rentsRepo,
    this.edit,
  });

  final ClientsRepository clientsRepo;
  final RentsRepository rentsRepo;
  final Payment? edit;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _amount = TextEditingController();
  final _ref = TextEditingController();
  final _notes = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _type = 'in';
  String _method = 'cash';
  int? _clientId;
  int? _rentId;

  List<Client> _clients = [];
  List<Rent> _rents = [];
  bool _loading = true;

  bool _submitted = false;
  bool _localSubmitting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.edit;
    if (p != null) {
      _amount.text = (p.amount ?? 0).toString();
      _ref.text = p.referenceNo ?? '';
      _notes.text = p.notes ?? '';
      _type = p.type ?? 'in';
      _method = p.method ?? 'cash';
      _clientId = p.clientId;
      _rentId = p.rentId;
    }
    _load();
  }

  Future<void> _load() async {
    final c = await widget.clientsRepo.list();
    final r = await widget.rentsRepo.list();
    if (!mounted) return;
    setState(() {
      _clients = c;
      _rents = r;
      _clientId ??= _clients.isNotEmpty ? _clients.first.id : null;
      _rentId ??= null;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.edit != null;
    return AlertDialog(
      title: Text(editing ? 'تعديل سند' : 'إضافة سند'),
      content: _loading
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!editing)
                      DropdownButtonFormField<String>(
                        value: _type,
                        decoration: const InputDecoration(labelText: 'النوع'),
                        items: const [
                          DropdownMenuItem(value: 'in', child: Text('قبض')),
                          DropdownMenuItem(value: 'out', child: Text('صرف')),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? 'in'),
                      ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _amount,
                      validator: validateAmount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: _clientId,
                      decoration: const InputDecoration(labelText: 'العميل (اختياري)'),
                      items: _clients.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.id} - ${c.name}'))).toList(),
                      onChanged: (v) => setState(() => _clientId = v),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      value: _rentId,
                      decoration: const InputDecoration(labelText: 'العقد (اختياري)'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('-')),
                        ..._rents.map((r) => DropdownMenuItem<int?>(value: r.id, child: Text('عقد #${r.id}'))),
                      ],
                      onChanged: (v) => setState(() => _rentId = v),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _method,
                      decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('كاش')),
                        DropdownMenuItem(value: 'bank', child: Text('تحويل')),
                        DropdownMenuItem(value: 'card', child: Text('بطاقة')),
                      ],
                      onChanged: (v) => setState(() => _method = v ?? 'cash'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _ref,
                      decoration: const InputDecoration(labelText: 'رقم مرجعي (اختياري)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notes,
                      decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        BlocConsumer<PaymentsBloc, PaymentsState>(
          listener: (context, state) {
            if (state.error != null) {
              _submitted = false;
              if (mounted) setState(() => _localSubmitting = false);
            }
            if (_submitted && !state.working && state.error == null) {
              _submitted = false;
              if (mounted) setState(() => _localSubmitting = false);
              Navigator.pop(context, true);
            }
          },
          builder: (context, state) {
            final disabled = state.working || _localSubmitting;
            return ElevatedButton(
              onPressed: disabled
                  ? null
                  : () {
                      if (!_formKey.currentState!.validate()) return;

                      final amt = double.tryParse(_amount.text.trim()) ?? 0;
                      setState(() => _localSubmitting = true);
                      _submitted = true;

                      if (editing) {
                        context.read<PaymentsBloc>().add(
                              PaymentUpdated(
                                id: widget.edit!.id,
                                amount: amt,
                                clientId: _clientId,
                                rentId: _rentId,
                                method: _method,
                                referenceNo: _ref.text.trim().isEmpty ? null : _ref.text.trim(),
                                notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                              ),
                            );
                      } else {
                        context.read<PaymentsBloc>().add(
                              PaymentCreated(
                                type: _type,
                                amount: amt,
                                clientId: _clientId,
                                rentId: _rentId,
                                method: _method,
                                referenceNo: _ref.text.trim().isEmpty ? null : _ref.text.trim(),
                                notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                              ),
                            );
                      }
                    },
              child: disabled
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ'),
            );
          },
        ),
      ],
    );
  }
}
