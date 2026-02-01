import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/printing/pdf_service.dart';
import 'package:rental_app/features/clients/domain/entities/models.dart';
import 'package:rental_app/features/payments/data/repositories/payments_repository_impl.dart';
import 'package:rental_app/features/rents/data/repositories/rents_repository_impl.dart';

class ClientDetailsPage extends StatelessWidget {
  const ClientDetailsPage({super.key, required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تفاصيل العميل'),
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
              // Header with client name
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
                      Icons.person,
                      size: 60,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      client.name,
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
              
              // Client details card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Client information
                      _buildDetailItem('الاسم', client.name),
                      const Divider(),
                      _buildDetailItem('الهاتف', client.phone ?? '-'),
                      const Divider(),
                      _buildDetailItem('رقم الهوية', client.nationalId ?? '-'),
                      const Divider(),
                      _buildDetailItem('العنوان', client.address ?? '-'),
                      const Divider(),
                      _buildDetailItem('رقم العميل', client.id.toString()),
                      const Divider(),
                      _buildDetailItem('الائتمان المسموح', '${client.creditLimit.toStringAsFixed(0)} ر.س'),
                      const Divider(),
                      _buildDetailItem('الحالة', client.isFrozen == 0 ? 'نشط' : 'مجمد'),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('عودة'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: open edit dialog/page if you add it
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('تعديل'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final api = context.read<ApiClient>();
                            final rentsRepo = RentsRepository(api);
                            final paymentsRepo = PaymentsRepository(api);

                            final rents = await rentsRepo.list(clientId: client.id);
                            final payments = await paymentsRepo.list(clientId: client.id, showVoided: true);

                            final pdf = PdfService();
                            await pdf.printClientStatement(client: client, rents: rents, payments: payments);
                          },
                          icon: const Icon(Icons.print),
                          label: const Text('طباعة كشف الحساب'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final api = context.read<ApiClient>();
                            final rentsRepo = RentsRepository(api);
                            final paymentsRepo = PaymentsRepository(api);

                            final rents = await rentsRepo.list(clientId: client.id);
                            final payments = await paymentsRepo.list(clientId: client.id, showVoided: true);

                            final pdf = PdfService();
                            await pdf.shareClientStatement(client: client, rents: rents, payments: payments);
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('مشاركة PDF'),
                        ),
                      ),
                    ],
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
}