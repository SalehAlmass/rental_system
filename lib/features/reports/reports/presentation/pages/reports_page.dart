import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/features/reports/data/repositories/reports_repository_impl.dart';
import 'package:rental_app/features/reports/domain/entities/payment_report.dart';
import 'package:rental_app/features/reports/presentation/utils/report_export.dart';
import '../bloc/reports_bloc.dart';
import '../bloc/reports_event.dart';
import '../bloc/reports_state.dart';


class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => ReportsRepository(context.read<ApiClient>()),
      child: BlocProvider(
        create: (ctx) => ReportsBloc(ctx.read<ReportsRepository>())
          ..add(const ReportsDashboardRequested()),
        child: _ReportsView(
          showBackButton: Navigator.canPop(context),
        ),
      ),
    );
  }
}

class _ReportsView extends StatefulWidget {
  const _ReportsView({this.showBackButton = true});

  final bool showBackButton;

  @override
  State<_ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<_ReportsView> {
  DateTime? _from;
  DateTime? _to;
  final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _to = picked);
  }

  void _applyFilter() {
    final from = _from != null ? _dateFormat.format(_from!) : null;
    final to = _to != null ? _dateFormat.format(_to!) : null;
    context.read<ReportsBloc>().add(ReportsDashboardRequested(from: from, to: to));
    context.read<ReportsBloc>().add(ReportsPaymentsRequested(from: from, to: to));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'التقارير',
          onIconPressed: widget.showBackButton ? () => Navigator.of(context).pop() : null,
          actions: const [
            SizedBox(width: 8),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildFilterRow(),
              const SizedBox(height: 12),
              const TabBar(
                tabs: [
                  Tab(text: 'ملخص'),
                  Tab(text: 'المدفوعات'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    _DashboardSummary(onRefresh: _applyFilter),
                    _PaymentsReport(
                      dateFormat: _dateFormat,
                      from: _from,
                      to: _to,
                      onRefresh: _applyFilter,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _pickFromDate,
            child: _DateChip(label: _from != null ? _dateFormat.format(_from!) : 'من التاريخ'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: _pickToDate,
            child: _DateChip(label: _to != null ? _dateFormat.format(_to!) : 'إلى التاريخ'),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _applyFilter,
          icon: const Icon(Icons.filter_alt),
          label: const Text('تطبيق'),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.date_range, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSummary extends StatelessWidget {
  const _DashboardSummary({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      builder: (context, state) {
        if (state.dashboardStatus == ReportsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.dashboardStatus == ReportsStatus.failure) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.dashboardError ?? 'حدث خطأ'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onRefresh,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }

        final d = state.dashboard;
        if (d == null) return const Center(child: Text('لا توجد بيانات'));

        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView(
            children: [
              _ReportTile(title: 'عدد العملاء', value: d.clients.toString(), icon: Icons.people),
              _ReportTile(title: 'عدد المعدات', value: d.equipment.toString(), icon: Icons.construction),
              _ReportTile(title: 'العقود المفتوحة', value: d.openContracts.toString(), icon: Icons.assignment),
              _ReportTile(title: 'الإيرادات', value: '${d.revenue.toStringAsFixed(0)} ر.س', icon: Icons.attach_money),
            ],
          ),
        );
      },
    );
  }
}

class _PaymentsReport extends StatelessWidget {
  const _PaymentsReport({
    required this.dateFormat,
    required this.from,
    required this.to,
    required this.onRefresh,
  });

  final DateFormat dateFormat;
  final DateTime? from;
  final DateTime? to;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      builder: (context, state) {
        if (state.paymentsStatus == ReportsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.paymentsStatus == ReportsStatus.failure) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.paymentsError ?? 'حدث خطأ'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onRefresh,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }

        final report = state.payments;
        if (report == null) {
          return const Center(child: Text('لا توجد بيانات'));
        }

        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView(
            children: [
              _TotalsCard(report: report),
              const SizedBox(height: 12),
              _ExportBar(report: report),
              const SizedBox(height: 12),
              ...report.rows.map((r) => _PaymentRowTile(row: r)),
              if (report.rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(child: Text('لا توجد عمليات ضمن النطاق')),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.report});

  final PaymentsReport report;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ملخص المدفوعات', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _MiniStat(label: 'إيرادات', value: report.totals.totalIn.toStringAsFixed(2))),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat(label: 'مصروفات', value: report.totals.totalOut.toStringAsFixed(2))),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الصافي', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 6),
                        Text(
                          report.totals.net.toStringAsFixed(2),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ExportBar extends StatelessWidget {
  const _ExportBar({required this.report});

  final PaymentsReport report;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final csv = ReportExport.toPaymentsCsv(report);
              await ReportExport.shareTextAsFile(
                fileName: 'payments_report.csv',
                mime: 'text/csv',
                content: csv,
              );
            },
            icon: const Icon(Icons.table_view),
            label: const Text('تصدير CSV'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final pdf = await ReportExport.toPaymentsPdf(report);
              await ReportExport.shareBytesAsFile(
                fileName: 'payments_report.pdf',
                mime: 'application/pdf',
                bytes: pdf,
              );
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('تصدير PDF'),
          ),
        ),
      ],
    );
  }
}

class _PaymentRowTile extends StatelessWidget {
  const _PaymentRowTile({required this.row});

  final PaymentReportRow row;

  @override
  Widget build(BuildContext context) {
    final isIn = row.type == 'in';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward),
        ),
        title: Text('${row.amount.toStringAsFixed(2)}  (${isIn ? 'دخل' : 'صرف'})'),
        subtitle: Text('${row.clientName ?? '-'} • ${row.createdAt}'),
        trailing: row.rentNo != null ? Text('#${row.rentNo}') : null,
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(value, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
