import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/features/rents/presentation/ui/rent_details_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<Map<String, dynamic>> _alerts = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = false;
  int _days = 14;

  String? _filterSeverity;
  String? _filterCategory;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final dio = context.read<ApiClient>().dio;
      final res = await dio.get('/settings/admin-alerts', queryParameters: {
        'days': _days,
        'limit': 100,
      });
      if (res.data is Map && res.data['success'] == true) {
        final data = res.data['data'] as Map<String, dynamic>? ?? {};
        final rawAlerts = (data['alerts'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        _summary = data['summary'] as Map<String, dynamic>? ?? {};

        var filtered = rawAlerts;
        if (_filterSeverity != null) {
          filtered = filtered.where((a) => a['severity']?.toString() == _filterSeverity).toList();
        }
        if (_filterCategory != null) {
          filtered = filtered.where((a) => a['category']?.toString() == _filterCategory).toList();
        }

        setState(() {
          _alerts.clear();
          _alerts.addAll(filtered);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل التنبيهات: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    await _loadAlerts();
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'high': return Colors.red.shade700;
      case 'medium': return Colors.orange.shade700;
      case 'low': return Colors.blue.shade600;
      default: return Colors.grey;
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'high': return Icons.error;
      case 'medium': return Icons.warning_amber_rounded;
      case 'low': return Icons.info_outline;
      default: return Icons.notifications;
    }
  }

  String _sevLabel(String sev) {
    switch (sev) {
      case 'high': return 'عالي';
      case 'medium': return 'متوسط';
      case 'low': return 'منخفض';
      default: return sev;
    }
  }

  String _catLabel(String cat) {
    switch (cat) {
      case 'receipt': return 'سند قبض';
      case 'pricing': return 'تسعير';
      case 'shift': return 'وردية';
      case 'payment': return 'مدفوعات';
      default: return cat;
    }
  }

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw.replaceAll(' ', 'T'));
    if (dt == null) return raw;
    return DateFormat('yyyy/MM/dd - hh:mm a', 'en').format(dt);
  }

  void _handleAlertTap(Map<String, dynamic> alert) {
    final entity = alert['entity']?.toString().toLowerCase();
    final entityIdStr = alert['entity_id']?.toString();
    final entityId = int.tryParse(entityIdStr ?? '');
    if (entityId == null || entityId <= 0) return;

    if (entity == 'rent') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RentDetailsPage(rentId: entityId)),
      );
    } else if (entity == 'payment') {
      final meta = alert['meta'];
      if (meta is Map && meta['rent_id'] != null) {
        final rId = int.tryParse(meta['rent_id'].toString());
        if (rId != null && rId > 0) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RentDetailsPage(rentId: rId)),
          );
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى فتح العقد المرتبط لعرض السند')),
      );
    } else if (entity == 'shift_closing') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('إغلاق وردية #$entityId')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'نظام التنبيهات',
        centerTitle: true,
        showShadow: true,
      ),
      body: Column(
        children: [
          _buildFilterBar(theme),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      children: [
                        _buildSummarySection(theme),
                        const SizedBox(height: 12),
                        ..._alerts.map((alert) => _buildAlertCard(alert, theme)),
                        if (_alerts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Center(child: Text('لا توجد تنبيهات', style: TextStyle(fontSize: 16))),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(ThemeData theme) {
    final cards = [
      {'title': 'تحتاج مراجعة', 'value': _summary['needs_review_total'], 'color': Colors.red},
      {'title': 'بدون سند', 'value': _summary['contracts_without_receipt'], 'color': Colors.orange},
      {'title': 'احتساب يدوي', 'value': _summary['manual_hour_pricing'], 'color': Colors.amber.shade700},
      {'title': 'فروقات دوام', 'value': _summary['shift_differences'], 'color': Colors.blue},
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = cards[index];
          return SizedBox(
            width: 140,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: (item['color'] as Color).withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['value'] ?? 0}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: item['color'] as Color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(item['title'] as String, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                for (final d in const [7, 14, 30])
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text('آخر $d يوم'),
                      selected: _days == d,
                      onSelected: (_) {
                        setState(() => _days = d);
                        _loadAlerts();
                      },
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'تحديث',
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterSeverity,
                    decoration: const InputDecoration(
                      labelText: 'الخطورة',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('الكل')),
                      DropdownMenuItem(value: 'high', child: Text('عالي')),
                      DropdownMenuItem(value: 'medium', child: Text('متوسط')),
                      DropdownMenuItem(value: 'low', child: Text('منخفض')),
                    ],
                    onChanged: (v) {
                      setState(() => _filterSeverity = v);
                      _loadAlerts();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterCategory,
                    decoration: const InputDecoration(
                      labelText: 'التصنيف',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('الكل')),
                      DropdownMenuItem(value: 'receipt', child: Text('سند قبض')),
                      DropdownMenuItem(value: 'pricing', child: Text('تسعير')),
                      DropdownMenuItem(value: 'shift', child: Text('وردية')),
                      DropdownMenuItem(value: 'payment', child: Text('مدفوعات')),
                    ],
                    onChanged: (v) {
                      setState(() => _filterCategory = v);
                      _loadAlerts();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert, ThemeData theme) {
    final severity = (alert['severity'] ?? 'low').toString();
    final color = _severityColor(severity);
    final title = alert['title']?.toString() ?? '';
    final subtitle = alert['subtitle']?.toString() ?? '';
    final details = alert['details']?.toString();
    final category = (alert['category'] ?? '').toString();
    final createdAt = _fmtDate(alert['created_at']?.toString());

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleAlertTap(alert),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: color.withOpacity(0.15),
                    child: Icon(_severityIcon(severity), color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _sevLabel(severity),
                                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _catLabel(category),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(createdAt, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                ],
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(subtitle, style: const TextStyle(fontSize: 13)),
              ],
              if (details != null && details.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      Expanded(child: Text(details, style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
