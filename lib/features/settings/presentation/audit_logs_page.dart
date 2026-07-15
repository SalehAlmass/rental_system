import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  final int _limit = 20;
  int _page = 1;
  int _total = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  final List<dynamic> _logs = [];
  List<dynamic> _users = [];
  final _scrollController = ScrollController();
  String _sortBy = 'id';
  String _sortOrder = 'desc';

  // Filter values
  DateTime? _fromDate;
  DateTime? _toDate;
  int? _selectedUserId;
  String? _selectedEntity;
  String? _selectedAction;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _entities = [
    'user',
    'payment',
    'settings',
    'rent',
    'shift_closing',
    'equipment',
    'equipment_maintenance',
    'attendance',
  ];

  final List<String> _actions = [
    'login_success',
    'login_failed',
    'password_changed',
    'user_created',
    'user_updated',
    'role_changed',
    'permissions_changed',
    'user_activated',
    'user_deactivated',
    'user_deleted',
    'payment_created',
    'payment_updated',
    'payment_voided',
    'rent_created',
    'rent_updated',
    'rent_closed',
    'rent_cancelled',
    'shift_closed',
    'shift_difference_detected',
    'contract_closing_settings_updated',
    'backup_created',
    'backup_failed',
    'credit_warning_used',
    'credit_blocked',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadUsers();
    _loadLogs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadLogs();
    }
  }

  Future<void> _loadUsers() async {
    try {
      final dio = context.read<ApiClient>().dio;
      final res = await dio.get('/users');
      if (res.data is List) {
        setState(() {
          _users = res.data;
        });
      }
    } catch (_) {
    }
  }

  Future<void> _loadLogs({bool refresh = false}) async {
    if (_isLoading || (!_hasMore && !refresh)) return;
    setState(() => _isLoading = true);

    if (refresh) {
      _page = 1;
      _hasMore = true;
    }

    try {
      final dio = context.read<ApiClient>().dio;
      final Map<String, dynamic> params = {
        'limit': _limit,
        'page': _page,
      };

      if (_fromDate != null) {
        params['from'] = DateFormat('yyyy-MM-dd').format(_fromDate!);
      }
      if (_toDate != null) {
        params['to'] = DateFormat('yyyy-MM-dd').format(_toDate!);
      }
      if (_selectedUserId != null) {
        params['user_id'] = _selectedUserId;
      }
      if (_selectedEntity != null) {
        params['entity'] = _selectedEntity;
      }
      if (_selectedAction != null) {
        params['action'] = _selectedAction;
      }
      if (_searchController.text.trim().isNotEmpty) {
        params['search'] = _searchController.text.trim();
      }
      params['sort_by'] = _sortBy;
      params['sort_order'] = _sortOrder;

      final res = await dio.get('/audit-logs', queryParameters: params);
      if (res.data is Map && res.data['success'] == true) {
        final data = res.data['data'] as List? ?? [];
        final totalCount = res.data['total'] as int? ?? 0;
        setState(() {
          if (refresh) _logs.clear();
          _logs.addAll(data);
          _page++;
          _total = totalCount;
          _hasMore = _logs.length < totalCount;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل سجل التدقيق: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _resetFilters() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _selectedUserId = null;
      _selectedEntity = null;
      _selectedAction = null;
      _searchController.clear();
    });
    _loadLogs(refresh: true);
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      _loadLogs(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: const CustomAppBar(
          title: 'سجل التدقيق المالي والعمليات',
          centerTitle: true,
          showShadow: true,
        ),
        body: Column(
          children: [
            // ────── Filters Header ─────
            Card(
              margin: const EdgeInsets.all(12),
              elevation: 2,
              child: ExpansionTile(
                leading: Icon(Icons.filter_list, color: theme.colorScheme.primary),
                title: const Text('تصفية وفلترة السجلات', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('إجمالي السجلات المكتشفة: $_total'),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // Text Search
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'بحث نصي (الحدث، الوحدة، المستخدم)...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadLogs();
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) {
                      _loadLogs(refresh: true);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Dropdown Filters Row
                  Row(
                    children: [
                      // Entity
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedEntity,
                          decoration: const InputDecoration(labelText: 'الوحدة / الكيان', border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('جميع الوحدات')),
                            ..._entities.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedEntity = val;
                            });
                            _loadLogs(refresh: true);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Action
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedAction,
                          decoration: const InputDecoration(labelText: 'العملية', border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('جميع العمليات')),
                            ..._actions.map((a) => DropdownMenuItem(value: a, child: Text(a))),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedAction = val;
                            });
                            _loadLogs(refresh: true);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // User + Date filter
                  Row(
                    children: [
                      // User Dropdown if users are fetched, otherwise disabled text fields
                      Expanded(
                        child: _users.isNotEmpty
                            ? DropdownButtonFormField<int>(
                                value: _selectedUserId,
                                decoration: const InputDecoration(labelText: 'الموظف المسؤول', border: OutlineInputBorder()),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('جميع الموظفين')),
                                  ..._users.map((u) {
                                    final id = u['id'] is int
                                        ? u['id'] as int
                                        : int.tryParse(u['id']?.toString() ?? '') ?? 0;
                                    return DropdownMenuItem(
                                      value: id,
                                      child: Text(u['username'].toString()),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedUserId = val;
                                  });
                                  _loadLogs(refresh: true);
                                },
                              )
                            : TextField(
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'معرف المستخدم (ID)',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) {
                                  final parsed = int.tryParse(val);
                                  setState(() {
                                    _selectedUserId = parsed;
                                  });
                                  _loadLogs(refresh: true);
                                },
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Date range
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectDate(context, true),
                          icon: const Icon(Icons.date_range),
                          label: Text(_fromDate == null
                              ? 'من تاريخ'
                              : DateFormat('yyyy/MM/dd').format(_fromDate!)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectDate(context, false),
                          icon: const Icon(Icons.date_range),
                          label: Text(_toDate == null
                              ? 'إلى تاريخ'
                              : DateFormat('yyyy/MM/dd').format(_toDate!)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Reset Button
                  TextButton.icon(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('إعادة تعيين الفلاتر'),
                  ),
                ],
              ),
            ),
            _buildSortingBar(context),
            // ────── Logs List ─────
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadLogs(refresh: true),
                child: _logs.isEmpty && !_isLoading
                    ? ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(child: Text('لا توجد سجلات تدقيق مطابقة للفلاتر المحددة.')),
                        ],
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _logs.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _logs.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final log = _logs[index];
                          return _buildAuditLogCard(log, isDark, theme);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortingBar(BuildContext context) {
    final sortOptions = {
      'id': 'الترتيب الافتراضي',
      'created_at': 'تاريخ العملية',
      'user': 'المستخدم',
      'action': 'نوع العملية',
      'entity': 'الوحدة',
    };

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                _loadLogs(refresh: true);
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
              _loadLogs(refresh: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogCard(dynamic log, bool isDark, ThemeData theme) {
    final String action = log['action'] ?? '';
    final String entity = log['entity'] ?? '';
    final String entityId = log['entity_id']?.toString() ?? '';
    final String username = log['username'] ?? 'مستخدم مجهول';
    final String createdAt = log['created_at'] ?? '';

    // Choose color badge based on action type
    Color actionColor = Colors.grey;
    if (action.contains('created') || action.contains('activated')) {
      actionColor = Colors.green.shade600;
    } else if (action.contains('updated') || action.contains('changed')) {
      actionColor = Colors.blue.shade600;
    } else if (action.contains('deleted') || action.contains('voided') || action.contains('deactivated')) {
      actionColor = Colors.red.shade600;
    }

    final hasDetails = log['old_values'] != null || log['new_values'] != null || log['meta'] != null;

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: actionColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: actionColor),
                  ),
                  child: Text(
                    _translateAction(action),
                    style: TextStyle(color: actionColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Text(
                  _fmtDate(createdAt),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('المسؤول: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                const Icon(Icons.category_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('الكيان: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                Text('${_translateEntity(entity)} #$entityId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            if (hasDetails) ...[
              const Divider(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: () => _showDetailsDialog(log, theme),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('عرض تفاصيل القيم والمقارنة'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetailsDialog(dynamic log, ThemeData theme) {
    final oldVals = log['old_values'];
    final newVals = log['new_values'];
    final meta = log['meta'];
    final ip = log['ip_address']?.toString();
    final device = log['device']?.toString();
    var description = log['description']?.toString();

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('تفاصيل التدقيق للعملية #${log['id']}'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description != null && description.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.description_outlined, size: 18, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(child: Text(description, style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (ip != null && ip.isNotEmpty) ...[
                      Row(children: [
                        const Icon(Icons.language, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('IP: $ip', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      ]),
                      const SizedBox(height: 4),
                    ],
                    if (device != null && device.isNotEmpty) ...[
                      Row(children: [
                        const Icon(Icons.devices, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(child: Text(device, style: const TextStyle(fontSize: 12))),
                      ]),
                      const SizedBox(height: 12),
                    ],
                    if (oldVals != null || newVals != null) ...[
                      const Text(
                        'مقارنة تغييرات القيم:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                      ),
                      const SizedBox(height: 8),
                      _buildComparisonWidget(oldVals, newVals, theme),
                    ],
                    if (meta != null && meta.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'بيانات وصفية إضافية:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? Colors.grey.shade900
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          meta.toString(),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComparisonWidget(dynamic oldVal, dynamic newVal, ThemeData theme) {
    final Map<String, dynamic> oldMap = (oldVal is Map) ? oldVal.cast<String, dynamic>() : {};
    final Map<String, dynamic> newMap = (newVal is Map) ? newVal.cast<String, dynamic>() : {};

    // Get union of keys
    final Set<String> keys = {...oldMap.keys, ...newMap.keys};

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(1.2), // Field name
        1: FlexColumnWidth(1.8), // Old value
        2: FlexColumnWidth(1.8), // New value
      },
      children: [
        // Header
        TableRow(
          decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1)),
          children: const [
            Padding(padding: EdgeInsets.all(6), child: Text('الحقل', style: TextStyle(fontWeight: FontWeight.bold))),
            Padding(padding: EdgeInsets.all(6), child: Text('القيمة السابقة', style: TextStyle(fontWeight: FontWeight.bold))),
            Padding(padding: EdgeInsets.all(6), child: Text('القيمة الجديدة', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        // Rows
        for (final k in keys)
          if (oldMap[k]?.toString() != newMap[k]?.toString()) // only show changed fields
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(k, style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    oldMap[k]?.toString() ?? '-',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    newMap[k]?.toString() ?? '-',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
      ],
    );
  }

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw.replaceAll(' ', 'T'));
    if (dt == null) return raw;
    return DateFormat('yyyy/MM/dd - hh:mm a', 'en').format(dt);
  }

  String _translateAction(String action) {
    switch (action) {
      case 'login_success': return 'تم تسجيل الدخول بنجاح';
      case 'login_failed': return 'فشل تسجيل الدخول';
      case 'logout': return 'تم تسجيل الخروج';
      case 'session_created': return 'تم إنشاء جلسة دخول';
      case 'session_revoked': return 'تم إلغاء جلسة الدخول';
      case 'admin_force_logout': return 'تسجيل خروج قسري من المسؤول';
      case 'password_changed': return 'تم تغيير كلمة المرور';
      case 'backup_created': return 'تم إنشاء نسخة احتياطية';
      case 'backup_failed': return 'فشل إنشاء النسخة الاحتياطية';
      case 'backup_restored': return 'تم استعادة النسخة الاحتياطية';
      case 'backup_restore_failed': return 'فشل استعادة النسخة الاحتياطية';
      case 'credit_warning_used': return 'تم استخدام تجاوز الحد الائتماني';
      case 'credit_blocked': return 'تم منع إنشاء العقد بسبب تجاوز الحد الائتماني';
      case 'attendance_check_in': return 'تسجيل حضور';
      case 'attendance_check_out': return 'تسجيل انصراف';
      case 'payment_created': return 'تم إنشاء سند دفع';
      case 'payment_updated': return 'تم تحديث السند';
      case 'payment_voided': return 'تم إلغاء/إبطال السند';
      case 'rent_created': return 'تم إنشاء عقد تأجير';
      case 'rent_updated': return 'تم تحديث العقد';
      case 'rent_cancelled': return 'تم إلغاء العقد';
      case 'rent_closed': return 'تم إغلاق العقد';
      case 'user_created': return 'تم إنشاء مستخدم جديد';
      case 'user_updated': return 'تم تحديث بيانات المستخدم';
      case 'user_activated': return 'تم تفعيل حساب المستخدم';
      case 'user_deactivated': return 'تم تعطيل حساب المستخدم';
      case 'user_deleted': return 'تم حذف المستخدم';
      case 'role_changed': return 'تم تغيير دور المستخدم';
      case 'permissions_changed': return 'تم تعديل الصلاحيات المخصصة';
      case 'shift_closed': return 'تم إغلاق الوردية ماليًا';
      case 'shift_difference_detected': return 'تم رصد عجز أو فائض بالوردية';
      case 'contract_closing_settings_updated': return 'تم تحديث إعدادات إغلاق العقود';
      default: return action;
    }
  }

  String _translateEntity(String entity) {
    switch (entity.toLowerCase()) {
      case 'payment': return 'سند مالي';
      case 'rent': return 'عقد تأجير';
      case 'client': return 'عميل';
      case 'equipment': return 'معدة / أصل';
      case 'user': return 'مستخدم';
      case 'shift_closing': return 'إغلاق وردية';
      case 'app_settings': return 'إعدادات النظام';
      default: return entity;
    }
  }
}
