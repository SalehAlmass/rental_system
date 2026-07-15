import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:rental_app/features/profile/profile_cubit.dart';
import 'package:rental_app/core/widgets/permission_guard.dart';

import '../../../../core/config/app_config.dart';
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
//  Design Tokens
// ─────────────────────────────────────────────────────────────────────────────
class _R {
  static const Color bg = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFFBBDEFB);
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFFC8E6C9);
  static const Color warning = Color(0xFFEF6C00);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFFFCDD2);
  static const Color info = Color(0xFF00838F);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);
  static const double radius = 12;
  static const double radiusSm = 8;
  static EdgeInsets cardPad = const EdgeInsets.all(16);
  static EdgeInsets pagePad = const EdgeInsets.all(16);
}

final _numFmt = NumberFormat('#,##0.00', 'ar');
String _fmtAmt(double v) => '${_numFmt.format(v)} ${AppConfig.currencySymbol}';
String _fmtN(double v) => _numFmt.format(v);
String _fmtPct(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}%';

Color _profitColor(double v) => v >= 0 ? _R.success : _R.error;

Widget _sectionHeader(String title, {Widget? action}) {
  return Row(
    children: [
      Container(width: 4, height: 22, decoration: BoxDecoration(color: _R.primary, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Expanded(child: Text(title, style: const TextStyle(color: _R.textPrimary, fontSize: 16, fontWeight: FontWeight.bold))),
      if (action != null) action,
    ],
  );
}

Widget _loadingBox() => const Center(child: Padding(
  padding: EdgeInsets.all(40),
  child: CircularProgressIndicator(color: _R.primary),
));

Widget _errorBox(String msg, {VoidCallback? onRetry}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: _R.textHint),
          const SizedBox(height: 12),
          Text('تعذر تحميل التقرير', style: const TextStyle(color: _R.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('يرجى المحاولة مرة أخرى.', style: const TextStyle(color: _R.textSecondary, fontSize: 13), textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
          ],
        ],
      ),
    ),
  );
}

Widget _emptyBox(String msg) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart, size: 48, color: _R.textHint.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: _R.textSecondary, fontSize: 14), textAlign: TextAlign.center),
          SizedBox(height: 6),
          Text('قم بتغيير الفترة أو الفلاتر.', style: TextStyle(color: _R.textHint, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

Widget _skeletonGrid({int count = 6, int crossAxisCount = 2}) {
  return GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: crossAxisCount,
    childAspectRatio: 1.55,
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    children: List.generate(count, (_) => Container(
      decoration: BoxDecoration(color: _R.border.withOpacity(0.5), borderRadius: BorderRadius.circular(_R.radius)),
      padding: _R.cardPad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 24, height: 24, decoration: BoxDecoration(color: _R.border, borderRadius: BorderRadius.circular(6))),
          const Spacer(),
          Container(width: 80, height: 12, decoration: BoxDecoration(color: _R.border, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 6),
          Container(width: 120, height: 20, decoration: BoxDecoration(color: _R.border, borderRadius: BorderRadius.circular(4))),
        ],
      ),
    )),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared Widgets
// ─────────────────────────────────────────────────────────────────────────────
Widget _card({required Widget child, EdgeInsets? padding, double? radius}) {
  return Container(
    padding: padding ?? _R.cardPad,
    decoration: BoxDecoration(
      color: _R.surface,
      borderRadius: BorderRadius.circular(radius ?? _R.radius),
      border: Border.all(color: _R.border),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
      ],
    ),
    child: child,
  );
}

Widget _kpiCard({
  required String label,
  required String value,
  Color? valueColor,
  IconData? icon,
  Color? iconBg,
}) {
  final icBg = iconBg ?? _R.primaryLight;
  return _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: icBg, borderRadius: BorderRadius.circular(_R.radiusSm)),
                child: Icon(icon, size: 18, color: iconBg != null ? Colors.white : _R.primary),
              ),
            if (icon != null) const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: const TextStyle(color: _R.textSecondary, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? _R.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

Widget _rowLine(String label, String value, {Color? color, bool bold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: bold ? _R.textPrimary : _R.textSecondary, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 14 : 13)),
        Text(value, style: TextStyle(color: color ?? _R.textPrimary, fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: bold ? 14 : 13)),
      ],
    ),
  );
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
      Text(label, style: const TextStyle(color: _R.textSecondary, fontSize: 11)),
    ]);
  }
}

class _ExportBtn extends StatelessWidget {
  const _ExportBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pstate = context.watch<ProfileCubit>().state;
    final canExport = pstate is ProfileLoaded && pstate.hasScreenPermission('export');

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canExport ? onTap : null,
        icon: const Icon(Icons.picture_as_pdf, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: _R.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_R.radius)),
        ),
      ),
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
        Text(label, style: const TextStyle(color: _R.textHint, fontSize: 10)),
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

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

  late final bool _hasFinancial;
  late final List<Tab> _tabs;

  @override
  void initState() {
    super.initState();
    final pstate = context.read<ProfileCubit>().state;
    _hasFinancial = pstate is ProfileLoaded && pstate.hasScreenPermission('financial_reports');

    _tabs = [
      if (_hasFinancial) const Tab(text: 'الملخص المالي'),
      if (_hasFinancial) const Tab(text: 'الأرباح والخسائر'),
      if (_hasFinancial) const Tab(text: 'التدفقات النقدية'),
      const Tab(text: 'أرباح المعدات'),
      const Tab(text: 'أداء الموظفين'),
      const Tab(text: 'الإيرادات بالمستخدم'),
      const Tab(text: 'الإيرادات'),
      const Tab(text: 'السندات'),
      const Tab(text: 'أفضل معدات'),
      const Tab(text: 'أفضل عملاء'),
      const Tab(text: 'المتأخرون'),
      const Tab(text: 'الإيرادات بالموظف'),
    ];

    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setQuickDate(int days) {
    final now = DateTime.now();
    setState(() {
      _to = now;
      _from = now.subtract(Duration(days: days));
    });
    _apply();
  }

  void _setThisWeek() {
    final now = DateTime.now();
    final weekday = now.weekday;
    setState(() {
      _to = now;
      _from = now.subtract(Duration(days: weekday - 1));
    });
    _apply();
  }

  void _setThisMonth() {
    final now = DateTime.now();
    setState(() {
      _to = now;
      _from = DateTime(now.year, now.month, 1);
    });
    _apply();
  }

  void _setThisYear() {
    final now = DateTime.now();
    setState(() {
      _to = now;
      _from = DateTime(now.year, 1, 1);
    });
    _apply();
  }

  Future<void> _pickCustom() async {
    final from = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (from == null || !context.mounted) return;
    final to = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (to == null || !context.mounted) return;
    setState(() { _from = from; _to = to; });
    _apply();
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
    return Scaffold(
      backgroundColor: _R.bg,
      appBar: AppBar(
        title: const Text('التقارير', style: TextStyle(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: widget.showBackButton,
        backgroundColor: _R.surface,
        foregroundColor: _R.textPrimary,
        surfaceTintColor: _R.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(130),
          child: Container(
            color: _R.surface,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تحليل أداء النظام المالي والتشغيلي', style: TextStyle(color: _R.textSecondary, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _quickBtn('اليوم', () => _setQuickDate(0)),
                          const SizedBox(width: 6),
                          _quickBtn('أسبوع', _setThisWeek),
                          const SizedBox(width: 6),
                          _quickBtn('شهر', _setThisMonth),
                          const SizedBox(width: 6),
                          _quickBtn('سنة', _setThisYear),
                          const SizedBox(width: 6),
                          _quickBtn('مخصص', _pickCustom),
                        ],
                      ),
                      if (_from != null || _to != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.date_range, size: 14, color: _R.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${_from == null ? '—' : _fmt.format(_from!)} → ${_to == null ? '—' : _fmt.format(_to!)}',
                              style: TextStyle(color: _R.primary, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: _R.primary,
                  unselectedLabelColor: _R.textHint,
                  indicatorColor: _R.primary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 12),
                  tabs: _tabs,
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          if (_hasFinancial) _FinancialSummaryTab(from: _from == null ? null : _fmt.format(_from!), to: _to == null ? null : _fmt.format(_to!)),
          if (_hasFinancial) _ProfitLossTab(from: _from == null ? null : _fmt.format(_from!), to: _to == null ? null : _fmt.format(_to!)),
          if (_hasFinancial) _CashFlowTab(from: _from == null ? null : _fmt.format(_from!), to: _to == null ? null : _fmt.format(_to!)),
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

Widget _quickBtn(String label, VoidCallback onTap) {
  return SizedBox(
    height: 30,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _R.primary,
        side: BorderSide(color: _R.primary.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Text(label),
    ),
  );
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
        if (state.financialSummaryStatus == ReportsStatus.loading) {
          return ListView(padding: _R.pagePad, children: [
            _skeletonGrid(),
            const SizedBox(height: 20),
            _sectionHeader('تفاصيل الإيرادات'),
            const SizedBox(height: 12),
            _card(child: Column(children: List.generate(3, (_) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Container(height: 16, decoration: BoxDecoration(color: _R.border, borderRadius: BorderRadius.circular(4))))))),
          ]);
        }
        if (state.financialSummaryStatus == ReportsStatus.failure) return _errorBox(state.financialSummaryError ?? 'خطأ', onRetry: () => context.read<ReportsBloc>().add(ReportsFinancialSummaryRequested(from: from, to: to)));

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
                PieChartSectionData(value: d.maintenanceExpenses, color: _R.warning, title: 'صيانة', radius: 55, titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                PieChartSectionData(value: d.payrollExpenses, color: _R.primary, title: 'رواتب', radius: 55, titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                PieChartSectionData(value: d.depreciationExpenses, color: _R.info, title: 'استهلاك', radius: 55, titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                PieChartSectionData(value: d.operationalExpenses, color: const Color(0xFF6A1B9A), title: 'تشغيل', radius: 55, titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              ]
            : [PieChartSectionData(value: 1, color: _R.border, title: 'لا يوجد', radius: 55, titleStyle: const TextStyle(fontSize: 10, color: _R.textSecondary))];

        return ListView(
          padding: _R.pagePad,
          children: [
            // KPI header
            _card(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: _R.primaryLight, borderRadius: BorderRadius.circular(_R.radius)),
                        child: const Icon(Icons.assessment, color: _R.primary, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الملخص المالي', style: const TextStyle(color: _R.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('نظرة عامة على الأداء المالي', style: TextStyle(color: _R.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // KPI Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.55,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _kpiCard(label: 'إجمالي الإيرادات', value: _fmtAmt(d.totalRevenue), icon: Icons.trending_up, iconBg: _R.success),
                _kpiCard(label: 'إجمالي المصروفات', value: _fmtAmt(d.totalExpenses), icon: Icons.trending_down, iconBg: _R.error),
                _kpiCard(label: 'صافي الربح', value: _fmtAmt(d.netProfit), valueColor: _profitColor(d.netProfit), icon: Icons.account_balance, iconBg: _profitColor(d.netProfit)),
                _kpiCard(label: 'هامش الربح', value: _fmtPct(d.profitMarginPct), icon: Icons.percent, iconBg: _R.primaryLight),
                _kpiCard(label: 'مستحقات غير مسددة', value: _fmtAmt(d.outstandingAmount), icon: Icons.schedule, iconBg: _R.warning),
                _kpiCard(label: 'قيمة الأصول', value: _fmtAmt(d.totalAssetValue), icon: Icons.business, iconBg: _R.primaryLight),
              ],
            ),
            const SizedBox(height: 20),

            // Revenue breakdown
            _sectionHeader('تفاصيل الإيرادات'),
            const SizedBox(height: 12),
            _card(child: Column(
              children: [
                _rowLine('إيرادات الإيجار', _fmtAmt(d.rentalRevenue), color: _R.success),
                const Divider(height: 1, color: _R.divider),
                _rowLine('إيرادات أخرى', _fmtAmt(d.otherRevenue), color: _R.primary),
                const Divider(height: 1, color: _R.divider),
                _rowLine('إجمالي الإيرادات', _fmtAmt(d.totalRevenue), color: _R.textPrimary, bold: true),
              ],
            )),
            const SizedBox(height: 20),

            // Profit indicators
            _sectionHeader('مؤشرات الربحية'),
            const SizedBox(height: 12),
            _card(child: Column(
              children: [
                _rowLine('الربح الإجمالي', _fmtAmt(d.grossProfit), color: _profitColor(d.grossProfit)),
                const Divider(height: 1, color: _R.divider),
                _rowLine('الربح التشغيلي', _fmtAmt(d.operatingProfit), color: _profitColor(d.operatingProfit)),
                const Divider(height: 1, color: _R.divider),
                _rowLine('صافي الربح', _fmtAmt(d.netProfit), color: _profitColor(d.netProfit), bold: true),
              ],
            )),
            const SizedBox(height: 20),

            // Expense pie chart
            _sectionHeader('توزيع المصروفات'),
            const SizedBox(height: 16),
            _card(
              child: Column(
                children: [
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
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _Legend(color: _R.warning, label: 'صيانة ${_fmtPct(expTotal > 0 ? (d.maintenanceExpenses / expTotal * 100) : null)}'),
                      _Legend(color: _R.primary, label: 'رواتب ${_fmtPct(expTotal > 0 ? (d.payrollExpenses / expTotal * 100) : null)}'),
                      _Legend(color: _R.info, label: 'استهلاك ${_fmtPct(expTotal > 0 ? (d.depreciationExpenses / expTotal * 100) : null)}'),
                      _Legend(color: const Color(0xFF6A1B9A), label: 'تشغيل ${_fmtPct(expTotal > 0 ? (d.operationalExpenses / expTotal * 100) : null)}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Export
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
        if (state.profitLossStatus == ReportsStatus.failure) return _errorBox(state.profitLossError ?? 'خطأ', onRetry: () => context.read<ReportsBloc>().add(ReportsProfitLossRequested(from: from, to: to)));
        final d = state.profitLoss;
        if (d == null) return _loadingBox();

        return ListView(
          padding: _R.pagePad,
          children: [
            _card(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _R.primaryLight, borderRadius: BorderRadius.circular(_R.radius)),
                    child: const Icon(Icons.account_balance, color: _R.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('قائمة الأرباح والخسائر', style: const TextStyle(color: _R.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('إيرادات — تكاليف — مصروفات', style: TextStyle(color: _R.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _PLSection(title: 'الإيرادات', color: _R.success, rows: [
              _PLRow('إيرادات الإيجار', d.rentalRevenue),
              _PLRow('إيرادات أخرى', d.otherRevenue),
              _PLRow('إجمالي الإيرادات', d.totalRevenue, bold: true),
            ]),
            const SizedBox(height: 16),
            _PLSection(title: 'تكلفة الإيرادات', color: _R.warning, rows: [
              _PLRow('الصيانة', d.maintenanceCost),
              _PLRow('الاستهلاك', d.depreciationCost),
              _PLRow('إجمالي تكلفة الإيرادات', d.totalCost, bold: true),
            ]),
            const SizedBox(height: 12),
            _PLSummaryLine(label: 'الربح الإجمالي', value: d.grossProfit),
            const SizedBox(height: 16),
            _PLSection(title: 'المصروفات التشغيلية', color: _R.primary, rows: [
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
        color: _R.surface,
        borderRadius: BorderRadius.circular(_R.radius),
        border: Border.all(color: _R.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(_R.radiusSm)),
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
          Text(label, style: TextStyle(color: bold ? _R.textPrimary : _R.textSecondary, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
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
        color: _profitColor(value).withOpacity(0.08),
        borderRadius: BorderRadius.circular(_R.radius),
        border: Border.all(color: _profitColor(value).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: _R.textPrimary, fontSize: big ? 16 : 14, fontWeight: FontWeight.bold)),
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
        if (state.cashFlowStatus == ReportsStatus.failure) return _errorBox(state.cashFlowError ?? 'خطأ', onRetry: () => context.read<ReportsBloc>().add(ReportsCashFlowRequested(from: from, to: to)));
        final d = state.cashFlow;
        if (d == null) return _loadingBox();

        return ListView(
          padding: _R.pagePad,
          children: [
            _card(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _R.primaryLight, borderRadius: BorderRadius.circular(_R.radius)),
                    child: const Icon(Icons.swap_horiz, color: _R.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('التدفقات النقدية', style: const TextStyle(color: _R.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('حركة النقدية الداخلة والخارجة', style: TextStyle(color: _R.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _CashFlowCard(label: 'الرصيد الافتتاحي', value: d.openingBalance, icon: Icons.account_balance_wallet, color: _R.primary),
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
    return _card(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: big ? 24 : 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: _R.textSecondary, fontSize: big ? 14 : 12)),
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
      decoration: BoxDecoration(color: _R.surface, borderRadius: BorderRadius.circular(_R.radius), border: Border.all(color: _R.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(color: Color(0xFFE8F5E9), borderRadius: BorderRadius.vertical(top: Radius.circular(_R.radiusSm))),
            child: Row(children: [const Icon(Icons.arrow_downward, color: _R.success, size: 16), const SizedBox(width: 6), const Text('التدفقات الداخلة', style: TextStyle(color: _R.success, fontWeight: FontWeight.bold))]),
          ),
          _rowLine('نقداً', _fmtAmt(d.cashIn), color: _R.success),
          _rowLine('تحويل بنكي', _fmtAmt(d.transferIn), color: _R.success),
          _rowLine('إجمالي التدفقات الداخلة', _fmtAmt(d.totalCashIn), color: _R.success, bold: true),
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
      decoration: BoxDecoration(color: _R.surface, borderRadius: BorderRadius.circular(_R.radius), border: Border.all(color: _R.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(color: Color(0xFFFFEBEE), borderRadius: BorderRadius.vertical(top: Radius.circular(_R.radiusSm))),
            child: Row(children: [const Icon(Icons.arrow_upward, color: _R.error, size: 16), const SizedBox(width: 6), const Text('التدفقات الخارجة', style: TextStyle(color: _R.error, fontWeight: FontWeight.bold))]),
          ),
          _rowLine('نقداً', _fmtAmt(d.cashOut), color: _R.error),
          _rowLine('تحويل بنكي', _fmtAmt(d.transferOut), color: _R.error),
          _rowLine('صيانة', _fmtAmt(d.maintenanceCashOut), color: _R.warning),
          _rowLine('إجمالي التدفقات الخارجة', _fmtAmt(d.totalCashOut), color: _R.error, bold: true),
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
        if (rows.isEmpty) return _emptyBox('لا توجد بيانات أرباح للمعدات');

        return ListView(
          padding: _R.pagePad,
          children: [
            _card(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _R.primaryLight, borderRadius: BorderRadius.circular(_R.radius)),
                    child: const Icon(Icons.precision_manufacturing, color: _R.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('أرباح المعدات', style: const TextStyle(color: _R.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('العائد على الاستثمار لكل معدة', style: TextStyle(color: _R.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (rows.isNotEmpty)
              _card(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: rows.map((r) => r.rentalRevenue).fold<double>(0, (a, b) => a > b ? a : b) * 1.2,
                      barGroups: rows.take(6).toList().asMap().entries.map((e) {
                        return BarChartGroupData(x: e.key, barRods: [
                          BarChartRodData(toY: e.value.rentalRevenue, color: _R.primary, width: 18, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
                          BarChartRodData(toY: e.value.netProfit, color: _profitColor(e.value.netProfit), width: 18, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
                        ]);
                      }).toList(),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
                          final i = v.toInt();
                          if (i < 0 || i >= rows.length) return const SizedBox();
                          return Padding(padding: const EdgeInsets.only(top: 4), child: Text(rows[i].name.length > 8 ? rows[i].name.substring(0, 8) : rows[i].name, style: const TextStyle(color: _R.textSecondary, fontSize: 9)));
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
              ),
            const SizedBox(height: 14),
            _sectionHeader('تفاصيل أرباح المعدات'),
            const SizedBox(height: 12),
            ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(r.name, style: const TextStyle(color: _R.textPrimary, fontWeight: FontWeight.bold))),
                        if (r.roiPct != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: _profitColor(r.roiPct!).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                            child: Text('العائد على الاستثمار: ${_fmtPct(r.roiPct)}', style: TextStyle(color: _profitColor(r.roiPct!), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        _MiniStat('إيرادات الإيجار', _fmtAmt(r.rentalRevenue), _R.success),
                        _MiniStat('أيام الإيجار', '${r.rentalDays.toStringAsFixed(0)} يوم', _R.primary),
                        _MiniStat('تكلفة الصيانة', _fmtAmt(r.maintenanceCost), _R.warning),
                        _MiniStat('استهلاك محاسبي', _fmtAmt(r.accountingDepreciation), _R.info),
                        _MiniStat('صافي الربح', _fmtAmt(r.netProfit), _profitColor(r.netProfit)),
                      ],
                    ),
                  ],
                ),
              ),
            )).toList(),
          ],
        );
      },
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
        if (rows.isEmpty) return _emptyBox('لا توجد بيانات أداء للموظفين');

        return ListView(
          padding: _R.pagePad,
          children: [
            _card(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _R.primaryLight, borderRadius: BorderRadius.circular(_R.radius)),
                    child: const Icon(Icons.people_alt, color: _R.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('أداء الموظفين', style: const TextStyle(color: _R.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('تحصيل وإنتاجية الموظفين', style: TextStyle(color: _R.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (rows.isNotEmpty)
              _card(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      barGroups: rows.take(6).toList().asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
                        BarChartRodData(toY: e.value.totalCollected, color: _R.primary, width: 22, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
                      ])).toList(),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
                          final i = v.toInt();
                          if (i < 0 || i >= rows.length) return const SizedBox();
                          final name = rows[i].username;
                          return Padding(padding: const EdgeInsets.only(top: 4), child: Text(name.length > 8 ? name.substring(0, 8) : name, style: const TextStyle(color: _R.textSecondary, fontSize: 9)));
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
              ),
            const SizedBox(height: 14),
            _sectionHeader('تفاصيل أداء الموظفين'),
            const SizedBox(height: 12),
            ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(radius: 18, backgroundColor: _R.primaryLight, child: const Icon(Icons.person, color: _R.primary, size: 18)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.username, style: const TextStyle(color: _R.textPrimary, fontWeight: FontWeight.bold)),
                        Text(r.role, style: const TextStyle(color: _R.textSecondary, fontSize: 11)),
                      ])),
                      Text(_fmtAmt(r.totalCollected), style: const TextStyle(color: _R.success, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(spacing: 10, runSpacing: 6, children: [
                      _MiniStat('عدد الإيصالات', '${r.receiptsCount}', _R.primary),
                      _MiniStat('العقود المنشأة', '${r.contractsCreated}', _R.info),
                      _MiniStat('قيمة العقود', _fmtAmt(r.totalContractValue), _R.warning),
                      _MiniStat('متوسط المعاملة', _fmtAmt(r.avgTransactionValue), _R.success),
                    ]),
                  ],
                ),
              ),
            )).toList(),
            const SizedBox(height: 16),
            _ExportBtn(
              label: 'تصدير أداء الموظفين PDF',
              onTap: () => ReportExport.exportEmployeePerformance(context, rows, from: from, to: to),
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
        if (rows.isEmpty) return _emptyBox('لا توجد بيانات');

        return ListView(
          padding: _R.pagePad,
          children: [
            _card(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _R.primaryLight, borderRadius: BorderRadius.circular(_R.radius)),
                    child: const Icon(Icons.person_outline, color: _R.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الإيرادات بالمستخدم', style: const TextStyle(color: _R.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('تفصيل الإيرادات لكل مستخدم', style: TextStyle(color: _R.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(radius: 18, backgroundColor: _R.successLight, child: const Icon(Icons.person, color: _R.success, size: 18)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(r.username, style: const TextStyle(color: _R.textPrimary, fontWeight: FontWeight.bold))),
                      Text(_fmtAmt(r.totalReceipts), style: const TextStyle(color: _R.success, fontWeight: FontWeight.bold, fontSize: 15)),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(spacing: 10, runSpacing: 6, children: [
                      _MiniStat('نقداً', _fmtAmt(r.cashCollected), _R.success),
                      _MiniStat('تحويل', _fmtAmt(r.transferCollected), _R.info),
                      _MiniStat('عدد المعاملات', '${r.transactionsCount}', _R.primary),
                    ]),
                  ],
                ),
              ),
            )).toList(),
          ],
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
        if (rows.isEmpty) return _emptyBox('لا توجد بيانات إيرادات');

        final maxY = rows.map((r) => r.revenue).fold<double>(0, (a, b) => a > b ? a : b);
        final spots = rows.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.revenue)).toList();

        return ListView(
          padding: _R.pagePad,
          children: [
            _card(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _R.primaryLight, borderRadius: BorderRadius.circular(_R.radius)),
                    child: const Icon(Icons.timeline, color: _R.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مخطط الإيرادات', style: const TextStyle(color: _R.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('تطور الإيرادات خلال الفترة', style: TextStyle(color: _R.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              child: SizedBox(
                height: 260,
                child: LineChart(
                  LineChartData(
                    maxY: maxY * 1.15,
                    minY: 0,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: _R.primary,
                        barWidth: 3,
                        belowBarData: BarAreaData(show: true, gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [_R.primary.withOpacity(0.3), _R.primary.withOpacity(0.02)],
                        )),
                        dotData: const FlDotData(show: false),
                      )
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: (rows.length / 5).ceilToDouble(), getTitlesWidget: (v, m) {
                        final i = v.toInt();
                        if (i < 0 || i >= rows.length) return const SizedBox();
                        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(rows[i].period, style: const TextStyle(color: _R.textSecondary, fontSize: 9)));
                      })),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(show: true, getDrawingHorizontalLine: (_) => FlLine(color: _R.border, strokeWidth: 1)),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionHeader('تفاصيل الإيرادات'),
            const SizedBox(height: 12),
            _card(
              child: Column(
                children: rows.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: _rowLine(r.period, _fmtAmt(r.revenue), color: _R.primary),
                )).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  8. PAYMENTS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _PaymentsTab extends StatefulWidget {
  const _PaymentsTab({this.from, this.to});
  final String? from;
  final String? to;

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  String _sortBy = 'id';
  String _sortOrder = 'desc';

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
              color: _R.bg,
              child: Row(
                children: [
                  Expanded(child: _kpiCard(label: 'إجمالي الداخل', value: _fmtAmt(d.totals.totalIn), icon: Icons.arrow_downward, iconBg: _R.success)),
                  const SizedBox(width: 8),
                  Expanded(child: _kpiCard(label: 'إجمالي الخارج', value: _fmtAmt(d.totals.totalOut), icon: Icons.arrow_upward, iconBg: _R.error)),
                ],
              ),
            ),
            _buildSortingBar(context),
            Expanded(
              child: d.rows.isEmpty
                  ? _emptyBox('لا توجد سندات للفترة المحددة')
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: d.rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (ctx, i) {
                        final p = d.rows[i];
                        final isIn = p.type == 'in';
                        return _card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            leading: CircleAvatar(
                              backgroundColor: (isIn ? _R.successLight : _R.errorLight),
                              child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: isIn ? _R.success : _R.error, size: 18),
                            ),
                            title: Text(p.clientName ?? '—', style: const TextStyle(color: _R.textPrimary, fontSize: 13)),
                            subtitle: Text('${p.method ?? ''} • ${p.createdAt ?? ''}', style: const TextStyle(color: _R.textSecondary, fontSize: 11)),
                            trailing: Text(_fmtAmt(p.amount), style: TextStyle(color: isIn ? _R.success : _R.error, fontWeight: FontWeight.bold)),
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

  Widget _buildSortingBar(BuildContext context) {
    final sortOptions = {
      'id': 'رقم السند',
      'created_at': 'تاريخ السند',
      'amount': 'المبلغ',
      'type': 'نوع السند',
      'client_name': 'اسم العميل',
    };

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sort, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _sortBy,
            underline: const SizedBox(),
            items: sortOptions.entries.map((e) {
              return DropdownMenuItem<String>(
                value: e.key,
                child: Text(e.value, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _sortBy = val;
                });
                context.read<ReportsBloc>().add(ReportsPaymentsRequested(
                  from: widget.from,
                  to: widget.to,
                  sortBy: _sortBy,
                  sortOrder: _sortOrder,
                ));
              }
            },
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _sortOrder == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
              });
              context.read<ReportsBloc>().add(ReportsPaymentsRequested(
                from: widget.from,
                to: widget.to,
                sortBy: _sortBy,
                sortOrder: _sortOrder,
              ));
            },
          ),
        ],
      ),
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
        if (rows.isEmpty) return _emptyBox('لا توجد بيانات');

        return ListView(
          padding: _R.pagePad,
          children: [
            _card(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _R.primaryLight, borderRadius: BorderRadius.circular(_R.radius)),
                    child: const Icon(Icons.star, color: _R.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('أفضل المعدات', style: const TextStyle(color: _R.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('المعدات الأعلى إيراداً', style: TextStyle(color: _R.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...rows.asMap().entries.map((e) {
              final i = e.key;
              final r = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    leading: CircleAvatar(child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.white)), backgroundColor: _R.primary),
                    title: Text(r.name, style: const TextStyle(color: _R.textPrimary)),
                    subtitle: Text('${r.rentalsCount} إيجار', style: const TextStyle(color: _R.textSecondary, fontSize: 11)),
                    trailing: Text(_fmtAmt(r.totalIncome), style: const TextStyle(color: _R.primary, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }).toList(),
          ],
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
        if (rows.isEmpty) return _emptyBox('لا توجد بيانات');

        return ListView(
          padding: _R.pagePad,
          children: [
            _card(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _R.primaryLight, borderRadius: BorderRadius.circular(_R.radius)),
                    child: const Icon(Icons.people, color: _R.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('أفضل العملاء', style: const TextStyle(color: _R.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('العملاء الأعلى قيمة', style: TextStyle(color: _R.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...rows.asMap().entries.map((e) {
              final i = e.key;
              final r = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    leading: CircleAvatar(child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.white)), backgroundColor: _R.info),
                    title: Text(r.name, style: const TextStyle(color: _R.textPrimary)),
                    subtitle: Text('${r.contractsCount} عقد • ${r.phone ?? ''}', style: const TextStyle(color: _R.textSecondary, fontSize: 11)),
                    trailing: Text(_fmtAmt(r.totalAmount), style: const TextStyle(color: _R.info, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }).toList(),
          ],
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
        if (rows.isEmpty) return _emptyBox('لا يوجد متأخرون');

        return ListView(
          padding: _R.pagePad,
          children: [
            _card(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _R.errorLight, borderRadius: BorderRadius.circular(_R.radius)),
                    child: const Icon(Icons.warning_amber, color: _R.error, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('العملاء المتأخرون', style: const TextStyle(color: _R.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('العقود المتأخرة التي تحتاج متابعة', style: TextStyle(color: _R.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: CircleAvatar(backgroundColor: _R.errorLight, child: const Icon(Icons.warning_amber, color: _R.error, size: 18)),
                  title: Text(r.name, style: const TextStyle(color: _R.textPrimary)),
                  subtitle: Text(r.phone ?? '—', style: const TextStyle(color: _R.textSecondary, fontSize: 11)),
                  trailing: Text('${r.lateContractsCount} عقد', style: const TextStyle(color: _R.error, fontWeight: FontWeight.bold)),
                ),
              ),
            )).toList(),
          ],
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
        if (rows.isEmpty) return _emptyBox('لا توجد بيانات');

        return ListView(
          padding: _R.pagePad,
          children: [
            _card(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _R.primaryLight, borderRadius: BorderRadius.circular(_R.radius)),
                    child: const Icon(Icons.history, color: _R.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الإيرادات بالموظف', style: const TextStyle(color: _R.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('سجل إيرادات الموظفين', style: TextStyle(color: _R.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: CircleAvatar(backgroundColor: _R.primaryLight, child: const Icon(Icons.person, color: _R.primary, size: 18)),
                  title: Text(r.username, style: const TextStyle(color: _R.textPrimary)),
                  subtitle: Text('${r.receiptsCount} إيصال • ${r.role}', style: const TextStyle(color: _R.textSecondary, fontSize: 11)),
                  trailing: Text(_fmtAmt(r.revenue), style: const TextStyle(color: _R.success, fontWeight: FontWeight.bold)),
                ),
              ),
            )).toList(),
          ],
        );
      },
    );
  }
}
