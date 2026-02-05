import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/failure.dart';
import '../data/backup_repository.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  late final BackupRepository repo;

  bool loading = true;
  String? error;
  List<BackupItem> items = const [];

  String backupType = 'full'; // full | def | log

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
      final list = await repo.list();
      setState(() {
        items = list;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  String _fmtSize(int bytes) {
    if (bytes <= 0) return '0 KB';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _createBackup() async {
    try {
      await repo.create(type: backupType);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم إنشاء النسخة')),
      );
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _restoreBackup(String file) async {
    final ok = await _confirm(
      title: 'استرجاع نسخة',
      body: 'سيتم استرجاع النسخة:\n$file\n\nهل تريد المتابعة؟',
      confirmText: 'استرجاع',
    );
    if (!ok) return;

    try {
      await repo.restore(file: file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم الاسترجاع بنجاح')),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteBackup(String file) async {
    final ok = await _confirm(
      title: 'حذف نسخة',
      body: 'هل تريد حذف النسخة:\n$file ؟',
      confirmText: 'حذف',
      danger: true,
    );
    if (!ok) return;

    try {
      await repo.delete(file: file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ تم حذف النسخة')),
      );
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _clearAll() async {
    final ok = await _confirm(
      title: 'حذف جميع النسخ',
      body: 'سيتم حذف جميع النسخ الاحتياطية.\nهل أنت متأكد؟',
      confirmText: 'حذف الكل',
      danger: true,
    );
    if (!ok) return;

    try {
      await repo.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ تم حذف جميع النسخ')),
      );
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    final msg = (e is ApiFailure) ? e.message : e.toString();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('خطأ'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
        ],
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmText,
    bool danger = false,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return res == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Toolbar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: backupType,
                    decoration: const InputDecoration(
                      labelText: 'نوع النسخة',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'full', child: Text('Full (كامل)')),
                      DropdownMenuItem(value: 'def', child: Text('Def (هيكل فقط)')),
                      DropdownMenuItem(value: 'log', child: Text('Log (سجل)')),
                    ],
                    onChanged: (v) => setState(() => backupType = v ?? 'full'),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: loading ? null : _createBackup,
                  icon: const Icon(Icons.add),
                  label: const Text('إنشاء'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: loading ? null : _clearAll,
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text('حذف الكل'),
                ),
              ],
            ),
          ),

          if (loading) const Expanded(child: Center(child: CircularProgressIndicator())),
          if (!loading && error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (!loading && error == null)
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('لا توجد نسخ احتياطية'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final b = items[i];
                        return Card(
                          child: ListTile(
                            title: Text(b.file, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${_fmtSize(b.size)} • ${b.createdAt}'),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'restore') await _restoreBackup(b.file);
                                if (v == 'delete') await _deleteBackup(b.file);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'restore', child: Text('استرجاع')),
                                PopupMenuItem(value: 'delete', child: Text('حذف')),
                              ],
                            ),
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
