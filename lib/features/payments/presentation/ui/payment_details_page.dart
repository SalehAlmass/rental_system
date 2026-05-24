import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rental_app/features/payments/domain/entities/models.dart';

class PaymentDetailsPage extends StatelessWidget {
  const PaymentDetailsPage({super.key, required this.payment, required int paymentId});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final isIn = payment.type.toLowerCase() == 'in';
    final statusColor = payment.isVoid ? Colors.grey : (isIn ? Colors.green : Colors.red);
    final statusText = payment.isVoid ? 'ملغي' : (isIn ? 'سند قبض' : 'سند صرف');
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل السند'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primaryContainer, cs.surfaceContainerHighest],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: statusColor,
                    child: Icon(isIn ? Icons.call_received_rounded : Icons.call_made_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(99)),
                    child: Text(statusText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 12),
                  Text('سند رقم #${payment.id}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(
                    '${payment.amount.round()} ر.ي',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: isIn ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'معلومات السند',
              children: [
                _buildInfoRow('النوع', isIn ? 'قبض' : 'صرف'),
                _buildInfoRow('طريقة الدفع', _methodLabel(payment.method)),
                _buildInfoRow('المرجع', payment.referenceNo ?? '-'),
                _buildInfoRow('تاريخ الإنشاء', _formatDateTimeString(payment.createdAt)),
                _buildInfoRow('الموظف المنشئ', payment.userName ?? '-'),
                _buildInfoRow('وقت الإلغاء', payment.voidedAt != null ? _formatDateTimeString(payment.voidedAt) : '-'),
                _buildInfoRow('سبب الإلغاء', payment.voidReason ?? '-'),
                _buildInfoRow('الملاحظات', payment.notes ?? '-'),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'الربط المحاسبي',
              children: [
                _buildInfoRow('اسم العميل', payment.clientName ?? '-'),
                _buildInfoRow('رقم العقد', payment.rentNo != null ? 'عقد #${payment.rentNo}' : '-'),
                _buildInfoRow('المعدة المرتبطة', payment.equipmentId != null ? 'معدة #${payment.equipmentId}' : '-'),
                _buildInfoRow('أثر السند', isIn ? 'يزيد المقبوضات ويرتبط بالعقد أو العميل' : 'يسجل كمصروف ويؤثر على الصندوق أو صيانة المعدة'),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.rule_folder_outlined, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'هذا السند يدخل ضمن مراجعة الصندوق اليومية، ويظهر أثره في شاشة إغلاق الدوام عند مقارنة المقبوض الفعلي بالمفترض.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static String _methodLabel(String? method) {
    switch ((method ?? '').toLowerCase()) {
      case 'cash':
        return 'نقد';
      case 'bank':
        return 'تحويل';
      case 'card':
        return 'بطاقة';
      default:
        return method?.trim().isEmpty ?? true ? '-' : method!;
    }
  }

  static String _formatDateTimeString(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '-';
    final dateTime = DateTime.tryParse(dateString);
    if (dateTime == null) return dateString;
    return DateFormat('yyyy/MM/dd - hh:mm a', 'en').format(dateTime);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
