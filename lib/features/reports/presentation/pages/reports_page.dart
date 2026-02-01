import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../data/repositories/reports_repository_impl.dart';
import '../../domain/entities/payment_report.dart';
import '../../domain/entities/smart_reports.dart';
import '../bloc/reports_bloc.dart';
import '../bloc/reports_event.dart';
import '../bloc/reports_state.dart';
import '../utils/report_export.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => ReportsRepository(context.read<ApiClient>()),
      child: BlocProvider(
        create: (ctx) => ReportsBloc(ctx.read<ReportsRepository>())
          ..add(const ReportsRefreshAllRequested(revenueGroup: 'day')),
        child: _ReportsTabs(showBackButton: Navigator.canPop(context)),
      ),
    );
  }
}

class _ReportsTabs extends StatefulWidget {
  const _ReportsTabs({required this.showBackButton});
  final bool showBackButton;

  @override
  State<_ReportsTabs> createState() => _ReportsTabsState();
}

class _ReportsTabsState extends State<_ReportsTabs> {
  DateTime? _from;
  DateTime? _to;
  String _revenueGroup = 'day';
  final _fmt = DateFormat('yyyy-MM-dd');

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _to = picked);
  }

  void _apply() {
    final from = _from == null ? null : _fmt.format(_from!);
    final to = _to == null ? null : _fmt.format(_to!);
    context.read<ReportsBloc>().add(
          ReportsRefreshAllRequested(from: from, to: to, revenueGroup: _revenueGroup),
        );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 8,
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'التقارير الذكية',
          onIconPressed: widget.showBackButton ? () => Navigator.pop(context) : null,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _FilterRow(
                    fromLabel: _from == null ? 'من' : _fmt.format(_from!),
                    toLabel: _to == null ? 'إلى' : _fmt.format(_to!),
                    onPickFrom: _pickFrom,
                    onPickTo: _pickTo,
                    onApply: _apply,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('تجميع الإيراد:'),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: _revenueGroup,
                        items: const [
                          DropdownMenuItem(value: 'day', child: Text('يومي')),
                          DropdownMenuItem(value: 'month', child: Text('شهري')),
                          DropdownMenuItem(value: 'year', child: Text('سنوي')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _revenueGroup = v);
                          _apply();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'لوحة التحكم'),
                Tab(text: 'أرباح المعدات'),
                Tab(text: 'الأكثر طلباً'),
                Tab(text: 'أفضل العملاء'),
                Tab(text: 'المتأخرون'),
                Tab(text: 'الإيراد'),
                Tab(text: 'إيراد الموظفين'),
                Tab(text: 'السندات'),
              ],
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: TabBarView(
                children: [
                  _DashboardTab(),
                  _EquipmentProfitTab(),
                  _TopEquipmentTab(),
                  _TopClientsTab(),
                  _LateClientsTab(),
                  _RevenueTab(),
                  _RevenueByUserTab(),
                  _PaymentsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.fromLabel,
    required this.toLabel,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onApply,
  });

  final String fromLabel;
  final String toLabel;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onPickFrom,
            borderRadius: BorderRadius.circular(12),
            child: _DateChip(label: fromLabel, icon: Icons.date_range),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: onPickTo,
            borderRadius: BorderRadius.circular(12),
            child: _DateChip(label: toLabel, icon: Icons.event_available),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.filter_alt),
          label: const Text('تطبيق'),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

// -------------------- DASHBOARD --------------------
class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (p, n) => p.dashboardStatus != n.dashboardStatus || p.dashboard != n.dashboard,
      builder: (context, state) {
        if (state.dashboardStatus == ReportsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.dashboardStatus == ReportsStatus.failure) {
          return _ErrorView(message: state.dashboardError ?? 'حدث خطأ');
        }
        final d = state.dashboard;
        if (d == null) return const Center(child: Text('لا توجد بيانات'));

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _StatTile(title: 'عدد العملاء', value: d.clients.toString(), icon: Icons.people_alt),
            _StatTile(title: 'عدد المعدات', value: d.equipment.toString(), icon: Icons.construction),
            _StatTile(title: 'العقود المفتوحة', value: d.openContracts.toString(), icon: Icons.assignment),
            _StatTile(title: 'إيراد الفترة', value: '${d.revenue.toStringAsFixed(0)} ر.س', icon: Icons.attach_money),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(value, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

// -------------------- EQUIPMENT PROFIT --------------------
class _EquipmentProfitTab extends StatelessWidget {
  const _EquipmentProfitTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (p, n) => p.equipmentProfitStatus != n.equipmentProfitStatus || p.equipmentProfit != n.equipmentProfit,
      builder: (context, state) {
        if (state.equipmentProfitStatus == ReportsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.equipmentProfitStatus == ReportsStatus.failure) {
          return _ErrorView(message: state.equipmentProfitError ?? 'حدث خطأ');
        }
        final rows = state.equipmentProfit;
        if (rows.isEmpty) return const Center(child: Text('لا توجد بيانات'));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final r = rows[i];
            return Card(
              child: ListTile(
                title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('ربح: ${r.profit.toStringAsFixed(0)} | صيانة: ${r.cost.toStringAsFixed(0)}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('الصافي'),
                    Text(
                      r.net.toStringAsFixed(0),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: r.net >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// -------------------- TOP EQUIPMENT --------------------
class _TopEquipmentTab extends StatelessWidget {
  const _TopEquipmentTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (p, n) => p.topEquipmentStatus != n.topEquipmentStatus || p.topEquipment != n.topEquipment,
      builder: (context, state) {
        if (state.topEquipmentStatus == ReportsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.topEquipmentStatus == ReportsStatus.failure) {
          return _ErrorView(message: state.topEquipmentError ?? 'حدث خطأ');
        }
        final rows = state.topEquipment;
        if (rows.isEmpty) return const Center(child: Text('لا توجد بيانات'));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final r = rows[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('عدد مرات التأجير: ${r.rentalsCount}'),
              ),
            );
          },
        );
      },
    );
  }
}

// -------------------- TOP CLIENTS --------------------
class _TopClientsTab extends StatelessWidget {
  const _TopClientsTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (p, n) => p.topClientsStatus != n.topClientsStatus || p.topClients != n.topClients,
      builder: (context, state) {
        if (state.topClientsStatus == ReportsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.topClientsStatus == ReportsStatus.failure) {
          return _ErrorView(message: state.topClientsError ?? 'حدث خطأ');
        }
        final rows = state.topClients;
        if (rows.isEmpty) return const Center(child: Text('لا توجد بيانات'));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final r = rows[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('عدد العقود: ${r.contractsCount}'),
                trailing: Text('${r.totalAmount.toStringAsFixed(0)} ر.س'),
              ),
            );
          },
        );
      },
    );
  }
}

// -------------------- LATE CLIENTS --------------------
class _LateClientsTab extends StatelessWidget {
  const _LateClientsTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (p, n) => p.lateClientsStatus != n.lateClientsStatus || p.lateClients != n.lateClients,
      builder: (context, state) {
        if (state.lateClientsStatus == ReportsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.lateClientsStatus == ReportsStatus.failure) {
          return _ErrorView(message: state.lateClientsError ?? 'حدث خطأ');
        }
        final rows = state.lateClients;
        if (rows.isEmpty) return const Center(child: Text('لا توجد بيانات'));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final r = rows[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('عدد مرات التأخير: ${r.lateContractsCount}'),
              ),
            );
          },
        );
      },
    );
  }
}

// -------------------- REVENUE --------------------
class _RevenueTab extends StatelessWidget {
  const _RevenueTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (p, n) => p.revenueStatus != n.revenueStatus || p.revenue != n.revenue || p.revenueGroup != n.revenueGroup,
      builder: (context, state) {
        if (state.revenueStatus == ReportsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.revenueStatus == ReportsStatus.failure) {
          return _ErrorView(message: state.revenueError ?? 'حدث خطأ');
        }
        final rows = state.revenue;
        if (rows.isEmpty) return const Center(child: Text('لا توجد بيانات'));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final r = rows[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(r.period, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text('${r.revenue.toStringAsFixed(0)} ر.س'),
              ),
            );
          },
        );
      },
    );
  }
}

// -------------------- REVENUE BY USER --------------------
class _RevenueByUserTab extends StatelessWidget {
  const _RevenueByUserTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (p, n) => p.revenueByUserStatus != n.revenueByUserStatus || p.revenueByUser != n.revenueByUser,
      builder: (context, state) {
        if (state.revenueByUserStatus == ReportsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.revenueByUserStatus == ReportsStatus.failure) {
          return _ErrorView(message: state.revenueByUserError ?? 'حدث خطأ');
        }
        final rows = state.revenueByUser;
        if (rows.isEmpty) return const Center(child: Text('لا توجد بيانات'));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final r = rows[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(r.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('سندات قبض: ${r.receiptsCount}'),
                trailing: Text('${r.revenue.toStringAsFixed(0)} ر.س'),
              ),
            );
          },
        );
      },
    );
  }
}

// -------------------- PAYMENTS (VOUCHERS) --------------------
class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (p, n) => p.paymentsStatus != n.paymentsStatus || p.payments != n.payments,
      builder: (context, state) {
        if (state.paymentsStatus == ReportsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.paymentsStatus == ReportsStatus.failure) {
          return _ErrorView(message: state.paymentsError ?? 'حدث خطأ');
        }
        final report = state.payments;
        if (report == null) return const Center(child: Text('لا توجد بيانات'));

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _TotalsCard(report: report),
            const SizedBox(height: 10),
            _ExportBar(report: report),
            const SizedBox(height: 10),
            ...report.rows.map((r) => _PaymentRowTile(row: r)),
            if (report.rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: Text('لا توجد عمليات ضمن النطاق')),
              ),
          ],
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
            Text('ملخص السندات', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _MiniStat(label: 'دخل', value: report.totals.totalIn.toStringAsFixed(2))),
                const SizedBox(width: 8),
                Expanded(child: _MiniStat(label: 'صرف', value: report.totals.totalOut.toStringAsFixed(2))),
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
                        Text(report.totals.net.toStringAsFixed(2), style: Theme.of(context).textTheme.titleLarge),
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
                fileName: 'vouchers_report.csv',
                mime: 'text/csv',
                content: csv,
              );
            },
            icon: const Icon(Icons.table_view),
            label: const Text('CSV'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final pdf = await ReportExport.toPaymentsPdf(report);
              await ReportExport.shareBytesAsFile(
                fileName: 'vouchers_report.pdf',
                mime: 'application/pdf',
                bytes: pdf,
              );
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('PDF'),
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
        leading: CircleAvatar(child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward)),
        title: Text('${row.amount.toStringAsFixed(2)}  (${isIn ? 'قبض' : 'صرف'})'),
        subtitle: Text('${row.clientName ?? '-'} • ${row.createdAt}'),
        trailing: row.rentNo != null ? Text('#${row.rentNo}') : null,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.read<ReportsBloc>().add(const ReportsRefreshAllRequested(revenueGroup: 'day')),
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث'),
            ),
          ],
        ),
      ),
    );
  }
}
