import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SystemHealthPage extends StatefulWidget {
  const SystemHealthPage({super.key});

  @override
  State<SystemHealthPage> createState() => _SystemHealthPageState();
}

class _SystemHealthPageState extends State<SystemHealthPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingHealth = true;
  bool _isLoadingIntegrity = true;
  bool _isLoadingErrors = true;
  
  Map<String, dynamic>? _healthData;
  List<dynamic> _integrityIssues = [];
  List<dynamic> _errorLogs = [];
  
  String? _healthError;
  String? _integrityError;
  String? _errorsError;

  // Error log filter
  String _errorFilter = 'all';
  Map<String, int> _errorCounts = {'total': 0, 'open': 0, 'resolved': 0};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHealthData();
    _loadIntegrityData();
    _loadErrorsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHealthData() async {
    setState(() {
      _isLoadingHealth = true;
      _healthError = null;
    });
    try {
      final dio = context.read<ApiClient>().dio;
      final res = await dio.get('system-health');
      if (res.data != null && res.data['success'] == true) {
        setState(() {
          _healthData = res.data['data'] as Map<String, dynamic>;
          _isLoadingHealth = false;
        });
      } else {
        setState(() {
          _healthError = res.data['error'] ?? 'فشل جلب بيانات حالة النظام';
          _isLoadingHealth = false;
        });
      }
    } catch (e) {
      final msg = e is DioException && e.response?.statusCode == 403
          ? 'لا تملك الصلاحية لعرض هذه البيانات'
          : 'خطأ في الاتصال بالخادم';
      setState(() {
        _healthError = '$msg: $e';
        _isLoadingHealth = false;
      });
    }
  }

  Future<void> _loadIntegrityData() async {
    setState(() {
      _isLoadingIntegrity = true;
      _integrityError = null;
    });
    try {
      final dio = context.read<ApiClient>().dio;
      final res = await dio.get('system-integrity');
      if (res.data != null && res.data['success'] == true) {
        setState(() {
          _integrityIssues = res.data['issues'] as List<dynamic>;
          _isLoadingIntegrity = false;
        });
      } else {
        setState(() {
          _integrityError = res.data['error'] ?? 'فشل إجراء فحص سلامة البيانات';
          _isLoadingIntegrity = false;
        });
      }
    } catch (e) {
      final msg = e is DioException && e.response?.statusCode == 403
          ? 'لا تملك الصلاحية لعرض هذه البيانات'
          : 'خطأ في الاتصال بالخادم';
      setState(() {
        _integrityError = '$msg: $e';
        _isLoadingIntegrity = false;
      });
    }
  }

  Future<void> _loadErrorsData() async {
    setState(() {
      _isLoadingErrors = true;
      _errorsError = null;
    });
    try {
      final dio = context.read<ApiClient>().dio;
      final params = <String, dynamic>{};
      if (_errorFilter != 'all') {
        params['status'] = _errorFilter;
      }
      final res = await dio.get('system-health/errors', queryParameters: params.isNotEmpty ? params : null);
      if (res.data != null && res.data['success'] == true) {
        setState(() {
          _errorLogs = res.data['data'] as List<dynamic>;
          if (res.data['counts'] != null) {
            _errorCounts = Map<String, int>.from(res.data['counts'] as Map);
          }
          _isLoadingErrors = false;
        });
      } else {
        setState(() {
          _errorsError = res.data['error'] ?? 'فشل جلب سجل أخطاء الخادم';
          _isLoadingErrors = false;
        });
      }
    } catch (e) {
      final msg = e is DioException && e.response?.statusCode == 403
          ? 'لا تملك الصلاحية لعرض هذه البيانات'
          : 'خطأ في الاتصال بالخادم';
      setState(() {
        _errorsError = '$msg: $e';
        _isLoadingErrors = false;
      });
    }
  }

  Future<void> _triggerInstantBackup() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري إنشاء نسخة احتياطية فورية...', style: TextStyle(fontFamily: 'Cairo')),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final dio = context.read<ApiClient>().dio;
      final res = await dio.post('backup/create', data: {'type': 'full'});
      if (!mounted) return;
      Navigator.pop(context); // close dialog
      
      if (res.data != null && res.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء النسخة الاحتياطية بنجاح وحفظها تلقائياً', style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.green,
          ),
        );
        _loadHealthData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل النسخ الاحتياطي: ${res.data['error'] ?? 'خطأ غير معروف'}', style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء تشغيل النسخ الاحتياطي: $e', style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حالة النظام والصيانة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.backup_outlined),
              tooltip: 'إنشاء نسخة احتياطية فورية',
              onPressed: _triggerInstantBackup,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _loadHealthData();
                _loadIntegrityData();
                _loadErrorsData();
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'حالة الخادم'),
              Tab(text: 'سلامة البيانات'),
              Tab(text: 'سجل الأخطاء'),
            ],
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildHealthTab(),
            _buildIntegrityTab(),
            _buildErrorsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthTab() {
    if (_isLoadingHealth) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_healthError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(_healthError!, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadHealthData,
                child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        ),
      );
    }

    final db = _healthData?['database'] ?? {};
    final sys = _healthData?['system'] ?? {};
    final backup = _healthData?['backup'] ?? {};
    final errs = _healthData?['errors'] ?? {};
    final active = _healthData?['active_users'] ?? {};

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Connection & Status Header Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'اتصال قاعدة البيانات: متصل بنجاح',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      Text(
                        'زمن استجابة الخادم: ${sys['api_response_time_ms'] ?? 0} ms',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        _sectionTitle('إحصائيات وقراءات الخادم'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildStatCard('حجم قاعدة البيانات', '${db['size_mb'] ?? 0} MB', Icons.storage_outlined, Colors.blue),
            _buildStatCard('عدد الجداول المفعلة', '${db['tables_count'] ?? 0} جدول', Icons.table_chart_outlined, Colors.orange),
            _buildStatCard('مساحة القرص الحرة', '${sys['disk_free_gb'] ?? 0} GB', Icons.donut_large_outlined, Colors.purple),
            _buildStatCard('الجلسات النشطة', '${active['sessions_count'] ?? 0} جلسة', Icons.people_outline, Colors.teal),
          ],
        ),
        const SizedBox(height: 20),

        _sectionTitle('حالة إضافات PHP المطلوبة (PHP Extensions)'),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: (sys['extensions'] as Map<String, dynamic>? ?? {}).entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Text(entry.value == true ? 'مفعل' : 'غير متوفر', style: TextStyle(fontFamily: 'Cairo', color: entry.value == true ? Colors.green : Colors.red)),
                          const SizedBox(width: 8),
                          Icon(entry.value == true ? Icons.check_circle_outline : Icons.cancel_outlined, color: entry.value == true ? Colors.green : Colors.red),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),

        _sectionTitle('النسخ الاحتياطي والأخطاء'),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildInfoRow('إصدار PHP الحالي', sys['php_version'] ?? 'غير معروف'),
                const Divider(),
                _buildInfoRow('آخر نسخة احتياطية ناجحة', backup['last_successful_backup_date'] ?? 'لا يوجد'),
                const Divider(),
                _buildInfoRow('حالة آخر عملية نسخ', backup['last_backup']?['status'] == 'success' ? 'ناجحة' : (backup['last_backup']?['status'] == 'failed' ? 'فاشلة' : 'لم تنفذ بعد')),
                if (errs['last_error'] != null) ...[
                  const Divider(),
                  _buildInfoRow('آخر خطأ مسجل بالخادم', errs['last_error']?['error_message'] ?? 'لا يوجد أخطاء'),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIntegrityTab() {
    if (_isLoadingIntegrity) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_integrityError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(_integrityError!, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadIntegrityData,
                child: const Text('إعادة الفحص', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        ),
      );
    }

    if (_integrityIssues.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_outlined, size: 80, color: Colors.green.shade400),
              const SizedBox(height: 16),
              const Text('سلامة البيانات ممتازة!', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 8),
              const Text('تم فحص جميع العقود والسندات وتكرار الحضور، ولم يتم العثور على أي مشاكل أو تعارضات.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', color: Colors.black54)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadIntegrityData,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة فحص سلامة البيانات الآن', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.amber.shade50,
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تم العثور على (${_integrityIssues.length}) تعارضات أو مشاكل في قاعدة البيانات تتطلب المراجعة.',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_outlined),
                onPressed: _loadIntegrityData,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _integrityIssues.length,
            itemBuilder: (context, index) {
              final issue = _integrityIssues[index];
              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: _getIntegrityIcon(issue['component']),
                  title: Text(issue['issue'] ?? 'تنبيه تعارض بيانات', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(issue['details'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getArabicComponent(issue['component']),
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.red.shade700, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorsTab() {
    if (_isLoadingErrors) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorsError!, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadErrorsData,
                child: const Text('تحديث السجل', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.playlist_add_check_circle_outlined, size: 80, color: Colors.green.shade400),
              const SizedBox(height: 16),
              Text('سجل الأخطاء فارغ!', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
              const SizedBox(height: 8),
              const Text('لم يتم تسجيل أي أخطاء أو استثناءات في الخادم مؤخراً.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', color: Colors.black54)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadErrorsData,
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث السجل', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Filter chips bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _buildFilterChip('الكل', 'all', null),
              const SizedBox(width: 8),
              _buildFilterChip('مفتوح', 'open', _errorCounts['open']),
              const SizedBox(width: 8),
              _buildFilterChip('تم الحل', 'resolved', _errorCounts['resolved']),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadErrorsData,
                tooltip: 'تحديث',
              ),
            ],
          ),
        ),
        // Error list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: _errorLogs.length,
            itemBuilder: (context, index) {
              final err = _errorLogs[index];
              final title = err['title_ar'] as String? ?? 'خطأ في الخادم';
              final cause = err['cause_ar'] as String? ?? '';
              final severity = err['severity'] as String? ?? 'متوسط';
              final action = err['suggested_action_ar'] as String? ?? '';
              final status = err['status'] as String? ?? 'resolved';
              final isResolved = status == 'resolved';

              // Determine severity level
              String levelLabel;
              Color severityColor;
              IconData severityIcon;
              switch (severity) {
                case 'عالي':
                  levelLabel = '🔴 خطير';
                  severityColor = Colors.red;
                  severityIcon = Icons.error;
                  break;
                case 'متوسط':
                  levelLabel = '🟠 تحذير';
                  severityColor = Colors.orange;
                  severityIcon = Icons.warning_amber_rounded;
                  break;
                case 'منخفض':
                  levelLabel = '🟢 معلومات';
                  severityColor = Colors.amber.shade700;
                  severityIcon = Icons.info_outline;
                  break;
                default:
                  levelLabel = severity;
                  severityColor = Colors.grey;
                  severityIcon = Icons.info_outline;
              }

              return Card(
                elevation: isResolved ? 0.5 : 1.5,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: isResolved ? Colors.grey.shade50 : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isResolved
                      ? BorderSide(color: Colors.grey.shade200)
                      : BorderSide(color: severityColor.withValues(alpha: 0.3)),
                ),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: (isResolved ? Colors.grey : severityColor).withValues(alpha: 0.15),
                    radius: 18,
                    child: Icon(severityIcon, color: isResolved ? Colors.grey : severityColor, size: 20),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isResolved ? Colors.grey : severityColor,
                            decoration: isResolved ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (isResolved)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('تم الحل', style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: Colors.green)),
                        ),
                    ],
                  ),
                  subtitle: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${err['api'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: Colors.black45),
                        ),
                      ),
                      Text(
                        levelLabel,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: severityColor),
                      ),
                    ],
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedAlignment: Alignment.topRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _errorDetailRow('الوحدة المتأثرة', err['api'] as String? ?? ''),
                          const SizedBox(height: 6),
                          _errorDetailRow('سبب المشكلة', cause),
                          const SizedBox(height: 6),
                          _errorDetailRow('مستوى الخطورة', levelLabel),
                          const SizedBox(height: 6),
                          _errorDetailRow('وقت حدوث الخطأ', err['created_at'] as String? ?? ''),
                          if (isResolved && err['resolved_at'] != null) ...[
                            const SizedBox(height: 6),
                            _errorDetailRow('وقت الحل', err['resolved_at'] as String),
                          ],
                          if (err['error_message'] != null) ...[
                            const SizedBox(height: 6),
                            _errorDetailRow('الرسالة التقنية', err['error_message'] as String),
                          ],
                          if (action.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _errorDetailRow('الإجراء المقترح', action),
                          ],
                        ],
                      ),
                    ),
                    if (err['stack_trace'] != null && (err['stack_trace'] as String).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('تفاصيل التتبع (Stack Trace):', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.brown)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            err['stack_trace'] as String,
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, int? count) {
    final isSelected = _errorFilter == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
          if (count != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.3) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _errorFilter = value;
          });
          _loadErrorsData();
        }
      },
      selectedColor: value == 'open' ? Colors.red.shade100 : (value == 'resolved' ? Colors.green.shade100 : Colors.blue.shade100),
      checkmarkColor: value == 'open' ? Colors.red : (value == 'resolved' ? Colors.green : Colors.blue),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _errorDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
        Expanded(
          child: Text(value, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black87)),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.black54),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              val,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Cairo', color: Colors.black54)),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: Text(
        title,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
    );
  }

  Widget _getIntegrityIcon(dynamic component) {
    switch (component?.toString()) {
      case 'contracts':
        return const Icon(Icons.description_outlined, color: Colors.orange);
      case 'payments':
        return const Icon(Icons.payments_outlined, color: Colors.red);
      case 'equipment':
        return const Icon(Icons.construction_outlined, color: Colors.blue);
      case 'attendance':
        return const Icon(Icons.fingerprint_outlined, color: Colors.teal);
      default:
        return const Icon(Icons.warning_amber_rounded, color: Colors.grey);
    }
  }

  String _getArabicComponent(dynamic component) {
    switch (component?.toString()) {
      case 'contracts':
        return 'العقود';
      case 'payments':
        return 'السندات';
      case 'equipment':
        return 'المعدات';
      case 'attendance':
        return 'التحضير';
      default:
        return 'النظام';
    }
  }
}
