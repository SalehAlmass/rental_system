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
      setState(() {
        _healthError = 'خطأ في الاتصال بالخادم: $e';
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
      setState(() {
        _integrityError = 'خطأ في الاتصال بالخادم: $e';
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
      final res = await dio.get('system-health/errors');
      if (res.data != null && res.data['success'] == true) {
        setState(() {
          _errorLogs = res.data['data'] as List<dynamic>;
          _isLoadingErrors = false;
        });
      } else {
        setState(() {
          _errorsError = res.data['error'] ?? 'فشل جلب سجل أخطاء الخادم';
          _isLoadingErrors = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorsError = 'خطأ في الاتصال بالخادم: $e';
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_add_check_circle_outlined, size: 80, color: Colors.green),
            SizedBox(height: 16),
            Text('سجل الأخطاء فارغ!', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
            SizedBox(height: 8),
            Text('لم يتم تسجيل أي أخطاء أو استثناءات في الخادم مؤخراً.', style: TextStyle(fontFamily: 'Cairo', color: Colors.black54)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _errorLogs.length,
      itemBuilder: (context, index) {
        final err = _errorLogs[index];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ExpansionTile(
            title: Text(
              err['error_message'] ?? 'خطأ في الخادم',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
            ),
            subtitle: Text(
              'المسار: ${err['api']} | ${err['created_at']}',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            childrenPadding: const EdgeInsets.all(16),
            expandedAlignment: Alignment.topRight,
            children: [
              const Text('رمز الخطأ وتتبع المسار (Stack Trace):', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.brown)),
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
                    err['stack_trace'] ?? 'لا يوجد تفاصيل إضافية لتتبع المسار',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
