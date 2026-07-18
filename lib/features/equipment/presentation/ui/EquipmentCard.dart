import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/config/app_config.dart';
import 'package:rental_app/core/widgets/permission_guard.dart';
import 'package:rental_app/features/equipment/domain/entities/models.dart';
import 'package:rental_app/features/equipment/presentation/bloc/equipment_bloc.dart';
import 'package:rental_app/features/equipment/presentation/ui/equipment_details_page.dart';
import 'package:rental_app/features/profile/profile_cubit.dart';

class EquipmentCard extends StatelessWidget {
  const EquipmentCard({
    required this.equipment,
    required this.onEdit,
    this.onDelete,
    super.key,
  });

  final Equipment equipment;
  final void Function(Equipment) onEdit;
  final void Function(Equipment)? onDelete;

  @override
  Widget build(BuildContext context) {
    final pstate = context.read<ProfileCubit>().state;
    final canEdit = pstate.hasActionPermission('equipment', 'edit');
    final canDelete = pstate.hasActionPermission('equipment', 'delete');

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
                  'السعر: ${equipment.dailyRate.toStringAsFixed(0)} ${AppConfig.currencySymbol} / يوم',
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canEdit)
                IconButton(
                  tooltip: 'تعديل',
                  icon: const Icon(Icons.edit),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () => onEdit(equipment),
                ),
              if (canDelete)
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
                builder: (context) =>
                    EquipmentDetailsPage(equipment: equipment),
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
      final del = onDelete;
      if (del != null) {
        del(equipment);
      } else {
        context.read<EquipmentBloc>().add(EquipmentDeleted(equipment.id));
      }
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
