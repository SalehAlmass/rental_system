import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/features/reports/data/repositories/payments_report_repository.dart';
import 'package:rental_app/features/reports/presentation/bloc/payments_report_cubit.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dio = context.read<ApiClient>().dio;

    return BlocProvider(
      create: (_) => PaymentsReportCubit(PaymentsReportRepository(dio))..load(),
      child: const _PaymentsReportView(),
    );
  }
}

class _PaymentsReportView extends StatefulWidget {
  const _PaymentsReportView();

  @override
  State<_PaymentsReportView> createState() => _PaymentsReportViewState();
}

class _PaymentsReportViewState extends State<_PaymentsReportView> {
  DateTimeRange? _range;

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
    );

    if (picked == null) return;

    setState(() => _range = picked);

    final cubit = context.read<PaymentsReportCubit>();
    cubit.setFilter(from: _ymd(picked.start), to: _ymd(picked.end));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التقارير المالية'),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
              onPressed: () => context.read<PaymentsReportCubit>().load(),
            ),
          ],
        ),
        body: BlocBuilder<PaymentsReportCubit, PaymentsReportState>(
          builder: (context, state) {
            final cubit = context.read<PaymentsReportCubit>();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _FilterCard(
                  rangeText: _range == null
                      ? 'اختر الفترة'
                      : '${_ymd(_range!.start)}  →  ${_ymd(_range!.end)}',
                  type: cubit.type,
                  onPickRange: () => _pickRange(context),
                  onTypeChanged: (v) {
                    cubit.setFilter(type: v);
                    setState(() {}); // فقط لتحديث UI النصي
                  },
                  onApply: () => cubit.load(),
                  onClear: () {
                    setState(() => _range = null);
                    cubit.clearFilter();
                    cubit.load();
                  },
                  onExportCsv: () {
                    final from = cubit.from;
                    final to = cubit.to;
                    final type = cubit.type;

                    // ملاحظة:
                    // هذا يعتمد على إعداد baseUrl عندك (هل تستخدم ?path= أم لا)
                    // إذا baseUrl عندك فيه ?path= مسبقًا: استخدم 'reports/payments.csv'
                    // وإلا: استخدم '/?path=reports/payments.csv'
                    //
                    // أسهل حل: استخدم نفس dio.baseUrl كنص:
                    final base = context.read<ApiClient>().dio.options.baseUrl;

                    // محاولة ذكية لبناء الرابط
                    // إذا baseUrl يحتوي ?path= نكتفي بإضافة endpoint مباشرة
                    final url = base.contains('?path=')
                        ? '${base}reports/payments.csv'
                        : '$base/?path=reports/payments.csv';

                    final qs = <String, String>{
                      if (from != null) 'from': from,
                      if (to != null) 'to': to,
                      'type': type,
                      'include_void': '0',
                    };

                    final full = Uri.parse(url).replace(queryParameters: qs).toString();

                    // يفتح المتصفح/تبويب (يعمل على web + mobile إذا عندك url_launcher)
                    // إذا ما عندك url_launcher قلّي وأعطيك إضافة جاهزة.
                    _showCopyLinkDialog(context, full);
                  },
                ),

                const SizedBox(height: 16),

                if (state is PaymentsReportLoading) ...[
                  const Center(child: CircularProgressIndicator()),
                ] else if (state is PaymentsReportError) ...[
                  _ErrorBox(
                    message: state.message,
                    onRetry: () => context.read<PaymentsReportCubit>().load(),
                  ),
                ] else if (state is PaymentsReportLoaded) ...[
                  _TotalsCard(totals: state.totals),
                  const SizedBox(height: 16),
                  _RowsTable(rows: state.rows),
                ] else ...[
                  const SizedBox.shrink(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static void _showCopyLinkDialog(BuildContext context, String link) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('رابط تصدير CSV'),
        content: SelectableText(link),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  final String rangeText;
  final String type;
  final VoidCallback onPickRange;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final VoidCallback onExportCsv;

  const _FilterCard({
    required this.rangeText,
    required this.type,
    required this.onPickRange,
    required this.onTypeChanged,
    required this.onApply,
    required this.onClear,
    required this.onExportCsv,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('فلترة التقرير', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(rangeText),
                    onPressed: onPickRange,
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('الكل')),
                    DropdownMenuItem(value: 'in', child: Text('قبض')),
                    DropdownMenuItem(value: 'out', child: Text('صرف')),
                  ],
                  onChanged: (v) => onTypeChanged(v ?? 'all'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.filter_alt),
                  label: const Text('تطبيق'),
                  onPressed: onApply,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('مسح'),
                  onPressed: onClear,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('تصدير CSV'),
                  onPressed: onExportCsv,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final Map<String, dynamic> totals;
  const _TotalsCard({required this.totals});

  @override
  Widget build(BuildContext context) {
    final tin = (totals['in'] ?? 0).toString();
    final tout = (totals['out'] ?? 0).toString();
    final net = (totals['net'] ?? 0).toString();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('ملخص', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _kpi('إجمالي القبض', tin)),
                const SizedBox(width: 10),
                Expanded(child: _kpi('إجمالي الصرف', tout)),
                const SizedBox(width: 10),
                Expanded(child: _kpi('الصافي', net)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _RowsTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _RowsTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('لا توجد بيانات ضمن هذه الفترة'));
    }

    // عشان الجوال والويب: Scroll أفقي/عمودي
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, c) {
            final tableMinWidth = max(900.0, c.maxWidth);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: tableMinWidth),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('التاريخ')),
                    DataColumn(label: Text('النوع')),
                    DataColumn(label: Text('المبلغ')),
                    DataColumn(label: Text('الطريقة')),
                    DataColumn(label: Text('العميل')),
                    DataColumn(label: Text('العقد')),
                    DataColumn(label: Text('المرجع')),
                  ],
                  rows: rows.map((r) {
                    final id = (r['id'] ?? '').toString();
                    final createdAt = (r['created_at'] ?? '').toString();
                    final type = (r['type'] ?? '').toString();
                    final amount = (r['amount'] ?? '').toString();
                    final method = (r['method'] ?? '').toString();
                    final client = (r['client_name'] ?? '').toString();
                    final rentNo = (r['rent_no'] ?? '').toString();
                    final ref = (r['reference_no'] ?? '').toString();

                    return DataRow(
                      cells: [
                        DataCell(Text(id)),
                        DataCell(Text(createdAt)),
                        DataCell(Text(type == 'in' ? 'قبض' : (type == 'out' ? 'صرف' : type))),
                        DataCell(Text(amount)),
                        DataCell(Text(method)),
                        DataCell(Text(client)),
                        DataCell(Text(rentNo)),
                        DataCell(Text(ref)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 46),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
