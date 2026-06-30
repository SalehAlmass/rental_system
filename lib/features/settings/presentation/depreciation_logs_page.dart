import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/core/widgets/permission_guard.dart';
import 'package:rental_app/features/profile/profile_cubit.dart';

class DepreciationLogsPage extends StatefulWidget {
  const DepreciationLogsPage({super.key});

  @override
  State<DepreciationLogsPage> createState() => _DepreciationLogsPageState();
}

class _DepreciationLogsPageState extends State<DepreciationLogsPage> {
  final int _limit = 20;
  int _offset = 0;
  int _total = 0;
  bool _isLoading = false;
  List<dynamic> _logs = [];
  List<dynamic> _equipmentList = [];

  // Filter values
  String? _fromMonth; // YYYY-MM
  String? _toMonth;   // YYYY-MM
  int? _selectedEquipmentId;
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _loadEquipment();
    _loadLogs();
  }

  Future<void> _loadEquipment() async {
    try {
      final dio = context.read<ApiClient>().dio;
      final res = await dio.get('/equipment');
      if (res.data is List) {
        setState(() {
          _equipmentList = res.data;
        });
      }
    } catch (_) {
      // Omit errors silently
    }
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);

    try {
      final dio = context.read<ApiClient>().dio;
      final Map<String, dynamic> params = {
        'limit': _limit,
        'offset': _offset,
      };

      if (_fromMonth != null && _fromMonth!.isNotEmpty) params['from'] = _fromMonth;
      if (_toMonth != null && _toMonth!.isNotEmpty) params['to'] = _toMonth;
      if (_selectedEquipmentId != null) params['equipment_id'] = _selectedEquipmentId;
      if (_selectedType != null) params['depreciation_type'] = _selectedType;

      final res = await dio.get('/depreciation-entries', queryParameters: params);
      if (res.data is Map && res.data['success'] == true) {
        setState(() {
          _logs = res.data['data'] as List? ?? [];
          _total = res.data['total'] as int? ?? 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل سجل الإهلاك: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _fromMonth = null;
      _toMonth = null;
      _selectedEquipmentId = null;
      _selectedType = null;
      _offset = 0;
    });
    _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pstate = context.read<ProfileCubit>().state;
    final hasAccess = pstate.hasScreenPermission('equipment') || pstate.hasScreenPermission('reports');

    if (!hasAccess) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: const CustomAppBar(title: 'سجل إهلاك الأصول', centerTitle: true),
          body: const Center(
            child: Text(
              'عذراً، ليس لديك الصلاحية الكافية للوصول إلى هذه الشاشة.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const CustomAppBar(
          title: 'سجل إهلاك الأصول (الاستهلاك)',
          centerTitle: true,
          showShadow: true,
        ),
        body: Column(
          children: [
            // Filters Header
            Card(
              margin: const EdgeInsets.all(12),
              elevation: 2,
              child: ExpansionTile(
                leading: Icon(Icons.filter_list, color: theme.colorScheme.primary),
                title: const Text('فلاتر البحث والتصفية', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('إجمالي سجلات الإهلاك: $_total'),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  Row(
                    children: [
                      // Equipment Dropdown
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selectedEquipmentId,
                          decoration: const InputDecoration(labelText: 'المعدة', border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('جميع المعدات')),
                            ..._equipmentList.map((e) {
                              final id = e['id'] is int
                                  ? e['id'] as int
                                  : int.tryParse(e['id']?.toString() ?? '') ?? 0;
                              return DropdownMenuItem(
                                value: id,
                                child: Text(e['name'].toString()),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedEquipmentId = val;
                              _offset = 0;
                            });
                            _loadLogs();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Type Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: const InputDecoration(labelText: 'نوع الإهلاك', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('جميع الأنواع')),
                            DropdownMenuItem(value: 'accounting', child: Text('إهلاك دفتري (محاسبي)')),
                            DropdownMenuItem(value: 'operational', child: Text('إهلاك تشغيلي (يومي)')),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedType = val;
                              _offset = 0;
                            });
                            _loadLogs();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Month Pickers
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'من شهر (YYYY-MM)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_month),
                          ),
                          controller: TextEditingController(text: _fromMonth),
                          onFieldSubmitted: (val) {
                            setState(() {
                              _fromMonth = val.trim();
                              _offset = 0;
                            });
                            _loadLogs();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'إلى شهر (YYYY-MM)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_month),
                          ),
                          controller: TextEditingController(text: _toMonth),
                          onFieldSubmitted: (val) {
                            setState(() {
                              _toMonth = val.trim();
                              _offset = 0;
                            });
                            _loadLogs();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('إعادة تعيين الفلاتر'),
                  ),
                ],
              ),
            ),
            // Logs View
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _logs.isEmpty
                      ? const Center(child: Text('لا توجد سجلات إهلاك مطابقة.'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            return _buildLogCard(log, theme);
                          },
                        ),
            ),
            // Pagination Footer
            if (_total > _limit) _buildPaginationFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(dynamic log, ThemeData theme) {
    final name = log['equipment_name'] ?? 'معدة مجهولة';
    final serial = log['equipment_serial'] ?? '';
    final month = log['depreciation_month'] ?? '';
    final type = log['depreciation_type'] ?? '';
    final amount = (log['amount'] as num?)?.toDouble() ?? 0.0;
    final bookBefore = (log['book_before'] as num?)?.toDouble() ?? 0.0;
    final bookAfter = (log['book_after'] as num?)?.toDouble() ?? 0.0;
    final date = log['created_at'] ?? '';

    final isAccounting = type == 'accounting';
    final typeColor = isAccounting ? Colors.indigo : Colors.teal;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  month,
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (serial.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'الرقم التسلسلي: $serial',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('نوع الإهلاك', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isAccounting ? 'دفتري / محاسبي' : 'تشغيلي / يومي',
                        style: TextStyle(color: typeColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('القيمة المهلكة', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      '${amount.toStringAsFixed(2)} ر.ي',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildValueIndicator('القيمة الدفترية قبل', bookBefore),
                const Icon(Icons.arrow_left, color: Colors.grey),
                _buildValueIndicator('القيمة الدفترية بعد', bookAfter),
              ],
            ),
            const Divider(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'تاريخ القيد: $date',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueIndicator(String title, double val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          '${val.toStringAsFixed(2)} ر.ي',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildPaginationFooter(ThemeData theme) {
    final int currentPage = (_offset / _limit).floor() + 1;
    final int totalPages = (_total / _limit).ceil();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: theme.cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: _offset > 0
                ? () {
                    setState(() => _offset = max(0, _offset - _limit));
                    _loadLogs();
                  }
                : null,
            child: const Text('السابق'),
          ),
          Text('صفحة $currentPage من $totalPages (الإجمالي: $_total)'),
          ElevatedButton(
            onPressed: (_offset + _limit) < _total
                ? () {
                    setState(() => _offset += _limit);
                    _loadLogs();
                  }
                : null,
            child: const Text('التالي'),
          ),
        ],
      ),
    );
  }
}
