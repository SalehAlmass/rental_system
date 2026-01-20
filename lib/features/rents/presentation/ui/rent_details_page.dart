import 'package:flutter/material.dart';
import 'package:rental_app/features/rents/domain/entities/models.dart';

class RentDetailsPage extends StatelessWidget {
  const RentDetailsPage({super.key, required this.rent});

  final Rent rent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تفاصيل العقد'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with rent ID
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment,
                      size: 60,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'عقد #${rent.id}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Rent details card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: _getStatusColor(rent.status).withOpacity(0.3), width: 2),
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
                              color: _getStatusColor(rent.status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getStatusText(rent.status),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(rent.status),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Rent information
                      _buildDetailItem('رقم العقد', rent.id.toString()),
                      const Divider(),
                      _buildDetailItem('اسم العميل', rent.clientName ?? rent.clientId.toString()),
                      const Divider(),
                      _buildDetailItem('اسم المعدة', rent.equipmentName ?? rent.equipmentId.toString()),
                      const Divider(),
                      _buildDetailItem('تاريخ البدء', rent.startDatetime),
                      const Divider(),
                      _buildDetailItem('تاريخ الانتهاء', rent.endDatetime ?? 'لم يتم تحديد تاريخ'),
                      const Divider(),
                      _buildDetailItem('سعر الساعة', '${rent.rate?.toStringAsFixed(0) ?? '0'} ر.س'),
                      const Divider(),
                      _buildDetailItem('عدد الساعات', '${rent.hours?.toStringAsFixed(0) ?? '0'} ساعات'),
                      const Divider(),
                      _buildDetailItem('المبلغ الإجمالي', '${rent.totalAmount?.toStringAsFixed(0) ?? '0'} ر.س'),
                      const Divider(),
                      _buildDetailItem('ملاحظات', rent.notes ?? '-'),
                      const Divider(),
                      _buildDetailItem('الحالة', _getStatusText(rent.status)),
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
            width: 100,
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
    if (status == null) return Colors.grey;
    final s = status.toLowerCase();
    if (s == 'closed') return Colors.green;
    if (s == 'cancelled') return Colors.grey;
    return Colors.blue;
  }

  String _getStatusText(String? status) {
    if (status == null) return 'غير معروف';
    final s = status.toLowerCase();
    if (s == 'closed') return 'مغلق';
    if (s == 'cancelled') return 'ملغي';
    return 'مفعل';
  }
}