import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';

class TeamMonitoringPage extends StatefulWidget {
  const TeamMonitoringPage({super.key});

  @override
  State<TeamMonitoringPage> createState() => _TeamMonitoringPageState();
}

class _TeamMonitoringPageState extends State<TeamMonitoringPage> {
  late Future<Map<String, dynamic>> _future;
  int _days = 14;
  String _sort = 'score';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final dio = context.read<ApiClient>().dio;
    final res = await dio.get('/settings/team-monitoring', queryParameters: {
      'days': _days,
      'sort': _sort,
    });
    final data = res.data;
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return (data['data'] as Map).cast<String, dynamic>();
    }
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'مراقبة الموظفين',
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
                PopupMenuButton<String>(
                  tooltip: 'ترتيب',
                  onSelected: (value) {
                    setState(() {
                      _sort = value;
                      _future = _load();
                    });
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'score', child: Text('الترتيب حسب التقييم')),
                    PopupMenuItem(value: 'collections', child: Text('الترتيب حسب التحصيل')),
                    PopupMenuItem(value: 'followups', child: Text('الترتيب حسب المتابعات')),
                    PopupMenuItem(value: 'issues', child: Text('الترتيب حسب الملاحظات')),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.sort),
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
                  return Center(child: Text('تعذر تحميل مراقبة الموظفين\n${snapshot.error}'));
                }
                final data = snapshot.data ?? <String, dynamic>{};
                final summary = ((data['summary'] as Map?)?.cast<String, dynamic>()) ?? {};
                final users = ((data['users'] as List?) ?? const [])
                    .whereType<Map>()
                    .map((e) => e.cast<String, dynamic>())
                    .toList();

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _MonitoringSummary(summary: summary),
                      const SizedBox(height: 16),
                      _SectionHeader(
                        title: 'ترتيب الموظفين',
                        subtitle: 'أفضل أداء وأعلى تحصيل وأهم من يحتاج متابعة',
                        icon: Icons.emoji_events_outlined,
                      ),
                      const SizedBox(height: 10),
                      if (users.isNotEmpty) _RankingStrip(users: users, sort: _sort),
                      if (users.isNotEmpty) const SizedBox(height: 16),
                      _SectionHeader(
                        title: 'أداء الموظفين',
                        subtitle: 'مغلقات العقود والتحصيل والمتابعات وآخر النشاط',
                        icon: Icons.manage_accounts_outlined,
                      ),
                      const SizedBox(height: 10),
                      if (users.isEmpty)
                        const _EmptyCard(message: 'لا توجد بيانات كافية في هذه الفترة.')
                      else
                        ...users.asMap().entries.map((entry) => _UserPerformanceCard(data: entry.value, rank: entry.key + 1)),
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

class _MonitoringSummary extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _MonitoringSummary({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cards = [
      {'title': 'الموظفون النشطون', 'value': summary['active_users'], 'icon': Icons.badge_outlined},
      {'title': 'إجمالي التحصيل', 'value': _fmt(summary['total_collections']), 'icon': Icons.payments_outlined},
      {'title': 'إجمالي المتابعات', 'value': summary['total_followups'], 'icon': Icons.call_outlined},
      {'title': 'حالات تحتاج متابعة', 'value': summary['total_issues'], 'icon': Icons.warning_amber_rounded},
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
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
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  item['title'] as String,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RankingStrip extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final String sort;
  const _RankingStrip({required this.users, required this.sort});

  @override
  Widget build(BuildContext context) {
    final topUsers = users.take(3).toList();
    final weakUser = users.isNotEmpty ? users.last : null;

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < topUsers.length; i++) ...[
              Expanded(
                child: _rankHighlightCard(
                  context,
                  rank: i + 1,
                  user: topUsers[i],
                ),
              ),
              if (i != topUsers.length - 1) const SizedBox(width: 10),
            ],
          ],
        ),
        if (weakUser != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.red.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_down_rounded, color: Colors.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('يحتاج متابعة أكثر', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        '${weakUser['username'] ?? 'مستخدم'} — ${_sortLabel(sort)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Text(
                  _sortValue(weakUser, sort),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _rankHighlightCard(BuildContext context, {required int rank, required Map<String, dynamic> user}) {
    final medalColor = rank == 1 ? Colors.amber : (rank == 2 ? Colors.blueGrey : Colors.brown);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: medalColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: medalColor.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: medalColor.withOpacity(0.18),
                child: Text('$rank', style: TextStyle(color: medalColor, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (user['username'] ?? 'مستخدم').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _sortValue(user, sort),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(_sortLabel(sort), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Text(
            'التقييم ${((user['score'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)} / 100',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _UserPerformanceCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final int rank;
  const _UserPerformanceCard({required this.data, required this.rank});

  @override
  Widget build(BuildContext context) {
    final score = (data['score'] as num?)?.toDouble() ?? 0;
    final issueCount = (data['issue_count'] as num?)?.toInt() ?? 0;
    final collection = _fmt(data['collection_total']);
    final status = _status(score, issueCount);
    final statusColor = _statusColor(status);
    final progress = (score / 100).clamp(0, 1).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  child: Text(
                    ((data['username'] ?? '-') as String).trim().isNotEmpty
                        ? ((data['username'] as String).trim().substring(0, 1))
                        : '-',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (data['username'] ?? 'مستخدم').toString(),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'آخر نشاط: ${_formatDateTime(data['last_activity_at'])}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '#$rank',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: progress, minHeight: 10),
            ),
            const SizedBox(height: 8),
            Text('التقييم: ${score.toStringAsFixed(0)} / 100', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metricChip('عقود مغلقة', '${data['closed_rents'] ?? 0}', Icons.task_alt_outlined),
                _metricChip('تحصيل', collection, Icons.payments_outlined),
                _metricChip('متابعات', '${data['followups'] ?? 0}', Icons.phone_in_talk_outlined),
                _metricChip('سندات ملغاة', '${data['voided_payments'] ?? 0}', Icons.receipt_long_outlined),
                _metricChip('ملاحظات', '$issueCount', Icons.warning_amber_rounded),
                _metricChip('إغلاقات دوام', '${data['shift_closings'] ?? 0}', Icons.point_of_sale_outlined),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _infoTile(
                    context,
                    title: 'احتساب يدوي',
                    value: '${data['manual_pricing_count'] ?? 0}',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _infoTile(
                    context,
                    title: 'تجاهل سند',
                    value: '${data['receipt_skipped_count'] ?? 0}',
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _infoTile(
                    context,
                    title: 'فروقات صندوق',
                    value: '${data['shift_differences'] ?? 0}',
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(value),
        ],
      ),
    );
  }

  Widget _infoTile(BuildContext context, {required String title, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  String _status(double score, int issues) {
    if (score >= 80 && issues <= 1) return 'ممتاز';
    if (score >= 60 && issues <= 3) return 'جيد';
    return 'يحتاج متابعة';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ممتاز':
        return Colors.green;
      case 'جيد':
        return Colors.orange;
      default:
        return Colors.red;
    }
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
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
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
        padding: const EdgeInsets.all(20),
        child: Center(child: Text(message)),
      ),
    );
  }
}

String _fmt(dynamic value) {
  final n = (value as num?)?.toDouble() ?? double.tryParse('${value ?? 0}') ?? 0;
  return n.toStringAsFixed(n >= 1000 ? 0 : 2);
}

String _formatDateTime(dynamic value) {
  final raw = (value ?? '').toString().trim();
  if (raw.isEmpty) return 'لا يوجد';
  final dt = DateTime.tryParse(raw.replaceAll(' ', 'T'));
  if (dt == null) return raw;
  return DateFormat('yyyy/MM/dd - hh:mm a').format(dt);
}


String _sortLabel(String sort) {
  switch (sort) {
    case 'collections':
      return 'الأعلى تحصيلاً';
    case 'followups':
      return 'الأكثر متابعة';
    case 'issues':
      return 'الأكثر ملاحظات';
    default:
      return 'الأعلى تقييماً';
  }
}

String _sortValue(Map<String, dynamic> user, String sort) {
  switch (sort) {
    case 'collections':
      return _fmt(user['collection_total']);
    case 'followups':
      return '${user['followups'] ?? 0}';
    case 'issues':
      return '${user['issue_count'] ?? 0}';
    default:
      return ((user['score'] as num?)?.toDouble() ?? 0).toStringAsFixed(0);
  }
}
