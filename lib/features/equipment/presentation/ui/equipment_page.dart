import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/core/widgets/equipment_search_delegate.dart';
import 'package:rental_app/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:rental_app/features/equipment/domain/entities/models.dart';
import 'package:rental_app/features/equipment/presentation/bloc/equipment_bloc.dart';
import 'package:rental_app/features/equipment/presentation/ui/equipment_details_page.dart';
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

String? validateName(String? value) {
  return validateField(value, isNumber: false, isRequired: true);
}

String? validateModel(String? value) {
  return validateField(value, isNumber: false, isRequired: false);
}

String? validateSerialNo(String? value) {
  return validateField(value, isNumber: false, isRequired: false);
}

String? validateDailyRate(String? value) {
  if (value == null || value.isEmpty) {
    return 'الرجاء إدخال السعر اليومي';
  }
  
  final numValue = double.tryParse(value);
  if (numValue == null || numValue < 0) {
    return 'الرجاء إدخال قيمة عددية صحيحة';
  }
  
  return null;
}

String? validateDepreciationRate(String? value) {
  if (value == null || value.isEmpty) {
    return 'الرجاء إدخال نسبة الإهلاك';
  }
  
  final numValue = double.tryParse(value);
  if (numValue == null || numValue < 0) {
    return 'الرجاء إدخال قيمة عددية صحيحة';
  }
  
  return null;
}

class EquipmentPage extends StatelessWidget {
  const EquipmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => EquipmentRepository(context.read<ApiClient>()),
      child: BlocProvider(
        create: (ctx) =>
            EquipmentBloc(ctx.read<EquipmentRepository>())
              ..add(EquipmentRequested()),
        child: _EquipmentView(
          showBackButton: Navigator.canPop(context),
        ),
      ),
    );
  }
}

/* -------------------- VIEW -------------------- */

class _EquipmentView extends StatelessWidget {
  const _EquipmentView({this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'المعدات',
        onIconPressed: showBackButton ? () {
          Navigator.pop(context);
        } : null,
        icon: () async {
        final items = context.read<EquipmentBloc>().state.items; // أو state.equipment حسب عندك
        await showSearch(
          context: context,
          delegate: EquipmentSearchDelegate(items),
        );
      },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'equipment_fab', // Unique hero tag to avoid conflicts
        icon: const Icon(Icons.add),
        label: const Text('إضافة معدة'),
        onPressed: () => _openDialog(context),
      ),
      body: PageEntrance(
        child: BlocConsumer<EquipmentBloc, EquipmentState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!)),
            );
          }
        },
        builder: (context, state) {
          if (state.status == EquipmentStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.items.isEmpty) {
            return const Center(child: Text('لا توجد معدات'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final equipment = state.items[index];
              return _EquipmentCard(equipment: equipment);
            },
          );
        },
        ),
      ),
    );
  }

  void _openDialog(BuildContext context, {Equipment? edit}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<EquipmentBloc>(),
        child: EquipmentDialog(edit: edit),
      ),
    );

    if (ok == true && context.mounted) {
      context.read<EquipmentBloc>().add(EquipmentRequested());
    }
  }
}

/* -------------------- CARD -------------------- */
class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({required this.equipment});

  final Equipment equipment;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _statusColor(equipment.status),
            child: const Icon(
              Icons.precision_manufacturing,
              color: Colors.white,
            ),
          ),
          title: Text(
            equipment.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الرقم التسلسلي: ${equipment.serialNo ?? '-'}'),
                Text(
                  'السعر: ${equipment.dailyRate.toStringAsFixed(0)} ر.ي / يوم',
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'تعديل',
                icon: const Icon(Icons.edit),
                color: Theme.of(context).colorScheme.primary,
                onPressed: () {
                  context.findAncestorWidgetOfExactType<_EquipmentView>()!
                      ._openDialog(context, edit: equipment);
                },
              ),
              IconButton(
                tooltip: 'حذف',
                icon: const Icon(Icons.delete),
                color: Colors.red,
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EquipmentDetailsPage(equipment: equipment),
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف "${equipment.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
          
        ],
      ),
    );

    if (ok == true && context.mounted) {
      context
          .read<EquipmentBloc>()
          .add(EquipmentDeleted(equipment.id));
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'rented':
        return Colors.orange;
      case 'maintenance':
        return Colors.red;
      default:
        return Colors.green;
    }
  }
}

/* -------------------- DIALOG -------------------- */

class EquipmentDialog extends StatefulWidget {
  const EquipmentDialog({super.key, this.edit});

  final Equipment? edit;

  @override
  State<EquipmentDialog> createState() => _EquipmentDialogState();
}

class _EquipmentDialogState extends State<EquipmentDialog> {
  final _name = TextEditingController();
  final _model = TextEditingController();
  final _serial = TextEditingController();
  final _rate = TextEditingController();
  final _dep = TextEditingController();
  final _purchase = TextEditingController();
  final _salvage = TextEditingController();
  final _lifeMonths = TextEditingController();
  final _startDate = TextEditingController();
  final _usageDays = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _status = 'available';
  bool _active = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _name.text = e.name;
      _model.text = e.model ?? '';
      _serial.text = e.serialNo ?? '';
      _rate.text = e.dailyRate.toString();
      _dep.text = e.depreciationRate.toString();
      _purchase.text = e.purchasePrice.toString();
      _salvage.text = e.salvageValue.toString();
      _lifeMonths.text = e.usefulLifeMonths.toString();
      _startDate.text = e.depreciationStartDate ?? '';
      _usageDays.text = e.estimatedUsageDays.toString();
      _status = e.status ?? 'available';
      _active = e.isActive;
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.edit != null;

    return AlertDialog(
      title: Text(editing ? 'تعديل معدة' : 'إضافة معدة'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                validator: validateName,
                decoration: const InputDecoration(
                  labelText: 'الاسم',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _model,
                validator: validateModel,
                decoration: const InputDecoration(
                  labelText: 'الموديل',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _serial,
                validator: validateSerialNo,
                decoration: const InputDecoration(
                  labelText: 'الرقم التسلسلي',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rate,
                      validator: validateDailyRate,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'السعر اليومي',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _dep,
                      validator: validateDepreciationRate,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'نسبة الإهلاك % (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _purchase,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'سعر الشراء',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _salvage,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'القيمة المتبقية',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _lifeMonths,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'العمر بالأشهر',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _usageDays,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'أيام الاستخدام المتوقعة',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _startDate,
                decoration: const InputDecoration(
                  labelText: 'تاريخ بدء الإهلاك YYYY-MM-DD',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'الحالة',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'available', child: Text('🟢 متاح')),
                  DropdownMenuItem(value: 'rented', child: Text('🟠 مؤجر')),
                  DropdownMenuItem(
                      value: 'maintenance', child: Text('🔴 صيانة')),
                ],
                onChanged: (v) => setState(() => _status = v!),
              ),
              SwitchListTile.adaptive(
                value: _active,
                title: const Text('نشطة'),
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('حفظ'),
          onPressed: _submitting ? null : () => _save(context, editing),
        ),
      ],
    );
  }

  void _save(BuildContext context, bool editing) {
    if (_formKey.currentState!.validate()) {
      setState(() => _submitting = true);

      final rate = double.tryParse(_rate.text) ?? 0;
      final dep = double.tryParse(_dep.text) ?? 0;
      final purchase = double.tryParse(_purchase.text) ?? 0;
      final salvage = double.tryParse(_salvage.text) ?? 0;
      final lifeMonths = int.tryParse(_lifeMonths.text) ?? 60;
      final usageDays = int.tryParse(_usageDays.text) ?? 365;
      final startDate = _startDate.text.trim().isEmpty ? null : _startDate.text.trim();

      if (editing) {
        context.read<EquipmentBloc>().add(
              EquipmentUpdated(
                id: widget.edit!.id,
                name: _name.text.trim(),
                model: _model.text.trim(),
                serialNo: _serial.text.trim(),
                status: _status,
                dailyRate: rate,
                depreciationRate: dep,
                isActive: _active,
                purchasePrice: purchase,
                salvageValue: salvage,
                usefulLifeMonths: lifeMonths,
                depreciationStartDate: startDate,
                estimatedUsageDays: usageDays,
              ),
            );
      } else {
        context.read<EquipmentBloc>().add(
              EquipmentCreated(
                name: _name.text.trim(),
                model: _model.text.trim(),
                serialNo: _serial.text.trim(),
                status: _status,
                dailyRate: rate,
                depreciationRate: dep,
                isActive: _active,
                purchasePrice: purchase,
                salvageValue: salvage,
                usefulLifeMonths: lifeMonths,
                depreciationStartDate: startDate,
                estimatedUsageDays: usageDays,
              ),
            );
      }

      Navigator.pop(context, true);
    }
  }
}
