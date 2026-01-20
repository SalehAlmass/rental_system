import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/equipment/domain/entities/models.dart';
import 'package:rental_app/features/equipment/presentation/bloc/equipment_bloc.dart';

class EquipmentDetailsPage extends StatelessWidget {
  const EquipmentDetailsPage({super.key, required this.equipment});

  final Equipment equipment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تفاصيل المعدة'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with equipment name
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.precision_manufacturing,
                      size: 60,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      equipment.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Equipment details card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: _getStatusColor(equipment.status).withOpacity(0.3), width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status indicator
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getStatusColor(equipment.status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getStatusText(equipment.status),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(equipment.status),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Equipment information
                      _buildDetailItem('الاسم', equipment.name),
                      const Divider(),
                      _buildDetailItem('الموديل', equipment.model ?? '-'),
                      const Divider(),
                      _buildDetailItem('الرقم التسلسلي', equipment.serialNo ?? '-'),
                      const Divider(),
                      _buildDetailItem('سعر الساعة', '${equipment.hourlyRate.toStringAsFixed(0)} ر.س'),
                      const Divider(),
                      _buildDetailItem('نسبة الإهلاك', '${equipment.depreciationRate.toStringAsFixed(0)} %'),
                      const Divider(),
                      _buildDetailItem(
                        'الحالة النشاطية', 
                        equipment.isActive ? 'نشطة' : 'غير نشطة'
                      ),
                      const Divider(),
                      _buildDetailItem(
                        'تاريخ آخر صيانة', 
                        equipment.lastMaintenanceDate ?? 'لم يتم تسجيل تاريخ'
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('عودة'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // You can implement navigation to edit page here
                        // Navigator.pushNamed(
                        //   context, 
                        //   '/equipment/edit', 
                        //   arguments: equipment
                        // );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('تعديل'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'rented':
        return Colors.orange;
      case 'maintenance':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'rented':
        return 'مؤجرة';
      case 'maintenance':
        return 'في الصيانة';
      default:
        return 'متاحة';
    }
  }
}