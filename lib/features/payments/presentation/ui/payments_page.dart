import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/printing/pdf_service.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/features/clients/data/repositories/clients_repository_impl.dart';
import 'package:rental_app/features/clients/domain/entities/models.dart';
import 'package:rental_app/features/payments/data/repositories/payments_repository_impl.dart';
import 'package:rental_app/features/payments/domain/entities/models.dart';
import 'package:rental_app/features/payments/presentation/bloc/payments_bloc.dart';
import 'package:rental_app/features/rents/data/repositories/rents_repository_impl.dart';
import 'package:rental_app/features/rents/domain/entities/models.dart';
import 'package:rental_app/features/payments/presentation/ui/payment_details_page.dart';
import 'package:rental_app/core/widgets/page_entrance.dart';

// Import validation functions
String? validateField(String? value, {bool isNumber = false, bool isRequired = true, int minLength = 0}) {
  if (isRequired && (value == null || value.isEmpty)) {
    return 'الرجاء إدخال قيمة';
  }
  
  if (value != null && value.isNotEmpty) {
    if (isNumber && !RegExp(r'^\\d+(\\.\\d+)?$').hasMatch(value)) {
      return 'الرجاء إدخال أرقام فقط';
    }
    
    if (!isNumber && RegExp(r'^\\d+$').hasMatch(value)) {
      return 'الحقل لا يمكن أن يكون أرقام فقط';
    }
    
    if (minLength > 0 && value.length < minLength) {
      return 'القيمة يجب أن تحتوي على ${minLength} أحرف على الأقل';
    }
  }
  
  return null;
}

String? validateAmount(String? value) {
  if (value == null || value.isEmpty) {
    return 'الرجاء إدخال المبلغ';
  }
  
  final numValue = double.tryParse(value);
  if (numValue == null || numValue <= 0) {
    return 'الرجاء إدخال مبلغ صحيح';
  }
  
  return null;
}

String? validateReference(String? value) {
  return validateField(value, isNumber: false, isRequired: false);
}

String? validateNotes(String? value) {
  return validateField(value, isNumber: false, isRequired: false);
}

/* -------------------- PAGE -------------------- */

class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (_) => PaymentsRepository(context.read<ApiClient>()),
        ),
        RepositoryProvider(
          create: (_) => ClientsRepository(context.read<ApiClient>()),
        ),
        RepositoryProvider(
          create: (_) => RentsRepository(context.read<ApiClient>()),
        ),
      ],
      child: BlocProvider(
        create: (context) =>
            PaymentsBloc(context.read<PaymentsRepository>())
              ..add(const PaymentsRequested()),
        child: _PaymentsView(
          showBackButton: Navigator.canPop(context),
        ),
      ),
    );
  }
}

/* -------------------- VIEW -------------------- */

class _PaymentsView extends StatelessWidget {
  const _PaymentsView({this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'السندات',
       onIconPressed: showBackButton ? () {
          Navigator.pop(context);
        } : null,
              
       actions: [
         BlocBuilder<PaymentsBloc, PaymentsState>(
            builder: (context, state) {
              return IconButton(
                tooltip: state.showVoided ? 'إخفاء الملغية' : 'إظهار الملغية',
                icon: Icon(
                  state.showVoided
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                color: Colors.white,
                onPressed: () {
                  context.read<PaymentsBloc>().add(
                        PaymentsRequested(showVoided: !state.showVoided),
                      );
                },
              );
            },
          ),],
          ),         
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'payments_fab', // Unique hero tag to avoid conflicts
        icon: const Icon(Icons.add),
        label: const Text('إضافة سند'),
        onPressed: () => _openDialog(context),
      ),
      body: PageEntrance(
        child: BlocConsumer<PaymentsBloc, PaymentsState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!)),
            );
          }
        },
        builder: (context, state) {
          if (state.status == PaymentsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.items.isEmpty) {
            return const Center(child: Text('لا توجد سندات'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              return _PaymentCard(payment: state.items[index]);
            },
          );
        },
        ),
      ),
    );
  }

  /* -------------------- HELPERS -------------------- */

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
            PaymentsRequested(
              showVoided: context.read<PaymentsBloc>().state.showVoided,
            ),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
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

/* -------------------- CARD -------------------- */

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final isIn = payment.type == 'in';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () {
          // Navigate to payment details page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentDetailsPage(payment: payment),
            ),
          );
        },
        leading: CircleAvatar(
          backgroundColor: isIn ? Colors.green : Colors.red,
          child: Icon(
            isIn ? Icons.arrow_downward : Icons.arrow_upward,
            color: Colors.white,
          ),
        ),
        title: Text(
          '#${payment.id} • ${payment.amount.toStringAsFixed(0)} ر.س',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isIn ? 'دخل' : 'صرف'),
              Text('العميل: ${payment.clientName ?? '-'}'),
              Text('العقد: ${payment.rentNo ?? '-'}'),
            ],
          ),
        ),
        trailing: payment.isVoid
            ? const Chip(
                label: Text('ملغي'),
                backgroundColor: Colors.grey,
              )
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('فشل الطباعة: $e')),
                          );
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('فشل المشاركة: $e')),
                          );
                        }
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'تعديل',
                    icon: const Icon(Icons.edit),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () {
                      context
                          .findAncestorWidgetOfExactType<_PaymentsView>()!
                          ._openDialog(context, edit: payment);
                    },
                  ),
                  IconButton(
                    tooltip: 'إلغاء السند',
                    icon: const Icon(Icons.block),
                    color: Colors.red,
                    onPressed: () {
                      context
                          .findAncestorWidgetOfExactType<_PaymentsView>()!
                          ._confirmVoid(context, payment);
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

/* -------------------- DIALOG (كما هو تقريبًا) -------------------- */

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
      _amount.text = p.amount.toString();
      _ref.text = p.referenceNo ?? '';
      _notes.text = p.notes ?? '';
      _type = p.type;
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
      _rentId ??= null; // اختياري
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
                          DropdownMenuItem(value: 'in', child: Text('دخل')),
                          DropdownMenuItem(value: 'out', child: Text('صرف')),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? 'in'),
                      ),
                    TextFormField(
                      controller: _amount,
                      validator: validateAmount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()),
                    ),
                    DropdownButtonFormField<int>(
                      value: _clientId,
                      decoration: const InputDecoration(labelText: 'العميل (اختياري)'),
                      items: _clients.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.id} - ${c.name}'))).toList(),
                      onChanged: (v) => setState(() => _clientId = v),
                    ),
                    DropdownButtonFormField<int?>(
                      value: _rentId,
                      decoration: const InputDecoration(labelText: 'العقد (اختياري)'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('-')),
                        ..._rents.map((r) => DropdownMenuItem<int?>(value: r.id, child: Text('عقد #${r.id}'))),
                      ],
                      onChanged: (v) => setState(() => _rentId = v),
                    ),
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
                    TextFormField(
                      controller: _ref,
                      validator: validateReference,
                      decoration: const InputDecoration(labelText: 'رقم مرجعي', border: OutlineInputBorder()),
                    ),
                    TextFormField(
                      controller: _notes,
                      validator: validateNotes,
                      decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder()),
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
                      if (_formKey.currentState!.validate()) {
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
                      }
                    },
              child: disabled ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('حفظ'),
            );
          },
        ),
      ],
    );
  }
}
