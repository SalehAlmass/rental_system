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

  String backupType = 'full';

  @override
  void initState() {
    super.initState();
    repo = BackupRepository(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await repo.list();
      if (!mounted) return;
      setState(() => items = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _createBackup() async {
    if (!mounted) return;
    setState(() {
      creating = true;
      error = null;
    });

    try {
      await repo.create(type: backupType);
      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم إنشاء النسخة الاحتياطية')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ فشل إنشاء النسخة: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => creating = false);
    }
  }

  Future<void> _confirmRestore(BackupItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الاسترجاع'),
        content: Text(
          'هل تريد استرجاع النسخة:\n${item.name}\n\nسيتم استبدال البيانات الحالية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('استرجاع'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await repo.restore(name: item.name);
      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم الاسترجاع بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ فشل الاسترجاع: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 KB';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي'),
        actions: [
          IconButton(
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCreateCard(cs),
          const SizedBox(height: 16),
          _buildHeader(loading),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text('حدث خطأ: $error', style: TextStyle(color: cs.error)),
          ],
          const SizedBox(height: 10),
          if (!loading && items.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('لا توجد نسخ بعد'),
              ),
            ),
          for (int i = 0; i < items.length; i++)
            _AnimatedBackupTile(
              index: i,
              item: items[i],
              subtitle:
                  '${_formatSize(items[i].size)} • ${items[i].createdAt} • ${items[i].type.toUpperCase()}',
              onRestore: loading ? null : () => _confirmRestore(items[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool loading) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('النسخ المتوفرة', style: TextStyle(fontWeight: FontWeight.bold)),
        if (loading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _buildCreateCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نسخة احتياطية يدوية',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'يمكنك إنشاء نسخة جديدة أو استرجاع أي نسخة سابقة.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: backupType,
              decoration: const InputDecoration(
                labelText: 'نوع النسخة',
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'full', child: Text('Full (كامل)')),
                DropdownMenuItem(value: 'def', child: Text('Def (تعريف فقط)')),
                DropdownMenuItem(value: 'log', child: Text('Log (بيانات فقط)')),
              ],
              onChanged: creating ? null : (v) => setState(() => backupType = v!),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: creating ? null : _createBackup,
                icon: creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: const Text('إنشاء نسخة الآن'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedBackupTile extends StatelessWidget {
  const _AnimatedBackupTile({
    required this.index,
    required this.item,
    required this.subtitle,
    required this.onRestore,
  });

  final int index;
  final BackupItem item;
  final String subtitle;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 40),
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 10),
            child: child,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.storage)),
          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: OutlinedButton.icon(
            onPressed: onRestore,
            icon: const Icon(Icons.restore),
            label: const Text('استرجاع'),
          ),
        ),
      ),
    );
  }
}
