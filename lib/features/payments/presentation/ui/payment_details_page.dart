import 'package:flutter/material.dart';
import 'package:rental_app/features/payments/domain/entities/models.dart';

class PaymentDetailsPage extends StatelessWidget {
  const PaymentDetailsPage({super.key, required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final isIn = payment.type == 'in';
    final statusColor = payment.isVoid ? Colors.grey : (isIn ? Colors.green : Colors.red);
    final statusText = payment.isVoid ? 'ملغي' : (isIn ? 'مدفوع' : 'مسجل');

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل السند'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: statusColor,
                          child: Icon(
                            isIn ? Icons.money : Icons.money_off,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '#${payment.id}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${payment.amount.toStringAsFixed(2)} ر.س',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: isIn ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Payment Information
            const Text(
              'معلومات السند',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _buildInfoCard([
              _buildInfoRow('نوع السند', isIn ? 'دخل' : 'صرف'),
              _buildInfoRow('طريقة الدفع', _getMethodDisplay(payment.method)),
              _buildInfoRow('رقم المرجعي', payment.referenceNo ?? '-'),
              _buildInfoRow('ملاحظات', payment.notes ?? '-'),
              _buildInfoRow('وقت الإنشاء', _formatDateTimeString(payment.createdAt)), // createdAt is String in Payment model
              _buildInfoRow('وقت الإلغاء', payment.voidedAt != null ? _formatDateTimeString(payment.voidedAt!) : '-'),
            ]),

            const SizedBox(height: 24),

            // Related Information
            const Text(
              'المعلومات المرتبطة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _buildInfoCard([
              _buildInfoRow('اسم العميل', payment.clientName ?? '-'),
              _buildInfoRow('رقم العقد', payment.rentNo != null ? 'عقد #${payment.rentNo}' : '-'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '$label: ',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMethodDisplay(String? method) {
    if (method == null) return '-';
    switch (method.toLowerCase()) {
      case 'cash':
        return 'كاش';
      case 'bank':
        return 'تحويل';
      case 'card':
        return 'بطاقة';
      default:
        return method;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTimeString(String? dateString) {
    if (dateString == null) return '-';
    try {
      final dateTime = DateTime.parse(dateString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}