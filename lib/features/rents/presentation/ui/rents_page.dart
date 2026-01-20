import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/features/clients/data/repositories/clients_repository_impl.dart';
import 'package:rental_app/features/clients/domain/entities/models.dart';
import 'package:rental_app/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:rental_app/features/equipment/domain/entities/models.dart';
import 'package:rental_app/features/rents/data/repositories/rents_repository_impl.dart';
import 'package:rental_app/features/rents/domain/entities/models.dart';
import 'package:rental_app/features/rents/presentation/bloc/rents_bloc.dart';
import 'package:rental_app/features/rents/presentation/ui/rent_details_page.dart';

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

String? validateRate(String? value) {
  if (value == null || value.isEmpty) {
    return null; // Optional field
  }
  
  final numValue = double.tryParse(value);
  if (numValue == null || numValue < 0) {
    return 'الرجاء إدخال قيمة عددية صحيحة';
  }
  
  return null;
}

/* -------------------- PAGE -------------------- */

class RentsPage extends StatelessWidget {
  const RentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => RentsRepository(context.read<ApiClient>())),
        RepositoryProvider(create: (_) => ClientsRepository(context.read<ApiClient>())),
        RepositoryProvider(create: (_) => EquipmentRepository(context.read<ApiClient>())),
      ],
      child: BlocProvider(
        create: (context) =>
            RentsBloc(context.read<RentsRepository>())
              ..add(RentsRequested()),
        child: _RentsView(
          showBackButton: Navigator.canPop(context),
        ),
      ),
    );
  }
}

/* -------------------- VIEW -------------------- */

class _RentsView extends StatelessWidget {
  const _RentsView({this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'العقود',

         onIconPressed: showBackButton ? () {
          Navigator.pop(context);
        } : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'rents_fab', // Unique hero tag to avoid conflicts
        icon: const Icon(Icons.add),
        label: const Text('فتح عقد'),
        onPressed: () => _openDialog(context),
      ),
      body: BlocConsumer<RentsBloc, RentsState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!)),
            );
          }
        },
        builder: (context, state) {
          if (state.status == RentsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.items.isEmpty) {
            return const Center(child: Text('لا توجد عقود'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              return _RentCard(rent: state.items[index]);
            },
          );
        },
      ),
    );
  }

  /* -------------------- HELPERS -------------------- */

  Future<void> _openDialog(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<RentsBloc>(),
        child: _OpenRentDialog(
          clientsRepo: context.read<ClientsRepository>(),
          equipmentRepo: context.read<EquipmentRepository>(),
        ),
      ),
    );

    if (ok == true && context.mounted) {
      context.read<RentsBloc>().add(RentsRequested());
    }
  }

  Future<void> _confirmCancel(BuildContext context, int rentId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content: Text('هل تريد إلغاء العقد رقم #$rentId ؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إلغاء العقد'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      context.read<RentsBloc>().add(RentCancelled(rentId: rentId));
    }
  }

  static String nowSql() {
    final n = DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    return "${n.year}-${two(n.month)}-${two(n.day)} "
        "${two(n.hour)}:${two(n.minute)}:${two(n.second)}";
  }
}

/* -------------------- CARD -------------------- */

class _RentCard extends StatelessWidget {
  const _RentCard({required this.rent});

  final Rent rent;

  @override
  Widget build(BuildContext context) {
    final status = (rent.status ?? '').toLowerCase();
    final isClosed = status == 'closed';
    final isCancelled = status == 'cancelled';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCancelled
              ? Colors.grey
              : isClosed
                  ? Colors.green
                  : Colors.blue,
          child: Icon(
            isCancelled
                ? Icons.block
                : isClosed
                    ? Icons.lock
                    : Icons.lock_open,
            color: Colors.white,
          ),
        ),
        title: Text(
          'عقد #${rent.id}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('العميل: ${rent.clientName ?? rent.clientId}'),
              Text('المعدة: ${rent.equipmentName ?? rent.equipmentId}'),
              Text('${rent.startDatetime} → ${rent.endDatetime ?? "-"}'),
            ],
          ),
        ),
        trailing: isCancelled
            ? const Chip(label: Text('ملغي'))
            : isClosed
                ? Text(
                    '${(rent.totalAmount ?? 0).toStringAsFixed(0)} ر.س',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'إغلاق العقد',
                        icon: const Icon(Icons.lock),
                        color: Colors.green,
                        onPressed: () {
                          context.read<RentsBloc>().add(
                                RentClosed(
                                  rentId: rent.id,
                                  endDatetime: _RentsView.nowSql(),
                                ),
                              );
                        },
                      ),
                      IconButton(
                        tooltip: 'إلغاء العقد',
                        icon: const Icon(Icons.block),
                        color: Colors.red,
                        onPressed: () {
                          context
                              .findAncestorWidgetOfExactType<_RentsView>()!
                              ._confirmCancel(context, rent.id);
                        },
                      ),
                    ],
                  ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RentDetailsPage(rent: rent),
            ),
          );
        },
      ),
    );
  }
}

/* -------------------- OPEN RENT DIALOG -------------------- */

class _OpenRentDialog extends StatefulWidget {
  const _OpenRentDialog({
    required this.clientsRepo,
    required this.equipmentRepo,
  });

  final ClientsRepository clientsRepo;
  final EquipmentRepository equipmentRepo;

  @override
  State<_OpenRentDialog> createState() => _OpenRentDialogState();
}

class _OpenRentDialogState extends State<_OpenRentDialog> {
  List<Client> _clients = [];
  List<Equipment> _equipment = [];
  int? _clientId;
  int? _equipmentId;
  final _rateCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;

  bool _submitted = false;
  bool _localSubmitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await widget.clientsRepo.list();
    final e = await widget.equipmentRepo.list();
    if (!mounted) return;
    setState(() {
      _clients = c;
      _equipment =
          e.where((x) => (x.status ?? 'available') != 'rented').toList();
      _clientId = _clients.isNotEmpty ? _clients.first.id : null;
      _equipmentId = _equipment.isNotEmpty ? _equipment.first.id : null;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('فتح عقد'),
      content: _loading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: _clientId,
                    items: _clients
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.id} - ${c.name}'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _clientId = v),
                    decoration: const InputDecoration(labelText: 'العميل'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _equipmentId,
                    items: _equipment
                        .map((e) => DropdownMenuItem(
                              value: e.id,
                              child: Text('${e.id} - ${e.name}'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _equipmentId = v),
                    decoration: const InputDecoration(labelText: 'المعدة'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rateCtrl,
                    validator: validateRate,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'سعر الساعة (اختياري)', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        BlocConsumer<RentsBloc, RentsState>(
          listener: (context, state) {
            if (state.error != null) {
              _submitted = false;
              setState(() => _localSubmitting = false);
            }
            if (_submitted && !state.working && state.error == null) {
              _submitted = false;
              setState(() => _localSubmitting = false);
              Navigator.pop(context, true);
            }
          },
          builder: (context, state) {
            final disabled = state.working || _localSubmitting;
            return ElevatedButton(
              onPressed: disabled
                  ? null
                  : () {
                      if (_clientId == null || _equipmentId == null) return;
                      setState(() => _localSubmitting = true);
                      _submitted = true;

                      if (_formKey.currentState!.validate()) {
              final rate =
                          double.tryParse(_rateCtrl.text.trim()) ?? 0;

                      context.read<RentsBloc>().add(
                            RentOpened(
                              clientId: _clientId!,
                              equipmentId: _equipmentId!,
                              startDatetime: _RentsView.nowSql(),
                              hourlyRate: rate,
                            ),
                          );
            }
                    },
              child: disabled
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('فتح'),
            );
          },
        ),
      ],
    );
  }
}
