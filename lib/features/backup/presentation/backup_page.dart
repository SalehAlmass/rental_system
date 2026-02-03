import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import '../data/backup_repository.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  late final BackupRepository repo;

  bool loading = false;
  bool creating = false;
  List<BackupItem> items = const [];
  String? error;

  @override
  void initState() {
    super.initState();
    repo = BackupRepository(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await repo.list();
      setState(() => items = res);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _createBackup() async {
    setState(() {
      creating = true;
      error = null;
    });
    try {
      await repo.create();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم إنشاء النسخة الاحتياطية')),
      );
    } catch (e) {
      setState(() => error = e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ فشل إنشاء النسخة: $e')),
      );
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  Future<void> _confirmRestore(BackupItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الاسترجاع'),
        content: Text('هل تريد استرجاع النسخة:\n${item.name} ؟\nسيتم استبدال بيانات قاعدة البيانات الحالية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('استرجاع')),
        ],
      ),
    );

    if (ok != true) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await repo.restore(name: item.name); // ✅ تمرير name الصحيح
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم استرجاع النسخة بنجاح')),
      );
    } catch (e) {
      setState(() => error = e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ فشل الاسترجاع: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return 'KB 0.0';
    final kb = bytes / 1024.0;
    if (kb < 1024) return 'KB ${kb.toStringAsFixed(1)}';
    final mb = kb / 1024.0;
    return 'MB ${mb.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي'),
        centerTitle: true,
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('نسخة احتياطية تلقائية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(
                    'يفضل أخذ نسخة يومية. يمكنك إنشاء نسخة الآن يدويًا أو استرجاع أي نسخة سابقة.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: creating ? null : _createBackup,
                      icon: creating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.cloud_upload),
                      label: const Text('إنشاء نسخة الآن'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('النسخ المتوفرة', style: TextStyle(fontWeight: FontWeight.bold)),
              if (loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),

          if (error != null) ...[
            const SizedBox(height: 10),
            Text('حدث خطأ: $error', style: TextStyle(color: cs.error)),
          ],

          const SizedBox(height: 10),

          if (!loading && items.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد نسخ بعد'))),

          for (final b in items)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.storage)),
                title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${_formatSize(b.size)} • ${b.createdAt}'),
                trailing: OutlinedButton.icon(
                  onPressed: loading ? null : () => _confirmRestore(b),
                  icon: const Icon(Icons.restore),
                  label: const Text('استرجاع'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
