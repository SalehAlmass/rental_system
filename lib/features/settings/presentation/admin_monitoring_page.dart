import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/features/settings/presentation/admin_alert_receipt_guard.dart';

class AdminMonitoringPage extends StatefulWidget {
  const AdminMonitoringPage({super.key});

  @override
  State<AdminMonitoringPage> createState() => _AdminMonitoringPageState();
}

class _AdminMonitoringPageState extends State<AdminMonitoringPage> {
  late Future<Map<String, dynamic>> _future;
  int _days = 14;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final dio = context.read<ApiClient>().dio;
    final res = await dio.get('/settings/admin-alerts', queryParameters: {
      'days': _days,
      'limit': 60,
    });
    final data = (res.data is Map<String, dynamic>)
        ? res.data as Map<String, dynamic>
        : <String, dynamic>{};
    return (data['data'] is Map<String, dynamic>)
        ? data['data'] as Map<String, dynamic>
        : <String, dynamic>{};
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'التنبيهات وسجل التدقيق',
        centerTitle: true,
        showShadow: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final d in const [7, 14, 30])
                        ChoiceChip(
                          label: Text('آخر $d يوم'),
                          selected: _days == d,
                          onSelected: (_) {
                            setState(() {
                              _days = d;
                              _future = _load();
                            });
                          },
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'تحديث',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorView(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  );
                }
                final data = snapshot.data ?? <String, dynamic>{};
                final summary = ((data['summary'] as Map?)?.cast<String, dynamic>()) ?? {};
                final alerts = ((data['alerts'] as List?) ?? const [])
                    .whereType<Map>()
                    .map((e) => e.cast<String, dynamic>())
                    .toList();
                final audit = ((data['audit'] as List?) ?? const [])
                    .whereType<Map>()
                    .map((e) => e.cast<String, dynamic>())
                    .toList();

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _SummarySection(summary: summary),
                      const SizedBox(height: 16),
                      _SectionHeader(
                        title: 'تنبيهات تحتاج مراجعة',
                        subtitle: 'أهم العمليات التي تحتاج متابعة مباشرة من الإدارة',
                        icon: Icons.notifications_active_outlined,
                      ),
                      const SizedBox(height: 10),
                      if (alerts.isEmpty)
                        const _EmptyCard(message: 'لا توجد تنبيهات مهمة في هذه الفترة.')
                      else
                        ...alerts.map(
                          (alert) => AdminAlertReceiptGuard(
                            data: alert,
                            child: _AlertCard(data: alert),
                          ),
                        ),
                      const SizedBox(height: 16),
                      _SectionHeader(
                        title: 'آخر سجل تدقيق',
                        subtitle: 'يوضح من نفّذ العمليات ومتى تمت',
                        icon: Icons.fact_check_outlined,
                      ),
                      const SizedBox(height: 10),
                      if (audit.isEmpty)
                        const _EmptyCard(message: 'لا توجد سجلات تدقيق في هذه الفترة.')
                      else
                        ...audit.take(30).map((item) => _AuditCard(data: item)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _SummarySection({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cards = [
      {'title': 'تحتاج مراجعة', 'value': summary['needs_review_total'], 'icon': Icons.warning_amber_rounded},
      {'title': 'بدون سند', 'value': summary['contracts_without_receipt'], 'icon': Icons.receipt_long_outlined},
      {'title': 'احتساب يدوي', 'value': summary['manual_hour_pricing'], 'icon': Icons.calculate_outlined},
      {'title': 'فروقات دوام', 'value': summary['shift_differences'], 'icon': Icons.point_of_sale_outlined},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.65,
      ),
      itemBuilder: (context, index) {
        final item = cards[index];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(item['icon'] as IconData),
                Text(
                  '${item['value'] ?? 0}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  item['title'] as String,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _SectionHeader({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AlertCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final severity = (data['severity'] ?? 'low').toString();
    Color color;
    if (severity == 'high') {
      color = Colors.red;
    } else if (severity == 'medium') {
      color = Colors.orange;
    } else {
      color = Colors.blueGrey;
    }
    final createdAt = _fmtDate(data['created_at']?.toString());
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(Icons.notification_important_outlined, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data['title']?.toString() ?? 'تنبيه',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _severityLabel(severity),
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(data['subtitle']?.toString() ?? ''),
            const SizedBox(height: 6),
            Text(
              data['details']?.toString() ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16),
                const SizedBox(width: 6),
                Text(createdAt, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AuditCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final createdAt = _fmtDate(data['created_at']?.toString());
    final action = data['action']?.toString() ?? '';
    final username = data['username']?.toString() ?? 'مستخدم غير معروف';
    final entity = data['entity']?.toString() ?? '';
    final entityId = data['entity_id']?.toString() ?? '-';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: const CircleAvatar(child: Icon(Icons.verified_user_outlined)),
        title: Text(
          _actionLabel(action),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('$username • $entity #$entityId\n$createdAt'),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 12),
            Text(
              'تعذر تحميل البيانات',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

String _severityLabel(String severity) {
  switch (severity) {
    case 'high':
      return 'عالي';
    case 'medium':
      return 'متوسط';
    default:
      return 'منخفض';
  }
}

String _actionLabel(String action) {
  switch (action) {
    case 'rent_closed':
      return 'تم إغلاق عقد';
    case 'payment_created':
      return 'تم إنشاء سند';
    case 'payment_voided':
      return 'تم إلغاء سند';
    case 'shift_closed':
      return 'تم إغلاق دوام';
    case 'shift_difference_detected':
      return 'تم رصد فرق بالصندوق';
    case 'manual_hour_pricing_used':
      return 'تم استخدام احتساب خاص';
    case 'receipt_skipped_on_close':
      return 'تم تجاهل إنشاء السند';
    case 'contract_closing_settings_updated':
      return 'تم تحديث سياسة الإغلاق';
    default:
      return action;
  }
}

String _fmtDate(String? raw) {
  if (raw == null || raw.isEmpty) return '-';
  final dt = DateTime.tryParse(raw.replaceAll(' ', 'T'));
  if (dt == null) return raw;
  return DateFormat('yyyy/MM/dd - hh:mm a', 'en').format(dt);
}
