import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/config/app_config.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/printing/pdf_service.dart';
import 'package:rental_app/features/clients/domain/entities/models.dart';
import 'package:rental_app/features/payments/data/repositories/payments_repository_impl.dart';
import 'package:rental_app/features/rents/data/repositories/rents_repository_impl.dart';

class ClientDetailsPage extends StatefulWidget {
  const ClientDetailsPage({super.key, required this.client});

  final Client client;

  @override
  State<ClientDetailsPage> createState() => _ClientDetailsPageState();
}

class _ClientDetailsPageState extends State<ClientDetailsPage> {
  late Future<List<ClientCollectionFollowup>> _followupsFuture;

  @override
  void initState() {
    super.initState();
    _followupsFuture = _loadFollowups();
  }

  Future<List<ClientCollectionFollowup>> _loadFollowups() async {
    final api = context.read<ApiClient>();
    final res = await api.dio.get('clients/${widget.client.id}/collection-followups');
    dynamic raw = res.data;
    if (raw is Map) raw = raw['data'] ?? raw['items'] ?? raw;
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => ClientCollectionFollowup.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  String _fmtDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final dt = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (dt == null) return raw;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل العميل'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _followupsFuture = _loadFollowups());
          await _followupsFuture;
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      Icon(Icons.person, size: 60, color: Colors.blue.shade700),
                      const SizedBox(height: 12),
                      Text(
                        client.name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
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
                        _buildDetailItem('الائتمان المسموح', '${client.creditLimit.toStringAsFixed(0)} ${AppConfig.currencySymbol}'),
                        const Divider(),
                        _buildDetailItem('الحالة', client.isFrozen == 0 ? 'نشط' : 'مجمد'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<ClientCollectionFollowup>>(
                  future: _followupsFuture,
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? const [];
                    final latest = items.isEmpty ? null : items.first;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text('آخر تواصل أو ملاحظة تحصيل', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                if (snapshot.connectionState == ConnectionState.waiting)
                                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (snapshot.hasError)
                              const Text('تعذر تحميل متابعات التحصيل لهذا العميل')
                            else if (latest == null)
                              const Text('لا توجد متابعات تحصيل مسجلة لهذا العميل حتى الآن')
                            else ...[
                              _buildDetailItem('آخر تواصل', _fmtDateTime(latest.createdAt)),
                              const Divider(),
                              _buildDetailItem('نوع المتابعة', latest.contactTypeLabel),
                              const Divider(),
                              _buildDetailItem('النتيجة', latest.outcomeLabel),
                              const Divider(),
                              _buildDetailItem('العقد', latest.rentNo == null ? '-' : '#${latest.rentNo}'),
                              const Divider(),
                              _buildDetailItem('الموظف', latest.createdByName ?? '-'),
                              const Divider(),
                              _buildDetailItem('الملاحظة', latest.note?.trim().isEmpty ?? true ? '-' : latest.note!.trim()),
                              if (items.length > 1) ...[
                                const Divider(),
                                Text('عدد المتابعات المسجلة: ${items.length}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
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
                            onPressed: () {},
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
                              await pdf.printClientStatement(client: client, rents: rents, payments: payments.items);
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
                              await pdf.shareClientStatement(client: client, rents: rents, payments: payments.items);
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
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class ClientCollectionFollowup {
  const ClientCollectionFollowup({
    required this.id,
    required this.contactType,
    required this.createdAt,
    this.outcome,
    this.note,
    this.rentNo,
    this.createdByName,
  });

  final int id;
  final String contactType;
  final String createdAt;
  final String? outcome;
  final String? note;
  final int? rentNo;
  final String? createdByName;

  factory ClientCollectionFollowup.fromJson(Map<String, dynamic> json) {
    int toI(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    int? toINull(dynamic v) {
      if (v == null) return null;
      final x = toI(v);
      return x == 0 ? null : x;
    }

    return ClientCollectionFollowup(
      id: toI(json['id']),
      contactType: (json['contact_type'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      outcome: json['outcome']?.toString(),
      note: json['note']?.toString(),
      rentNo: toINull(json['rent_no']),
      createdByName: json['created_by_name']?.toString(),
    );
  }

  String get contactTypeLabel {
    switch (contactType.toLowerCase()) {
      case 'call':
        return 'اتصال';
      case 'whatsapp':
        return 'واتساب';
      case 'visit':
        return 'زيارة';
      case 'verbal':
        return 'تذكير شفهي';
      case 'no_answer':
        return 'لم يتم الرد';
      default:
        return contactType.isEmpty ? '-' : contactType;
    }
  }

  String get outcomeLabel {
    switch ((outcome ?? '').toLowerCase()) {
      case 'promise_to_pay':
        return 'وعد بالسداد';
      case 'follow_up_later':
        return 'متابعة لاحقة';
      case 'paid':
        return 'تم التحصيل';
      case 'customer_requested_delay':
        return 'تأجيل بطلب العميل';
      case 'no_answer':
        return 'لا يرد';
      case 'other':
        return 'أخرى';
      default:
        return outcome == null || outcome!.isEmpty ? '-' : outcome!;
    }
  }
}
