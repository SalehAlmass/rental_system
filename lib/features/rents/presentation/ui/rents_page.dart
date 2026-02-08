import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/core/widgets/page_entrance.dart';

import 'package:rental_app/features/clients/data/repositories/clients_repository_impl.dart';
import 'package:rental_app/features/clients/domain/entities/models.dart';

import 'package:rental_app/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:rental_app/features/equipment/domain/entities/models.dart';

import 'package:rental_app/features/rents/data/repositories/rents_repository_impl.dart';
import 'package:rental_app/features/rents/domain/entities/models.dart';
import 'package:rental_app/features/rents/presentation/bloc/rents_bloc.dart';
import 'package:rental_app/features/rents/presentation/ui/rent_details_page.dart';

/// ===================== Helpers =====================

String nowSql() {
  final n = DateTime.now();
  String two(int x) => x.toString().padLeft(2, '0');
  return "${n.year}-${two(n.month)}-${two(n.day)} "
      "${two(n.hour)}:${two(n.minute)}:${two(n.second)}";
}

String? validateRate(String? value) {
  if (value == null || value.trim().isEmpty) return null; // optional
  final numValue = double.tryParse(value.trim());
  if (numValue == null || numValue < 0) {
    return 'الرجاء إدخال قيمة عددية صحيحة';
  }
  return null;
}

/// ===================== PAGE =====================

class RentsPage extends StatelessWidget {
  const RentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (_) => RentsRepository(context.read<ApiClient>()),
        ),
        RepositoryProvider(
          create: (_) => ClientsRepository(context.read<ApiClient>()),
        ),
        RepositoryProvider(
          create: (_) => EquipmentRepository(context.read<ApiClient>()),
        ),
      ],
      child: BlocProvider(
        create: (context) =>
            RentsBloc(context.read<RentsRepository>())
              ..add(const RentsRequested()),
        child: _RentsView(showBackButton: Navigator.canPop(context)),
      ),
    );
  }
}

/// ===================== VIEW =====================

class _RentsView extends StatefulWidget {
  const _RentsView({this.showBackButton = true});
  final bool showBackButton;

  @override
  State<_RentsView> createState() => _RentsViewState();
}

class _RentsViewState extends State<_RentsView> {
  String _statusFilter = 'all';
  String? get _statusParam => _statusFilter == 'all' ? null : _statusFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'العقود',
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                dropdownColor: Theme.of(context).colorScheme.primary,
                icon: Icon(
                  Icons.filter_list,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                value: _statusFilter,
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text(
                      'الكل',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'open',
                    child: Text(
                      'مفتوحة',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'closed',
                    child: Text(
                      'مغلقة',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'cancelled',
                    child: Text(
                      'ملغاة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _statusFilter = v);
                  context.read<RentsBloc>().add(
                    RentsRequested(status: _statusParam),
                  );
                },
              ),
            ),
          ),
        ],
        onIconPressed: widget.showBackButton
            ? () => Navigator.pop(context)
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'rents_fab',
        icon: const Icon(Icons.add),
        label: const Text('فتح عقد'),
        onPressed: () => _openDialog(context),
      ),
      body: PageEntrance(
        child: BlocConsumer<RentsBloc, RentsState>(
          listener: (context, state) {
            if (state.error != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.error!)));
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
              itemBuilder: (context, i) {
                return _RentCard(
                  rent: state.items[i],
                  onClosed: (rentId) {
                    context.read<RentsBloc>().add(
                      RentClosed(rentId: rentId, endDatetime: nowSql()),
                    );
                  },
                  onCancelled: (rentId) {
                    context.read<RentsBloc>().add(
                      RentCancelled(rentId: rentId),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

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
      context.read<RentsBloc>().add(RentsRequested(status: _statusParam));
    }
  }
}

/// ===================== CARD =====================

class _RentCard extends StatelessWidget {
  const _RentCard({
    required this.rent,
    required this.onClosed,
    required this.onCancelled,
  });

  final Rent rent;
  final void Function(int rentId) onClosed;
  final void Function(int rentId) onCancelled;

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
                    onPressed: () => onClosed(rent.id),
                  ),
                  IconButton(
                    tooltip: 'إلغاء العقد',
                    icon: const Icon(Icons.block),
                    color: Colors.red,
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('تأكيد الإلغاء'),
                          content: Text(
                            'هل تريد إلغاء العقد رقم #${rent.id} ؟',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('تراجع'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('إلغاء العقد'),
                            ),
                          ],
                        ),
                      );

                      if (ok == true && context.mounted) {
                        onCancelled(rent.id);
                      }
                    },
                  ),
                ],
              ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RentDetailsPage(rentId: rent.id)),
          );
        },
      ),
    );
  }
}

/// ===================== OPEN RENT DIALOG =====================

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
      _equipment = e
          .where((x) => (x.status ?? 'available') != 'rented')
          .toList();
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
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.id} - ${c.name}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _clientId = v),
                    decoration: const InputDecoration(labelText: 'العميل'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _equipmentId,
                    items: _equipment
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.id,
                            child: Text('${e.id} - ${e.name}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _equipmentId = v),
                    decoration: const InputDecoration(labelText: 'المعدة'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rateCtrl,
                    validator: validateRate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'سعر الساعة (اختياري)',
                      border: OutlineInputBorder(),
                    ),
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

                      if (!_formKey.currentState!.validate()) return;

                      setState(() {
                        _localSubmitting = true;
                        _submitted = true;
                      });

                      final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;

                      context.read<RentsBloc>().add(
                        RentOpened(
                          clientId: _clientId!,
                          equipmentId: _equipmentId!,
                          startDatetime: nowSql(),
                          hourlyRate: rate,
                        ),
                      );
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
