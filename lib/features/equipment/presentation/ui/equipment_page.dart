import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/core/widgets/equipment_search_delegate.dart';
import 'package:rental_app/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:rental_app/features/equipment/domain/entities/models.dart';
import 'package:rental_app/features/equipment/presentation/bloc/equipment_bloc.dart';
import 'package:rental_app/features/equipment/presentation/ui/EquipmentCard.dart';
import 'package:rental_app/core/widgets/page_entrance.dart';

// Import validation functions
String? validateField(
  String? value, {
  bool isNumber = false,
  bool isRequired = true,
  int minLength = 0,
}) {
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
      return 'القيمة يجب أن تحتوي على $minLength أحرف على الأقل';
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
    return null; // جعلها اختيارية
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
        child: _EquipmentView(showBackButton: Navigator.canPop(context)),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => context.read<EquipmentBloc>().add(EquipmentRequested()),
          ),
        ],
        onIconPressed: showBackButton
            ? () {
                Navigator.pop(context);
              }
            : null,
        icon: () async {
          final bloc = context.read<EquipmentBloc>();
          final items = bloc.state.items;
          await showSearch(
            context: context,
            delegate: EquipmentSearchDelegate(items, context.read<EquipmentRepository>(), bloc),
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.error!)));
            }
          },
          builder: (context, state) {
            if (state.status == EquipmentStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                _buildSortingBar(context, state),
                Expanded(
                  child: state.items.isEmpty
                      ? const Center(child: Text('لا توجد معدات'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: state.items.length,
                          itemBuilder: (context, index) {
                            final equipment = state.items[index];
                            return EquipmentCard(
                              equipment: equipment,
                              onEdit: (e) => _openDialog(context, edit: e),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSortingBar(BuildContext context, EquipmentState state) {
    final bloc = context.read<EquipmentBloc>();
    final currentSortBy = state.sortBy ?? 'id';
    final currentSortOrder = state.sortOrder ?? 'desc';

    final sortOptions = {
      'id': 'الترتيب الافتراضي',
      'name': 'الاسم',
      'serial_no': 'الرقم التسلسلي',
      'created_at': 'تاريخ الإضافة',
      'status': 'الحالة',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          const Icon(Icons.sort, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: currentSortBy,
            underline: const SizedBox(),
            items: sortOptions.entries.map((e) {
              return DropdownMenuItem<String>(
                value: e.key,
                child: Text(e.value, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                bloc.add(EquipmentRequested(sortBy: val));
              }
            },
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              currentSortOrder == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
              size: 20,
            ),
            onPressed: () {
              final nextOrder = currentSortOrder == 'asc' ? 'desc' : 'asc';
              bloc.add(EquipmentRequested(sortOrder: nextOrder));
            },
          ),
        ],
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
  final _seriesCount = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();

  String _status = 'available';
  bool _active = true;
  bool _submitting = false;

  void _calculateDepreciationRate() {
    final purchase = double.tryParse(_purchase.text);
    final salvage = double.tryParse(_salvage.text);
    final lifeMonths = int.tryParse(_lifeMonths.text);

    if (purchase != null &&
        salvage != null &&
        lifeMonths != null &&
        purchase > salvage &&
        lifeMonths > 0) {
      final lifeYears = lifeMonths / 12.0;
      final depRate = ((purchase - salvage) / (purchase * lifeYears)) * 100;
      if (_dep.text.isEmpty) {
        _dep.text = depRate.toStringAsFixed(2);
      }
    }
  }

  void _calculateSalvageValue() {
    final purchase = double.tryParse(_purchase.text);
    final depRate = double.tryParse(_dep.text);
    final lifeMonths = int.tryParse(_lifeMonths.text);

    if (purchase != null &&
        depRate != null &&
        lifeMonths != null &&
        depRate > 0 &&
        lifeMonths > 0) {
      final lifeYears = lifeMonths / 12.0;
      final salvage = purchase - (purchase * (depRate / 100) * lifeYears);
      if (_salvage.text.isEmpty) {
        _salvage.text = salvage.toStringAsFixed(2);
      }
    }
  }

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
      _seriesCount.text = '1';
      _status = e.status ?? 'available';
      _active = e.isActive;
    } else {
      final now = DateTime.now();
      _startDate.text =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _model.dispose();
    _serial.dispose();
    _rate.dispose();
    _dep.dispose();
    _purchase.dispose();
    _salvage.dispose();
    _lifeMonths.dispose();
    _startDate.dispose();
    _usageDays.dispose();
    _seriesCount.dispose();
    super.dispose();
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
                decoration: InputDecoration(
                  labelText: editing ? 'الرقم التسلسلي' : 'الرقم التسلسلي الأساسي (اختياري)',
                  helperText: editing ? null : 'عند استخدام السلسلة سيتم توليد الأرقام تلقائيًا مثل: serial 1, serial 2 ...',
                  border: const OutlineInputBorder(),
                ),
              ),
              if (!editing) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _seriesCount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'السلسلة / عدد النسخ',
                    helperText: 'مثال: اكتب 30 لإنشاء ماطور 1 إلى ماطور 30 بنفس البيانات',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final n = int.tryParse((value ?? '').trim());
                    if (n == null || n < 1) return 'أدخل رقمًا صحيحًا أكبر من صفر';
                    if (n > 500) return 'الحد الأعلى للسلسلة 500 معدة في عملية واحدة';
                    return null;
                  },
                ),
              ],
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
                      onChanged: (_) => _calculateSalvageValue(),
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
                      onChanged: (_) {
                        _calculateDepreciationRate();
                        _calculateSalvageValue();
                      },
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
                      onChanged: (_) => _calculateDepreciationRate(),
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
                      onChanged: (_) {
                        _calculateDepreciationRate();
                        _calculateSalvageValue();
                      },
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
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'الحالة',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'available', child: Text('🟢 متاح')),
                  DropdownMenuItem(value: 'rented', child: Text('🟠 مؤجر')),
                  DropdownMenuItem(
                    value: 'maintenance',
                    child: Text('🔴 صيانة'),
                  ),
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
      final seriesCount = editing ? 1 : (int.tryParse(_seriesCount.text.trim()) ?? 1);
      final startDate = _startDate.text.trim().isNotEmpty
          ? _startDate.text.trim()
          : '${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

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
            seriesCount: seriesCount,
          ),
        );
      }

      Navigator.pop(context, true);
    }
  }
}
