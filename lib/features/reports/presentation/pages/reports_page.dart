import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../data/repositories/reports_repository_impl.dart';
import '../../domain/entities/financial_reports.dart';
import '../../domain/entities/payment_report.dart';
import '../../domain/entities/smart_reports.dart';
import '../bloc/reports_bloc.dart';
import '../bloc/reports_event.dart';
import '../bloc/reports_state.dart';
import '../utils/report_export.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Entry
// ─────────────────────────────────────────────────────────────────────────────
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => ReportsRepository(context.read<ApiClient>()),
      child: BlocProvider(
        create: (ctx) =>
            ReportsBloc(ctx.read<ReportsRepository>())
              ..add(const ReportsRefreshAllRequested(revenueGroup: 'month')),
        child: _ReportsTabs(showBackButton: Navigator.canPop(context)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tabs Shell
// ─────────────────────────────────────────────────────────────────────────────
class _ReportsTabs extends StatefulWidget {
  const _ReportsTabs({required this.showBackButton});
  final bool showBackButton;

  @override
  State<_ReportsTabs> createState() => _ReportsTabsState();
}

class _ReportsTabsState extends State<_ReportsTabs> with SingleTickerProviderStateMixin {
  DateTime? _from;
  DateTime? _to;
  String _revenueGroup = 'month';
  final _fmt = DateFormat('yyyy-MM-dd');
  late TabController _tabController;

  // Tab indices
  static const _tabCount = 12;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        title: const Text('التقارير المالية'),
        automaticallyImplyLeading: widget.showBackButton,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(88),
          child: Column(
            children: [
              // Date filter row
              Container(
                color: const Color(0xFF1A1D2E),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: _DateBtn(label: _from == null ? 'من تاريخ' : _fmt.format(_from!), onTap: _pickFrom)),
                    const SizedBox(width: 8),
                    Expanded(child: _DateBtn(label: _to == null ? 'إلى تاريخ' : _fmt.format(_to!), onTap: _pickTo)),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('تطبيق', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
              // Tab bar
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: const Color(0xFF6C63FF),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF6C63FF),
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: 'الملخص المالي'),
                  Tab(text: 'الأرباح والخسائر'),
                  Tab(text: 'التدفقات النقدية'),
                  Tab(text: 'أرباح المعدات'),
                  Tab(text: 'أداء الموظفين'),
                  Tab(text: 'الإيرادات بالمستخدم'),
                  Tab(text: 'الإيرادات'),
                  Tab(text: 'السندات'),
                  Tab(text: 'أفضل معدات'),
                  Tab(text: 'أفضل عملاء'),
                  Tab(text: 'المتأخرون'),
                  Tab(text: 'الإيرادات بالموظف'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FinancialSummaryTab(from: _from == null ? null : _fmt.format(_from!), to: _to == null ? null : _fmt.format(_to!)),
          _ProfitLossTab(from: _from == null ? null : _fmt.format(_from!), to: _to == null ? null : _fmt.format(_to!)),
          _CashFlowTab(from: _from == null ? null : _fmt.format(_from!), to: _to == null ? null : _fmt.format(_to!)),
          _EquipmentProfitTab(from: _from == null ? null : _fmt.format(_from!), to: _to == null ? null : _fmt.format(_to!)),
          _EmployeePerformanceTab(from: _from == null ? null : _fmt.format(_from!), to: _to == null ? null : _fmt.format(_to!)),
          _RevenueByUserSummaryTab(from: _from == null ? null : _fmt.format(_from!), to: _to == null ? null : _fmt.format(_to!)),
          _RevenueTrendTab(from: _from == null ? null : _fmt.format(_from!), to: _to == null ? null : _fmt.format(_to!)),
          _PaymentsTab(from: _from == null ? null : _fmt.format(_from!), to: _to == null ? null : _fmt.format(_to!)),
          _TopEquipmentTab(),
          _TopClientsTab(),
          _LateClientsTab(),
          _RevenueByUserTab(from: _from == null ? null : _fmt.format(_from!), to: _to == null ? null : _fmt.format(_to!)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────
final _numFmt = NumberFormat('#,##0.00', 'ar');
String _fmtAmt(double v) => '${_numFmt.format(v)} ر.س';
String _fmtN(double v) => _numFmt.format(v);
String _fmtPct(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}%';

Color _profitColor(double v) => v >= 0 ? const Color(0xFF00E676) : const Color(0xFFFF5252);

Widget _kpiCard({
  required String label,
  required String value,
  Color? valueColor,
  IconData? icon,
  Color? iconBg,
}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [const Color(0xFF1E2035), const Color(0xFF252840)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg ?? const Color(0xFF6C63FF33),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconBg != null ? Colors.white : const Color(0xFF6C63FF)),
              ),
            if (icon != null) const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

Widget _sectionHeader(String title, {Widget? action}) {
  return Row(
    children: [
      Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFF6C63FF), borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Expanded(
        child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      if (action != null) action,
    ],
  );
}

Widget _loadingBox() => const Center(child: Padding(
  padding: EdgeInsets.all(40),
  child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
));

Widget _errorBox(String msg) => Center(
  child: Padding(
    padding: const EdgeInsets.all(20),
    child: Text(msg, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
  ),
);

class _DateBtn extends StatelessWidget {
  const _DateBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF252840),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 14, color: Color(0xFF6C63FF)),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  1. FINANCIAL SUMMARY TAB
// ─────────────────────────────────────────────────────────────────────────────
class _FinancialSummaryTab extends StatelessWidget {
  const _FinancialSummaryTab({this.from, this.to});
  final String? from;
  final String? to;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (a, b) =>
          a.financialSummaryStatus != b.financialSummaryStatus ||
          a.financialSummary != b.financialSummary,
      builder: (context, state) {
        if (state.financialSummaryStatus == ReportsStatus.loading) return _loadingBox();
        if (state.financialSummaryStatus == ReportsStatus.failure) return _errorBox(state.financialSummaryError ?? 'خطأ');

        final d = state.financialSummary;
        if (d == null) return _loadingBox();

        final expenses = [
          d.maintenanceExpenses,
          d.payrollExpenses,
          d.depreciationExpenses,
          d.operationalExpenses,
        ];
        final expTotal = expenses.fold<double>(0, (a, b) => a + b);
        final sections = expTotal > 0
            ? [
                PieChartSectionData(value: d.maintenanceExpenses, color: const Color(0xFFFF9800), title: 'صيانة', radius: 55, titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
                PieChartSectionData(value: d.payrollExpenses, color: const Color(0xFF6C63FF), title: 'رواتب', radius: 55, titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
                PieChartSectionData(value: d.depreciationExpenses, color: const Color(0xFF00BCD4), title: 'استهلاك', radius: 55, titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
                PieChartSectionData(value: d.operationalExpenses, color: const Color(0xFFE91E63), title: 'تشغيل', radius: 55, titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
              ]
            : [PieChartSectionData(value: 1, color: Colors.white12, title: 'لا يوجد', radius: 55, titleStyle: const TextStyle(fontSize: 10, color: Colors.white60))];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // KPI Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.55,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _kpiCard(label: 'إجمالي الإيرادات', value: _fmtAmt(d.totalRevenue), icon: Icons.arrow_upward, iconBg: const Color(0xFF00C853)),
                _kpiCard(label: 'إجمالي المصروفات', value: _fmtAmt(d.totalExpenses), icon: Icons.arrow_downward, iconBg: const Color(0xFFFF5252)),
                _kpiCard(label: 'صافي الربح', value: _fmtAmt(d.netProfit), valueColor: _profitColor(d.netProfit), icon: Icons.trending_up, iconBg: _profitColor(d.netProfit).withOpacity(0.9)),
                _kpiCard(label: 'هامش الربح', value: _fmtPct(d.profitMarginPct), icon: Icons.percent),
                _kpiCard(label: 'مستحقات غير مسددة', value: _fmtAmt(d.outstandingAmount), icon: Icons.schedule, iconBg: const Color(0xFFFF9800)),
                _kpiCard(label: 'قيمة الأصول الإجمالية', value: _fmtAmt(d.totalAssetValue), icon: Icons.business, iconBg: const Color(0xFF6C63FF)),
              ],
            ),
            const SizedBox(height: 20),

            // Revenue breakdown
            _sectionHeader('تفاصيل الإيرادات'),
            const SizedBox(height: 12),
            _RowLine(label: 'إيرادات الإيجار', value: _fmtAmt(d.rentalRevenue), color: const Color(0xFF00C853)),
            _RowLine(label: 'إيرادات أخرى', value: _fmtAmt(d.otherRevenue), color: const Color(0xFF69F0AE)),
            _RowLine(label: 'إجمالي الإيرادات', value: _fmtAmt(d.totalRevenue), color: Colors.white, bold: true),
            const SizedBox(height: 20),

            // Profit breakdown
            _sectionHeader('مؤشرات الربحية'),
            const SizedBox(height: 12),
            _RowLine(label: 'الربح الإجمالي', value: _fmtAmt(d.grossProfit), color: _profitColor(d.grossProfit)),
            _RowLine(label: 'الربح التشغيلي', value: _fmtAmt(d.operatingProfit), color: _profitColor(d.operatingProfit)),
            _RowLine(label: 'صافي الربح', value: _fmtAmt(d.netProfit), color: _profitColor(d.netProfit), bold: true),
            const SizedBox(height: 20),

            // Expense pie chart
            _sectionHeader('توزيع المصروفات'),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _Legend(color: const Color(0xFFFF9800), label: 'صيانة ${_fmtPct(expTotal > 0 ? (d.maintenanceExpenses / expTotal * 100) : null)}'),
                _Legend(color: const Color(0xFF6C63FF), label: 'رواتب ${_fmtPct(expTotal > 0 ? (d.payrollExpenses / expTotal * 100) : null)}'),
                _Legend(color: const Color(0xFF00BCD4), label: 'استهلاك ${_fmtPct(expTotal > 0 ? (d.depreciationExpenses / expTotal * 100) : null)}'),
                _Legend(color: const Color(0xFFE91E63), label: 'تشغيل ${_fmtPct(expTotal > 0 ? (d.operationalExpenses / expTotal * 100) : null)}'),
              ],
            ),
            const SizedBox(height: 20),

            // Export button
            _ExportBtn(
              label: 'تصدير الملخص المالي PDF',
              onTap: () => ReportExport.exportFinancialSummary(context, d, from: from, to: to),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  2. PROFIT & LOSS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _ProfitLossTab extends StatelessWidget {
  const _ProfitLossTab({this.from, this.to});
  final String? from;
  final String? to;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (a, b) => a.profitLossStatus != b.profitLossStatus || a.profitLoss != b.profitLoss,
      builder: (context, state) {
        if (state.profitLossStatus == ReportsStatus.loading) return _loadingBox();
        if (state.profitLossStatus == ReportsStatus.failure) return _errorBox(state.profitLossError ?? 'خطأ');
        final d = state.profitLoss;
        if (d == null) return _loadingBox();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PLSection(title: 'الإيرادات', color: const Color(0xFF00C853), rows: [
              _PLRow('إيرادات الإيجار', d.rentalRevenue),
              _PLRow('إيرادات أخرى', d.otherRevenue),
              _PLRow('إجمالي الإيرادات', d.totalRevenue, bold: true),
            ]),
            const SizedBox(height: 16),
            _PLSection(title: 'تكلفة الإيرادات', color: const Color(0xFFFF9800), rows: [
              _PLRow('الصيانة', d.maintenanceCost),
              _PLRow('الاستهلاك', d.depreciationCost),
              _PLRow('إجمالي تكلفة الإيرادات', d.totalCost, bold: true),
            ]),
            const SizedBox(height: 12),
            _PLSummaryLine(label: 'الربح الإجمالي', value: d.grossProfit),
            const SizedBox(height: 16),
            _PLSection(title: 'المصروفات التشغيلية', color: const Color(0xFF6C63FF), rows: [
              _PLRow('الرواتب والأجور', d.payrollExpense),
              _PLRow('مصروفات أخرى', d.otherExpenses),
              _PLRow('إجمالي المصروفات التشغيلية', d.totalOperating, bold: true),
            ]),
            const SizedBox(height: 12),
            _PLSummaryLine(label: 'صافي الربح', value: d.netProfit, big: true),
            const SizedBox(height: 20),
            _ExportBtn(
              label: 'تصدير قائمة الأرباح والخسائر PDF',
              onTap: () => ReportExport.exportProfitLoss(context, d, from: from, to: to),
            ),
          ],
        );
      },
    );
  }
}

class _PLSection extends StatelessWidget {
  const _PLSection({required this.title, required this.color, required this.rows});
  final String title;
  final Color color;
  final List<_PLRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
          ...rows.map((r) => r.build(context)).toList(),
        ],
      ),
    );
  }
}

class _PLRow {
  const _PLRow(this.label, this.value, {this.bold = false});
  final String label;
  final double value;
  final bool bold;

  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: bold ? Colors.white : Colors.white70, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(_fmtAmt(value), style: TextStyle(color: _profitColor(value), fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _PLSummaryLine extends StatelessWidget {
  const _PLSummaryLine({required this.label, required this.value, this.big = false});
  final String label;
  final double value;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _profitColor(value).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _profitColor(value).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white, fontSize: big ? 16 : 14, fontWeight: FontWeight.bold)),
          Text(_fmtAmt(value), style: TextStyle(color: _profitColor(value), fontSize: big ? 18 : 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  3. CASH FLOW TAB
// ─────────────────────────────────────────────────────────────────────────────
class _CashFlowTab extends StatelessWidget {
  const _CashFlowTab({this.from, this.to});
  final String? from;
  final String? to;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (a, b) => a.cashFlowStatus != b.cashFlowStatus || a.cashFlow != b.cashFlow,
      builder: (context, state) {
        if (state.cashFlowStatus == ReportsStatus.loading) return _loadingBox();
        if (state.cashFlowStatus == ReportsStatus.failure) return _errorBox(state.cashFlowError ?? 'خطأ');
        final d = state.cashFlow;
        if (d == null) return _loadingBox();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Balance flow cards
            _CashFlowCard(label: 'الرصيد الافتتاحي', value: d.openingBalance, icon: Icons.account_balance_wallet, color: const Color(0xFF6C63FF)),
            const SizedBox(height: 10),
            _CashInSection(d),
            const SizedBox(height: 10),
            _CashOutSection(d),
            const SizedBox(height: 10),
            _CashFlowCard(label: 'صافي الحركة', value: d.netMovement, icon: Icons.swap_vert, color: _profitColor(d.netMovement)),
            const SizedBox(height: 10),
            _CashFlowCard(label: 'الرصيد الختامي', value: d.closingBalance, icon: Icons.account_balance, color: _profitColor(d.closingBalance), big: true),
            const SizedBox(height: 20),
            _ExportBtn(
              label: 'تصدير التدفقات النقدية PDF',
              onTap: () => ReportExport.exportCashFlow(context, d, from: from, to: to),
            ),
          ],
        );
      },
    );
  }
}

class _CashFlowCard extends StatelessWidget {
  const _CashFlowCard({required this.label, required this.value, required this.icon, required this.color, this.big = false});
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF1A1D2E), const Color(0xFF252840)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: big ? 24 : 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.white60, fontSize: big ? 14 : 12)),
              Text(_fmtAmt(value), style: TextStyle(color: color, fontSize: big ? 22 : 17, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CashInSection extends StatelessWidget {
  const _CashInSection(this.d);
  final CashFlow d;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1A1D2E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(color: Color(0xFF00C85333), borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
            child: Row(children: [const Icon(Icons.arrow_downward, color: Color(0xFF00C853), size: 16), const SizedBox(width: 6), const Text('التدفقات الداخلة', style: TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold))]),
          ),
          _RowLine(label: 'نقداً', value: _fmtAmt(d.cashIn), color: const Color(0xFF69F0AE)),
          _RowLine(label: 'تحويل بنكي', value: _fmtAmt(d.transferIn), color: const Color(0xFF69F0AE)),
          _RowLine(label: 'إجمالي التدفقات الداخلة', value: _fmtAmt(d.totalCashIn), color: const Color(0xFF00C853), bold: true),
        ],
      ),
    );
  }
}

class _CashOutSection extends StatelessWidget {
  const _CashOutSection(this.d);
  final CashFlow d;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1A1D2E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(color: Color(0xFFFF525233), borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
            child: Row(children: [const Icon(Icons.arrow_upward, color: Color(0xFFFF5252), size: 16), const SizedBox(width: 6), const Text('التدفقات الخارجة', style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold))]),
          ),
          _RowLine(label: 'نقداً', value: _fmtAmt(d.cashOut), color: const Color(0xFFFF8A80)),
          _RowLine(label: 'تحويل بنكي', value: _fmtAmt(d.transferOut), color: const Color(0xFFFF8A80)),
          _RowLine(label: 'صيانة', value: _fmtAmt(d.maintenanceCashOut), color: const Color(0xFFFF9800)),
          _RowLine(label: 'إجمالي التدفقات الخارجة', value: _fmtAmt(d.totalCashOut), color: const Color(0xFFFF5252), bold: true),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  4. EQUIPMENT PROFITABILITY TAB
// ─────────────────────────────────────────────────────────────────────────────
class _EquipmentProfitTab extends StatelessWidget {
  const _EquipmentProfitTab({this.from, this.to});
  final String? from;
  final String? to;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (a, b) => a.equipmentProfitV2Status != b.equipmentProfitV2Status || a.equipmentProfitV2 != b.equipmentProfitV2,
      builder: (context, state) {
        if (state.equipmentProfitV2Status == ReportsStatus.loading) return _loadingBox();
        if (state.equipmentProfitV2Status == ReportsStatus.failure) return _errorBox(state.equipmentProfitV2Error ?? 'خطأ');
        final rows = state.equipmentProfitV2;
        if (rows.isEmpty) return const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white60)));

        return Column(
          children: [
            // Top equipment ROI bar chart
            if (rows.isNotEmpty)
              Container(
                height: 200,
                padding: const EdgeInsets.all(12),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: rows.map((r) => r.rentalRevenue).fold<double>(0, (a, b) => a > b ? a : b) * 1.2,
                    barGroups: rows.take(6).toList().asMap().entries.map((e) {
                      return BarChartGroupData(x: e.key, barRods: [
                        BarChartRodData(toY: e.value.rentalRevenue, color: const Color(0xFF6C63FF), width: 18, borderRadius: BorderRadius.circular(4)),
                        BarChartRodData(toY: e.value.netProfit, color: _profitColor(e.value.netProfit), width: 18, borderRadius: BorderRadius.circular(4)),
                      ]);
                    }).toList(),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
                        final i = v.toInt();
                        if (i < 0 || i >= rows.length) return const SizedBox();
                        return Padding(padding: const EdgeInsets.only(top: 4), child: Text(rows[i].name.length > 8 ? rows[i].name.substring(0, 8) : rows[i].name, style: const TextStyle(color: Colors.white60, fontSize: 9)));
                      })),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = rows[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1D2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(r.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            if (r.roiPct != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: _profitColor(r.roiPct!).withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                                child: Text('العائد: ${_fmtPct(r.roiPct)}', style: TextStyle(color: _profitColor(r.roiPct!), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            _MiniStat('إيرادات الإيجار', _fmtAmt(r.rentalRevenue), const Color(0xFF00C853)),
                            _MiniStat('أيام الإيجار', '${r.rentalDays.toStringAsFixed(0)} يوم', const Color(0xFF6C63FF)),
                            _MiniStat('تكلفة الصيانة', _fmtAmt(r.maintenanceCost), const Color(0xFFFF9800)),
                            _MiniStat('استهلاك محاسبي', _fmtAmt(r.accountingDepreciation), const Color(0xFF00BCD4)),
                            _MiniStat('صافي الربح', _fmtAmt(r.netProfit), _profitColor(r.netProfit)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  5. EMPLOYEE PERFORMANCE TAB
// ─────────────────────────────────────────────────────────────────────────────
class _EmployeePerformanceTab extends StatelessWidget {
  const _EmployeePerformanceTab({this.from, this.to});
  final String? from;
  final String? to;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (a, b) => a.employeePerformanceStatus != b.employeePerformanceStatus || a.employeePerformance != b.employeePerformance,
      builder: (context, state) {
        if (state.employeePerformanceStatus == ReportsStatus.loading) return _loadingBox();
        if (state.employeePerformanceStatus == ReportsStatus.failure) return _errorBox(state.employeePerformanceError ?? 'خطأ');
        final rows = state.employeePerformance;
        if (rows.isEmpty) return const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white60)));

        return Column(
          children: [
            if (rows.isNotEmpty)
              Container(
                height: 200,
                padding: const EdgeInsets.all(12),
                child: BarChart(
                  BarChartData(
                    barGroups: rows.take(6).toList().asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
                      BarChartRodData(toY: e.value.totalCollected, color: const Color(0xFF6C63FF), width: 22, borderRadius: BorderRadius.circular(4)),
                    ])).toList(),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
                        final i = v.toInt();
                        if (i < 0 || i >= rows.length) return const SizedBox();
                        final name = rows[i].username;
                        return Padding(padding: const EdgeInsets.only(top: 4), child: Text(name.length > 8 ? name.substring(0, 8) : name, style: const TextStyle(color: Colors.white60, fontSize: 9)));
                      })),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = rows[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF1A1D2E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const CircleAvatar(radius: 18, backgroundColor: Color(0xFF6C63FF33), child: Icon(Icons.person, color: Color(0xFF6C63FF), size: 18)),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text(r.role, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          ])),
                          Text(_fmtAmt(r.totalCollected), style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 10),
                        Wrap(spacing: 10, runSpacing: 6, children: [
                          _MiniStat('عدد الإيصالات', '${r.receiptsCount}', const Color(0xFF6C63FF)),
                          _MiniStat('العقود المنشأة', '${r.contractsCreated}', const Color(0xFF00BCD4)),
                          _MiniStat('قيمة العقود', _fmtAmt(r.totalContractValue), const Color(0xFFFF9800)),
                          _MiniStat('متوسط المعاملة', _fmtAmt(r.avgTransactionValue), const Color(0xFF69F0AE)),
                        ]),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _ExportBtn(
                label: 'تصدير أداء الموظفين PDF',
                onTap: () => ReportExport.exportEmployeePerformance(context, rows, from: from, to: to),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  6. REVENUE BY USER SUMMARY TAB
// ─────────────────────────────────────────────────────────────────────────────
class _RevenueByUserSummaryTab extends StatelessWidget {
  const _RevenueByUserSummaryTab({this.from, this.to});
  final String? from;
  final String? to;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (a, b) => a.revenueByUserSummaryStatus != b.revenueByUserSummaryStatus || a.revenueByUserSummary != b.revenueByUserSummary,
      builder: (context, state) {
        if (state.revenueByUserSummaryStatus == ReportsStatus.loading) return _loadingBox();
        if (state.revenueByUserSummaryStatus == ReportsStatus.failure) return _errorBox(state.revenueByUserSummaryError ?? 'خطأ');
        final rows = state.revenueByUserSummary;
        if (rows.isEmpty) return const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white60)));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = rows[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF1A1D2E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const CircleAvatar(radius: 18, backgroundColor: Color(0xFF00C85333), child: Icon(Icons.person, color: Color(0xFF00C853), size: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(r.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    Text(_fmtAmt(r.totalReceipts), style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 6, children: [
                    _MiniStat('نقداً', _fmtAmt(r.cashCollected), const Color(0xFF69F0AE)),
                    _MiniStat('تحويل', _fmtAmt(r.transferCollected), const Color(0xFF00BCD4)),
                    _MiniStat('عدد المعاملات', '${r.transactionsCount}', const Color(0xFF6C63FF)),
                  ]),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  7. REVENUE TREND TAB
// ─────────────────────────────────────────────────────────────────────────────
class _RevenueTrendTab extends StatelessWidget {
  const _RevenueTrendTab({this.from, this.to});
  final String? from;
  final String? to;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (a, b) => a.revenueStatus != b.revenueStatus || a.revenue != b.revenue,
      builder: (context, state) {
        if (state.revenueStatus == ReportsStatus.loading) return _loadingBox();
        if (state.revenueStatus == ReportsStatus.failure) return _errorBox(state.revenueError ?? 'خطأ');
        final rows = state.revenue;

        if (rows.isEmpty) return const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white60)));

        final maxY = rows.map((r) => r.revenue).fold<double>(0, (a, b) => a > b ? a : b);
        final spots = rows.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.revenue)).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionHeader('مخطط الإيرادات'),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: LineChart(
                LineChartData(
                  maxY: maxY * 1.15,
                  minY: 0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: const Color(0xFF6C63FF),
                      barWidth: 3,
                      belowBarData: BarAreaData(show: true, color: const Color(0xFF6C63FF22)),
                      dotData: const FlDotData(show: false),
                    )
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: (rows.length / 5).ceilToDouble(), getTitlesWidget: (v, m) {
                      final i = v.toInt();
                      if (i < 0 || i >= rows.length) return const SizedBox();
                      return Padding(padding: const EdgeInsets.only(top: 6), child: Text(rows[i].period, style: const TextStyle(color: Colors.white54, fontSize: 9)));
                    })),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true, getDrawingHorizontalLine: (_) => FlLine(color: Colors.white10, strokeWidth: 1)),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionHeader('تفاصيل الإيرادات'),
            const SizedBox(height: 12),
            ...rows.map((r) => _RowLine(label: r.period, value: _fmtAmt(r.revenue), color: const Color(0xFF6C63FF))).toList(),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  8. PAYMENTS TAB (existing)
// ─────────────────────────────────────────────────────────────────────────────
class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({this.from, this.to});
  final String? from;
  final String? to;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (a, b) => a.paymentsStatus != b.paymentsStatus || a.payments != b.payments,
      builder: (context, state) {
        if (state.paymentsStatus == ReportsStatus.loading) return _loadingBox();
        if (state.paymentsStatus == ReportsStatus.failure) return _errorBox(state.paymentsError ?? 'خطأ');
        final d = state.payments;
        if (d == null) return _loadingBox();

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF1A1D2E),
              child: Row(
                children: [
                  Expanded(child: _kpiCard(label: 'إجمالي الداخل', value: _fmtAmt(d.totals.totalIn), icon: Icons.arrow_downward, iconBg: const Color(0xFF00C853))),
                  const SizedBox(width: 8),
                  Expanded(child: _kpiCard(label: 'إجمالي الخارج', value: _fmtAmt(d.totals.totalOut), icon: Icons.arrow_upward, iconBg: const Color(0xFFFF5252))),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: d.rows.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                itemBuilder: (ctx, i) {
                  final p = d.rows[i];
                  final isIn = p.type == 'in';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: (isIn ? const Color(0xFF00C853) : const Color(0xFFFF5252)).withOpacity(0.15),
                      child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: isIn ? const Color(0xFF00C853) : const Color(0xFFFF5252), size: 18),
                    ),
                    title: Text(p.clientName ?? '—', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: Text('${p.method ?? ''} • ${p.createdAt ?? ''}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    trailing: Text(_fmtAmt(p.amount), style: TextStyle(color: isIn ? const Color(0xFF00C853) : const Color(0xFFFF5252), fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  9. TOP EQUIPMENT TAB
// ─────────────────────────────────────────────────────────────────────────────
class _TopEquipmentTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (a, b) => a.topEquipmentStatus != b.topEquipmentStatus || a.topEquipment != b.topEquipment,
      builder: (context, state) {
        if (state.topEquipmentStatus == ReportsStatus.loading) return _loadingBox();
        if (state.topEquipmentStatus == ReportsStatus.failure) return _errorBox(state.topEquipmentError ?? 'خطأ');
        final rows = state.topEquipment;
        if (rows.isEmpty) return const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white60)));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (ctx, i) {
            final r = rows[i];
            return ListTile(
              tileColor: const Color(0xFF1A1D2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: CircleAvatar(child: Text('${i + 1}', style: const TextStyle(fontSize: 12)), backgroundColor: const Color(0xFF6C63FF)),
              title: Text(r.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text('${r.rentalsCount} إيجار', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              trailing: Text(_fmtAmt(r.totalIncome), style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  10. TOP CLIENTS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _TopClientsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (a, b) => a.topClientsStatus != b.topClientsStatus || a.topClients != b.topClients,
      builder: (context, state) {
        if (state.topClientsStatus == ReportsStatus.loading) return _loadingBox();
        if (state.topClientsStatus == ReportsStatus.failure) return _errorBox(state.topClientsError ?? 'خطأ');
        final rows = state.topClients;
        if (rows.isEmpty) return const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white60)));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (ctx, i) {
            final r = rows[i];
            return ListTile(
              tileColor: const Color(0xFF1A1D2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: CircleAvatar(child: Text('${i + 1}', style: const TextStyle(fontSize: 12)), backgroundColor: const Color(0xFF00BCD4)),
              title: Text(r.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text('${r.contractsCount} عقد • ${r.phone ?? ''}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              trailing: Text(_fmtAmt(r.totalAmount), style: const TextStyle(color: Color(0xFF00BCD4), fontWeight: FontWeight.bold)),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  11. LATE CLIENTS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _LateClientsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (a, b) => a.lateClientsStatus != b.lateClientsStatus || a.lateClients != b.lateClients,
      builder: (context, state) {
        if (state.lateClientsStatus == ReportsStatus.loading) return _loadingBox();
        if (state.lateClientsStatus == ReportsStatus.failure) return _errorBox(state.lateClientsError ?? 'خطأ');
        final rows = state.lateClients;
        if (rows.isEmpty) return const Center(child: Text('لا يوجد متأخرون', style: TextStyle(color: Colors.white60)));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (ctx, i) {
            final r = rows[i];
            return ListTile(
              tileColor: const Color(0xFF1A1D2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: const CircleAvatar(backgroundColor: Color(0xFFFF525233), child: Icon(Icons.warning_amber, color: Color(0xFFFF5252), size: 18)),
              title: Text(r.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text(r.phone ?? '—', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              trailing: Text('${r.lateContractsCount} عقد', style: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold)),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  12. REVENUE BY USER (legacy)
// ─────────────────────────────────────────────────────────────────────────────
class _RevenueByUserTab extends StatelessWidget {
  const _RevenueByUserTab({this.from, this.to});
  final String? from;
  final String? to;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      buildWhen: (a, b) => a.revenueByUserStatus != b.revenueByUserStatus || a.revenueByUser != b.revenueByUser,
      builder: (context, state) {
        if (state.revenueByUserStatus == ReportsStatus.loading) return _loadingBox();
        if (state.revenueByUserStatus == ReportsStatus.failure) return _errorBox(state.revenueByUserError ?? 'خطأ');
        final rows = state.revenueByUser;
        if (rows.isEmpty) return const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white60)));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (ctx, i) {
            final r = rows[i];
            return ListTile(
              tileColor: const Color(0xFF1A1D2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: const CircleAvatar(backgroundColor: Color(0xFF6C63FF33), child: Icon(Icons.person, color: Color(0xFF6C63FF), size: 18)),
              title: Text(r.username, style: const TextStyle(color: Colors.white)),
              subtitle: Text('${r.receiptsCount} إيصال • ${r.role}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              trailing: Text(_fmtAmt(r.revenue), style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold)),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _RowLine extends StatelessWidget {
  const _RowLine({required this.label, required this.value, required this.color, this.bold = false});
  final String label;
  final String value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: bold ? Colors.white : Colors.white70, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 14 : 13)),
          Text(value, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: bold ? 14 : 13)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }
}

class _ExportBtn extends StatelessWidget {
  const _ExportBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.picture_as_pdf, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
