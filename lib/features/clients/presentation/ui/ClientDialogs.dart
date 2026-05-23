import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/clients/domain/entities/models.dart';
import 'package:rental_app/features/clients/presentation/bloc/clients_bloc.dart';

// Global validation functions that can be reused across the app
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
    if (isNumber && !RegExp(r'^\d+$').hasMatch(value)) {
      return 'الرجاء إدخال أرقام فقط';
    }

    if (!isNumber && RegExp(r'^\d+$').hasMatch(value)) {
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

String? validatePhone(String? value) {
  if (value == null || value.isEmpty) {
    return 'الرجاء إدخال رقم الجوال';
  }

  if (!RegExp(r'^\d+$').hasMatch(value)) {
    return 'الرجاء إدخال أرقام فقط';
  }

  if (value.length != 9) {
    return 'رقم الجوال يجب أن يكون 9 أرقام';
  }

  return null;
}

String? validateNationalId(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  if (!RegExp(r'^\d+$').hasMatch(value)) {
    return 'الرجاء إدخال أرقام فقط';
  }

  return null;
}

String? validateAddress(String? value) {
  return validateField(value, isNumber: false, isRequired: false);
}

class CreateClientDialog extends StatefulWidget {
  const CreateClientDialog({super.key});

  @override
  State<CreateClientDialog> createState() => _CreateClientDialogState();
}

class _CreateClientDialogState extends State<CreateClientDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _nid = TextEditingController();
  final _addr = TextEditingController();
  final _creditLimit = TextEditingController(text: '0');
  bool _isFrozen = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _nid.dispose();
    _addr.dispose();
    _creditLimit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة عميل'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                validator: (val) {
                  final baseError = validateName(val);
                  if (baseError != null) return baseError;
                  final clients = context.read<ClientsBloc>().state.items;
                  if (clients.any((c) => c.name.trim() == val!.trim())) {
                    return 'تمت اضافة هذا العميل مسبقا';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'الاسم',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phone,
                validator: (val) {
                  final baseError = validatePhone(val);
                  if (baseError != null) return baseError;
                  final clients = context.read<ClientsBloc>().state.items;
                  if (clients.any((c) => c.phone?.trim() == val!.trim())) {
                    return 'تمت اضافة هذا العميل مسبقا';
                  }
                  return null;
                },
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الجوال',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nid,
                validator: (val) {
                  final baseError = validateNationalId(val);
                  if (baseError != null) return baseError;
                  if (val!.trim().isEmpty) return null;
                  final clients = context.read<ClientsBloc>().state.items;
                  if (clients.any((c) => c.nationalId?.trim() == val.trim())) {
                    return 'تمت اضافة هذا العميل مسبقا';
                  }
                  return null;
                },
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'رقم الهوية',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addr,
                validator: validateAddress,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _creditLimit,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الحد الائتماني',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val != null && val.isNotEmpty) {
                    if (double.tryParse(val) == null) {
                      return 'الرجاء إدخال رقم صحيح';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('إيقاف العميل (تجميد)'),
                value: _isFrozen,
                onChanged: (val) {
                  setState(() {
                    _isFrozen = val;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final nationalId = _nid.text.trim();
              Navigator.pop(context, {
                "name": _name.text.trim(),
                "phone": _phone.text.trim(),
                "nationalId": nationalId.isEmpty ? null : nationalId,
                "address": _addr.text.trim(),
                "creditLimit": double.tryParse(_creditLimit.text.trim()) ?? 0.0,
                "isFrozen": _isFrozen ? 1 : 0,
              });
            }
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

// ---------- Edit Dialog مشابه ----------
class EditClientDialog extends StatefulWidget {
  const EditClientDialog({required this.client, super.key});
  final Client client;

  @override
  State<EditClientDialog> createState() => _EditClientDialogState();
}

class _EditClientDialogState extends State<EditClientDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _nid;
  late final TextEditingController _addr;
  late final TextEditingController _creditLimit;
  late bool _isFrozen;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.client.name);
    _phone = TextEditingController(text: widget.client.phone);
    _nid = TextEditingController(text: widget.client.nationalId);
    _addr = TextEditingController(text: widget.client.address);
    _creditLimit = TextEditingController(text: widget.client.creditLimit.toString());
    _isFrozen = widget.client.isFrozen == 1;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _nid.dispose();
    _addr.dispose();
    _creditLimit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ClientsBloc>();

    return AlertDialog(
      title: const Text('تعديل العميل'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                validator: (val) {
                  final baseError = validateName(val);
                  if (baseError != null) return baseError;
                  final clients = context.read<ClientsBloc>().state.items;
                  if (clients.any((c) => c.id != widget.client.id && c.name.trim() == val!.trim())) {
                    return 'تمت اضافة هذا العميل مسبقا';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'الاسم',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phone,
                validator: (val) {
                  final baseError = validatePhone(val);
                  if (baseError != null) return baseError;
                  final clients = context.read<ClientsBloc>().state.items;
                  if (clients.any((c) => c.id != widget.client.id && c.phone?.trim() == val!.trim())) {
                    return 'تمت اضافة هذا العميل مسبقا';
                  }
                  return null;
                },
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الجوال',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nid,
                validator: (val) {
                  final baseError = validateNationalId(val);
                  if (baseError != null) return baseError;
                  if (val!.trim().isEmpty) return null;
                  final clients = context.read<ClientsBloc>().state.items;
                  if (clients.any((c) => c.id != widget.client.id && c.nationalId?.trim() == val.trim())) {
                    return 'تمت اضافة هذا العميل مسبقا';
                  }
                  return null;
                },
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'رقم الهوية',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addr,
                validator: validateAddress,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _creditLimit,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الحد الائتماني',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val != null && val.isNotEmpty) {
                    if (double.tryParse(val) == null) {
                      return 'الرجاء إدخال رقم صحيح';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('إيقاف العميل (تجميد)'),
                value: _isFrozen,
                onChanged: (val) {
                  setState(() {
                    _isFrozen = val;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        BlocConsumer<ClientsBloc, ClientsState>(
          listener: (context, state) {
            if (state.error != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.error!)));
            }

            if (state.action == ClientsAction.created ||
                state.action == ClientsAction.updated) {
              Navigator.pop(context, true);
            }
          },
          builder: (context, state) {
            return ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('حفظ'),
              onPressed: state.creating
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        final nationalId = _nid.text.trim();
                        bloc.add(
                          ClientUpdated(
                            id: widget.client.id,
                            name: _name.text.trim(),
                            phone: _phone.text.trim(),
                            nationalId: nationalId.isEmpty ? null : nationalId,
                            address: _addr.text.trim(),
                            creditLimit: double.tryParse(_creditLimit.text.trim()) ?? 0.0,
                            isFrozen: _isFrozen ? 1 : 0,
                          ),
                        );
                      }
                    },
            );
          },
        ),
      ],
    );
  }
}
