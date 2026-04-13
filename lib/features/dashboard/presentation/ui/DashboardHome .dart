import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/widgets/page_entrance.dart';
import 'package:rental_app/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:rental_app/features/dashboard/presentation/ui/StatCard.dart';
import 'package:rental_app/features/rents/domain/entities/models.dart';
import 'package:rental_app/features/rents/presentation/ui/rent_details_page.dart';
import 'package:rental_app/features/settings/presentation/admin_monitoring_page.dart';

class DashboardHome extends StatelessWidget {
  final bool isAdmin;
  final String userName;
  final VoidCallback? onOpenRents;

  const DashboardHome({
    super.key,
    required this.isAdmin,
    required this.userName,
    this.onOpenRents,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state.status == DashboardStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == DashboardStatus.failure) {
          return Center(child: Text(state.error ?? 'حدث خطأ'));
        }

        final stats = state.stats;
        if (stats == null) {
          return const Center(child: Text('لا توجد بيانات'));
        }

        final summary = _EmployeeRentSummary.fromRents(state.recentRents);

        return PageEntrance(
          child: RefreshIndicator(
            onRefresh: () async {
              context.read<DashboardBloc>().add(DashboardRequested());
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(context, userName, isAdmin),
                const SizedBox(height: 24),
                if (isAdmin)
                  _AdminExecutiveDashboard(
                    userName: userName,
                    stats: stats,
                    rents: state.recentRents,
                    onOpenRents: onOpenRents,
                  )
                else ...[
                  if (summary.openCount > 0 ||
                      summary.overdueCount > 0 ||
                      summary.deferredCount > 0)
                    _EmployeeAlertBanner(
                      summary: summary,
                      onOpenRents: onOpenRents,
                    ),
                  if (summary.openCount > 0 ||
                      summary.overdueCount > 0 ||
                      summary.deferredCount > 0)
                    const SizedBox(height: 16),
                  SizedBox(
                    height: 116,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        StatCard(
                          title: 'العقود المفتوحة',
                          value: summary.openCount.toString(),
                          icon: Icons.lock_open_rounded,
                          onTap: onOpenRents,
                        ),
                        StatCard(
                          title: 'العقود المتأخرة',
                          value: summary.overdueCount.toString(),
                          icon: Icons.warning_amber_rounded,
                          color: Colors.red,
                          onTap: onOpenRents,
                        ),
                        StatCard(
                          title: 'تسديد مؤجل',
                          value: summary.deferredCount.toString(),
                          subtitle:
                              '${summary.deferredAmount.toStringAsFixed(0)} ر.س',
                          icon: Icons.account_balance_wallet_outlined,
                          color: Colors.orange,
                          onTap: onOpenRents,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final crossAxisCount = w >= 1100
                          ? 4
                          : w >= 800
                              ? 3
                              : w >= 500
                                  ? 2
                                  : 1;

                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: w >= 800 ? 1.45 : 1.6,
                        children: [
                          StatCard(
                            title: 'عدد العملاء',
                            value: stats.clients.toString(),
                            icon: Icons.people,
                            width: double.infinity,
                          ),
                          StatCard(
                            title: 'عدد المعدات',
                            value: stats.equipment.toString(),
                            icon: Icons.construction,
                            width: double.infinity,
                          ),
                          StatCard(
                            title: 'العقود المفتوحة',
                            value: stats.openRents.toString(),
                            icon: Icons.description,
                            onTap: onOpenRents,
                            width: double.infinity,
                          ),
                          StatCard(
                            title: 'الإيراد',
                            value: '${stats.revenue.toStringAsFixed(0)} ر.س',
                            subtitle: 'إجمالي التحصيلات',
                            icon: Icons.attach_money,
                            color: Colors.green,
                            width: double.infinity,
                          ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'آخر العقود',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (state.recentRents.isEmpty)
                  const Text('لا توجد عقود لعرضها')
                else
                  ...state.recentRents.take(10).map((r) => _RentCard(rent: r)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, String userName, bool isAdmin) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.72),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Icon(
              isAdmin ? Icons.admin_panel_settings : Icons.person,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً، $userName 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAdmin
                      ? 'لوحة تنفيذية لمتابعة التشغيل والرقابة اليومية'
                      : 'لوحة العمل اليومية',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: () {
              context.read<DashboardBloc>().add(DashboardRequested());
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _AdminExecutiveDashboard extends StatelessWidget {
  const _AdminExecutiveDashboard({
    required this.userName,
    required this.stats,
    required this.rents,
    this.onOpenRents,
  });

  final String userName;
  final dynamic stats;
  final List<Rent> rents;
  final VoidCallback? onOpenRents;

  @override
  Widget build(BuildContext context) {
    final summary = _AdminDashboardSummary.fromRents(rents);
    final money = NumberFormat.decimalPattern('ar');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdminInstantAlertsPanel(summary: summary),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1100
                ? 4
                : constraints.maxWidth >= 700
                    ? 2
                    : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: constraints.maxWidth >= 700 ? 1.55 : 1.7,
              children: [
                StatCard(
                  title: 'إيراد اليوم',
                  value: '${money.format(summary.todayRevenue)} ر.س',
                  subtitle: 'إغلاق وتحصيلات اليوم',
                  trend: _trendText(summary.todayRevenue, summary.yesterdayRevenue),
                  icon: Icons.today_rounded,
                  color: Colors.green,
                  width: double.infinity,
                ),
                StatCard(
                  title: 'تحصيل هذا الأسبوع',
                  value: '${money.format(summary.thisWeekRevenue)} ر.س',
                  subtitle: 'مقارنة بالأسبوع الماضي',
                  trend:
                      _trendText(summary.thisWeekRevenue, summary.lastWeekRevenue),
                  icon: Icons.calendar_view_week_rounded,
                  color: Colors.teal,
                  width: double.infinity,
                ),
                StatCard(
                  title: 'الذمم الحالية',
                  value: '${money.format(summary.deferredAmount)} ر.س',
                  subtitle: '${summary.deferredCount} عقد مغلق بتسديد مؤجل',
                  icon: Icons.account_balance_wallet_outlined,
                  color: Colors.orange,
                  onTap: onOpenRents,
                  width: double.infinity,
                ),
                StatCard(
                  title: 'عقود متأخرة',
                  value: '${summary.overdueCount}',
                  subtitle: '${summary.openCount} عقد مفتوح حاليًا',
                  icon: Icons.warning_amber_rounded,
                  color: Colors.red,
                  onTap: onOpenRents,
                  width: double.infinity,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 950;
            return Flex(
              direction: isWide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  flex: 5,
                  fit: FlexFit.loose,
                  child: _Panel(
                    title: 'الإيرادات آخر 7 أيام',
                    subtitle: 'اليوم مقابل أمس • هذا الأسبوع مقابل الماضي',
                    child: Column(
                      children: [
                        SizedBox(
                          height: 220,
                          child: _WeeklyRevenueChart(values: summary.last7Days),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _KpiLine(
                                label: 'اليوم',
                                value:
                                    '${money.format(summary.todayRevenue)} ر.س',
                                note: _trendText(
                                  summary.todayRevenue,
                                  summary.yesterdayRevenue,
                                ),
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _KpiLine(
                                label: 'هذا الأسبوع',
                                value:
                                    '${money.format(summary.thisWeekRevenue)} ر.س',
                                note: _trendText(
                                  summary.thisWeekRevenue,
                                  summary.lastWeekRevenue,
                                ),
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 16),
                Flexible(
                  flex: 4,
                  fit: FlexFit.loose,
                  child: Column(
                    children: [
                      _Panel(
                        title: 'تشغيل اليوم',
                        subtitle: 'حالة التشغيل الحالية للمحل',
                        child: Column(
                          children: [
                            _StatusRow(
                              label: 'عقود مفتوحة',
                              value: '${summary.openCount}',
                              color: Colors.blue,
                              icon: Icons.lock_open_rounded,
                            ),
                            _StatusRow(
                              label: 'أُغلقت اليوم',
                              value: '${summary.closedTodayCount}',
                              color: Colors.green,
                              icon: Icons.task_alt_rounded,
                            ),
                            _StatusRow(
                              label: 'تحتاج تحصيل',
                              value: '${summary.deferredCount}',
                              color: Colors.orange,
                              icon: Icons.payments_outlined,
                            ),
                            _StatusRow(
                              label: 'متأخرة',
                              value: '${summary.overdueCount}',
                              color: Colors.red,
                              icon: Icons.priority_high_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Panel(
                        title: 'ملخص سريع للإدارة',
                        subtitle: 'نظرة تنفيذية جاهزة للقرار',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InsightChip(
                              icon: Icons.people_alt_outlined,
                              color: Colors.indigo,
                              text:
                                  'العملاء: ${stats.clients} • المعدات: ${stats.equipment}',
                            ),
                            const SizedBox(height: 10),
                            _InsightChip(
                              icon: Icons.bar_chart_rounded,
                              color: Colors.purple,
                              text:
                                  'إجمالي الإيراد المسجل: ${money.format(stats.revenue)} ر.س',
                            ),
                            const SizedBox(height: 10),
                            _InsightChip(
                              icon: Icons.auto_graph_rounded,
                              color: Colors.teal,
                              text: _buildInsightText(summary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 950;
            return Flex(
              direction: isWide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  flex: 4,
                  fit: FlexFit.loose,
                  child: _Panel(
                    title: 'أفضل المعدات دخلًا',
                    subtitle: 'اعتمادًا على العقود الأخيرة داخل النظام',
                    child: Column(
                      children: summary.topEquipment.map((item) {
                        final max = summary.topEquipment.isEmpty
                            ? 1.0
                            : summary.topEquipment.first.amount;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _TopItemRow(
                            title: item.label,
                            amount: '${money.format(item.amount)} ر.س',
                            ratio: max == 0 ? 0 : item.amount / max,
                            color: Colors.deepPurple,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 16),
                Flexible(
                  flex: 4,
                  fit: FlexFit.loose,
                  child: _Panel(
                    title: 'أفضل العملاء إيرادًا',
                    subtitle: 'من خلال العقود والدفعات المرتبطة',
                    child: Column(
                      children: summary.topClients.map((item) {
                        final max = summary.topClients.isEmpty
                            ? 1.0
                            : summary.topClients.first.amount;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _TopItemRow(
                            title: item.label,
                            amount: '${money.format(item.amount)} ر.س',
                            ratio: max == 0 ? 0 : item.amount / max,
                            color: Colors.indigo,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _KpiLine extends StatelessWidget {
  const _KpiLine({
    required this.label,
    required this.value,
    required this.note,
    required this.color,
  });

  final String label;
  final String value;
  final String note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(note, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightChip extends StatelessWidget {
  const _InsightChip({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _TopItemRow extends StatelessWidget {
  const _TopItemRow({
    required this.title,
    required this.amount,
    required this.ratio,
    required this.color,
  });

  final String title;
  final String amount;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final safeRatio = ratio.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Text(amount, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: safeRatio,
            backgroundColor: color.withOpacity(0.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _WeeklyRevenueChart extends StatelessWidget {
  const _WeeklyRevenueChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final labels = List.generate(7, (i) {
      final dt = DateTime.now().subtract(Duration(days: 6 - i));
      return DateFormat('E', 'ar').format(dt);
    });

    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            size: const Size(double.infinity, 180),
            painter: _LineChartPainter(
              values: values,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels
              .map((e) => Expanded(
                    child: Center(
                      child: Text(
                        e,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 1; i <= 4; i++) {
      final y = size.height * (i / 5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.isEmpty) return;
    final maxValue = values.reduce(math.max);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final stepX = values.length == 1 ? 0.0 : size.width / (values.length - 1);

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final normalized = values[i] / safeMax;
      final y = size.height - (normalized * (size.height - 12)) - 6;
      points.add(Offset(i * stepX, y));
    }

    final areaPath = Path()..moveTo(points.first.dx, size.height);
    for (final point in points) {
      areaPath.lineTo(point.dx, point.dy);
    }
    areaPath.lineTo(points.last.dx, size.height);
    areaPath.close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withOpacity(0.24),
          color.withOpacity(0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(areaPath, areaPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final current = points[i];
      final mid = Offset((prev.dx + current.dx) / 2, (prev.dy + current.dy) / 2);
      linePath.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    linePath.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = color;
    for (final point in points) {
      canvas.drawCircle(point, 4.5, Paint()..color = Colors.white);
      canvas.drawCircle(point, 3.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

class _AdminInstantAlertsPanel extends StatefulWidget {
  const _AdminInstantAlertsPanel({required this.summary});

  final _AdminDashboardSummary summary;

  @override
  State<_AdminInstantAlertsPanel> createState() =>
      _AdminInstantAlertsPanelState();
}

class _AdminInstantAlertsPanelState extends State<_AdminInstantAlertsPanel> {
  Timer? _timer;
  bool _loading = true;
  String? _error;
  int _lastHighCount = 0;
  Map<String, dynamic> _summary = const {};
  List<Map<String, dynamic>> _alerts = const [];

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _fetch(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  Future<void> _fetch({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final dio = context.read<ApiClient>().dio;
      final res = await dio.get(
        '/settings/admin-alerts',
        queryParameters: {'days': 7, 'limit': 20},
      );
      
      // Check mounted after async operation
      if (!mounted) return;
      
      final data = (res.data is Map<String, dynamic>)
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};
      final payload = (data['data'] is Map<String, dynamic>)
          ? data['data'] as Map<String, dynamic>
          : <String, dynamic>{};
      final alerts = ((payload['alerts'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      final highCount = alerts
          .where((a) => (a['severity'] ?? '').toString() == 'high')
          .length;

      if (silent && mounted && highCount > _lastHighCount && _lastHighCount > 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('ظهرت حالات حرجة جديدة تحتاج مراجعة: $highCount'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }

      if (!mounted) return;
      setState(() {
        _summary = ((payload['summary'] as Map?)?.cast<String, dynamic>()) ?? {};
        _alerts = alerts;
        _lastHighCount = highCount;
        _loading = false;
        _error = null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message ?? 'تعذر جلب التنبيهات';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final high = _alerts.where((a) => a['severity'] == 'high').length;
    final medium = _alerts.where((a) => a['severity'] == 'medium').length;
    final reviewTotal = (_summary['needs_review_total'] ?? 0).toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.08),
            Theme.of(context).colorScheme.secondary.withOpacity(0.06),
          ],
        ),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.red.withOpacity(0.12),
                child: const Icon(Icons.notifications_active_outlined,
                    color: Colors.red),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'التنبيهات الفورية للإدارة',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'مباشرة من السجل والتشغيل اليومي مع تحديث تلقائي',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminMonitoringPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('اللوحة الكاملة'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniAlertStat(
                title: 'تحتاج مراجعة',
                value: reviewTotal,
                icon: Icons.warning_amber_rounded,
                color: Colors.orange,
              ),
              _MiniAlertStat(
                title: 'حرجة',
                value: '$high',
                icon: Icons.priority_high_rounded,
                color: Colors.red,
              ),
              _MiniAlertStat(
                title: 'متوسطة',
                value: '$medium',
                icon: Icons.error_outline,
                color: Colors.deepOrange,
              ),
              _MiniAlertStat(
                title: 'بدون سند',
                value: '${_summary['contracts_without_receipt'] ?? 0}',
                icon: Icons.receipt_long_outlined,
                color: Colors.indigo,
              ),
              _MiniAlertStat(
                title: 'متأخرة',
                value: '${widget.summary.overdueCount}',
                icon: Icons.schedule_send_outlined,
                color: Colors.redAccent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _InlineError(message: _error!, onRetry: _fetch)
          else if (_alerts.isEmpty)
            const _InlineEmpty(message: 'لا توجد تنبيهات فورية حالياً.')
          else
            ..._alerts.take(4).map((alert) => _AlertStrip(data: alert)),
        ],
      ),
    );
  }
}

class _MiniAlertStat extends StatelessWidget {
  const _MiniAlertStat({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _AlertStrip extends StatelessWidget {
  const _AlertStrip({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final severity = (data['severity'] ?? 'low').toString();
    final tone = severity == 'high'
        ? Colors.red
        : severity == 'medium'
            ? Colors.orange
            : Colors.blueGrey;
    final dt = _fmtDate(data['created_at']?.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: tone.withOpacity(0.12),
            child: Icon(Icons.notifications, color: tone, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['title'] ?? 'تنبيه').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  (data['subtitle'] ?? '').toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if ((data['details'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    (data['details'] ?? '').toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tone.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  severity == 'high'
                      ? 'حرج'
                      : severity == 'medium'
                          ? 'متوسط'
                          : 'منخفض',
                  style: TextStyle(color: tone, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Text(dt, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function({bool silent}) onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () => onRetry(silent: false),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _RentCard extends StatelessWidget {
  const _RentCard({required this.rent});
  final Rent rent;

  @override
  Widget build(BuildContext context) {
    final status = (rent.status ?? '').toString();
    final statusLabel = status == 'closed'
        ? 'مغلق'
        : status == 'cancelled'
            ? 'ملغي'
            : 'مفتوح';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(child: Text('#${rent.id}')),
        title: Text(
          '${rent.clientName ?? rent.clientId} • ${rent.equipmentName ?? rent.equipmentId}',
        ),
        subtitle: Text(
          'الحالة: $statusLabel   |   البداية: ${rent.startDatetime}',
        ),
        trailing: Text('${(rent.totalAmount ?? 0).toStringAsFixed(2)} ر.س'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RentDetailsPage(rentId: rent.id)),
          );
        },
      ),
    );
  }
}

class _TopAmountItem {
  const _TopAmountItem(this.label, this.amount);

  final String label;
  final double amount;
}

class _AdminDashboardSummary {
  const _AdminDashboardSummary({
    required this.openCount,
    required this.overdueCount,
    required this.deferredCount,
    required this.deferredAmount,
    required this.todayRevenue,
    required this.yesterdayRevenue,
    required this.thisWeekRevenue,
    required this.lastWeekRevenue,
    required this.closedTodayCount,
    required this.last7Days,
    required this.topEquipment,
    required this.topClients,
  });

  final int openCount;
  final int overdueCount;
  final int deferredCount;
  final double deferredAmount;
  final double todayRevenue;
  final double yesterdayRevenue;
  final double thisWeekRevenue;
  final double lastWeekRevenue;
  final int closedTodayCount;
  final List<double> last7Days;
  final List<_TopAmountItem> topEquipment;
  final List<_TopAmountItem> topClients;

  static DateTime? _parse(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static double _cashValue(Rent rent) {
    final closing = rent.closingPaidAmount ?? 0;
    if (closing > 0) return closing;
    final paid = rent.paidAmount ?? 0;
    if ((rent.status ?? '').toLowerCase() == 'closed' && paid > 0) return paid;
    return 0;
  }

  static bool _isOverdue(Rent rent, DateTime now) {
    if ((rent.status ?? '').toLowerCase() != 'open') return false;
    final end = _parse(rent.endDatetime) ?? _parse(rent.startDatetime);
    if (end == null) return false;
    return end.isBefore(now);
  }

  static double _remaining(Rent rent) {
    final remaining = rent.remainingAmount;
    if (remaining != null && remaining > 0) return remaining;
    final total = rent.totalAmount ?? 0;
    final paid = rent.paidAmount ?? rent.closingPaidAmount ?? 0;
    final diff = total - paid;
    return diff > 0 ? diff : 0;
  }

  factory _AdminDashboardSummary.fromRents(List<Rent> rents) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final lastWeekStart = weekStart.subtract(const Duration(days: 7));
    final last7Keys = List.generate(
      7,
      (i) => todayStart.subtract(Duration(days: 6 - i)),
    );
    final revenueMap = <String, double>{
      for (final day in last7Keys) DateFormat('yyyy-MM-dd').format(day): 0,
    };

    var openCount = 0;
    var overdueCount = 0;
    var deferredCount = 0;
    var deferredAmount = 0.0;
    var todayRevenue = 0.0;
    var yesterdayRevenue = 0.0;
    var thisWeekRevenue = 0.0;
    var lastWeekRevenue = 0.0;
    var closedTodayCount = 0;
    final equipmentTotals = <String, double>{};
    final clientTotals = <String, double>{};

    for (final rent in rents) {
      final status = (rent.status ?? '').toLowerCase();
      final closeDate = _parse(rent.closedAt);
      final cash = _cashValue(rent);
      final remaining = _remaining(rent);

      if (status == 'open') openCount++;
      if (_isOverdue(rent, now)) overdueCount++;

      if (status == 'closed' && remaining > 0.009) {
        deferredCount++;
        deferredAmount += remaining;
      }

      if (closeDate != null) {
        if (_sameDay(closeDate, todayStart)) {
          closedTodayCount++;
          todayRevenue += cash;
        }
        if (_sameDay(closeDate, yesterdayStart)) {
          yesterdayRevenue += cash;
        }
        if (!closeDate.isBefore(weekStart) && closeDate.isBefore(todayStart.add(const Duration(days: 1)))) {
          thisWeekRevenue += cash;
        }
        if (!closeDate.isBefore(lastWeekStart) && closeDate.isBefore(weekStart)) {
          lastWeekRevenue += cash;
        }
        final key = DateFormat('yyyy-MM-dd').format(DateTime(closeDate.year, closeDate.month, closeDate.day));
        if (revenueMap.containsKey(key)) {
          revenueMap[key] = (revenueMap[key] ?? 0) + cash;
        }
      }

      final amountBasis = (rent.totalAmount ?? cash);
      if (amountBasis > 0) {
        final equipment = (rent.equipmentName ?? 'معدة #${rent.equipmentId}').trim();
        final client = (rent.clientName ?? 'عميل #${rent.clientId}').trim();
        equipmentTotals[equipment] = (equipmentTotals[equipment] ?? 0) + amountBasis;
        clientTotals[client] = (clientTotals[client] ?? 0) + amountBasis;
      }
    }

    List<_TopAmountItem> topFromMap(Map<String, double> source) {
      final items = source.entries
          .map((e) => _TopAmountItem(e.key, e.value))
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
      return items.take(5).toList();
    }

    return _AdminDashboardSummary(
      openCount: openCount,
      overdueCount: overdueCount,
      deferredCount: deferredCount,
      deferredAmount: deferredAmount,
      todayRevenue: todayRevenue,
      yesterdayRevenue: yesterdayRevenue,
      thisWeekRevenue: thisWeekRevenue,
      lastWeekRevenue: lastWeekRevenue,
      closedTodayCount: closedTodayCount,
      last7Days: last7Keys
          .map((d) => revenueMap[DateFormat('yyyy-MM-dd').format(d)] ?? 0)
          .toList(),
      topEquipment: topFromMap(equipmentTotals),
      topClients: topFromMap(clientTotals),
    );
  }
}

class _EmployeeRentSummary {
  const _EmployeeRentSummary({
    required this.openCount,
    required this.overdueCount,
    required this.deferredCount,
    required this.deferredAmount,
  });

  final int openCount;
  final int overdueCount;
  final int deferredCount;
  final double deferredAmount;

  static DateTime? _parse(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }

  static bool _isOverdue(Rent rent) {
    final status = (rent.status ?? '').toString().toLowerCase();
    if (status != 'open') return false;
    final start = _parse(rent.startDatetime.toString());
    if (start == null) return false;
    return DateTime.now().difference(start).inHours >= 24;
  }

  static double _remaining(Rent rent) {
    final total = rent.totalAmount ?? 0;
    final remaining = rent.remainingAmount;
    if (remaining != null) return remaining;
    final paid = rent.paidAmount ?? rent.closingPaidAmount ?? 0;
    final diff = total - paid;
    return diff > 0 ? diff : 0;
  }

  factory _EmployeeRentSummary.fromRents(List<Rent> rents) {
    var openCount = 0;
    var overdueCount = 0;
    var deferredCount = 0;
    var deferredAmount = 0.0;

    for (final rent in rents) {
      final status = (rent.status ?? '').toString().toLowerCase();
      if (status == 'open') openCount++;
      if (_isOverdue(rent)) overdueCount++;
      if (status == 'closed') {
        final remaining = _remaining(rent);
        if (remaining > 0.009) {
          deferredCount++;
          deferredAmount += remaining;
        }
      }
    }

    return _EmployeeRentSummary(
      openCount: openCount,
      overdueCount: overdueCount,
      deferredCount: deferredCount,
      deferredAmount: deferredAmount,
    );
  }
}

class _EmployeeAlertBanner extends StatelessWidget {
  const _EmployeeAlertBanner({required this.summary, this.onOpenRents});

  final _EmployeeRentSummary summary;
  final VoidCallback? onOpenRents;

  @override
  Widget build(BuildContext context) {
    final danger = summary.overdueCount > 0;
    final tone = danger ? Colors.red : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(
            danger ? Icons.notifications_active_outlined : Icons.info_outline,
            color: tone,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  danger
                      ? 'لديك عقود متأخرة تحتاج متابعة'
                      : 'يوجد تسديدات مؤجلة تحتاج متابعة',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'المفتوحة: ${summary.openCount} • المتأخرة: ${summary.overdueCount} • المؤجلة: ${summary.deferredCount}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (onOpenRents != null)
            FilledButton.icon(
              onPressed: onOpenRents,
              icon: const Icon(Icons.open_in_new),
              label: const Text('فتح العقود'),
            ),
        ],
      ),
    );
  }
}

String _trendText(double current, double previous) {
  if (previous == 0 && current == 0) return 'بدون تغير';
  if (previous == 0 && current > 0) return 'جديد';
  final change = ((current - previous) / previous) * 100;
  final sign = change >= 0 ? '+' : '';
  return '$sign${change.toStringAsFixed(0)}%';
}

String _buildInsightText(_AdminDashboardSummary summary) {
  if (summary.todayRevenue > summary.yesterdayRevenue && summary.overdueCount == 0) {
    return 'التحصيل اليوم أفضل من أمس ولا توجد حالات تأخير ظاهرة.';
  }
  if (summary.overdueCount > 0 && summary.todayRevenue <= summary.yesterdayRevenue) {
    return 'يوجد ضغط تشغيلي: العقود المتأخرة مرتفعة والتحصيل اليوم أقل من أمس.';
  }
  if (summary.deferredCount > 0) {
    return 'هناك ذمم تحتاج متابعة: ${summary.deferredCount} عقد ما زال عليه رصيد.';
  }
  return 'وضع التشغيل مستقر حاليًا مع حاجة لمتابعة التنبيهات اليومية فقط.';
}

String _fmtDate(String? value) {
  if (value == null || value.isEmpty) return '-';
  final dt = DateTime.tryParse(value.replaceFirst(' ', 'T'));
  if (dt == null) return value;
  return DateFormat('yyyy/MM/dd - hh:mm a').format(dt);
}
