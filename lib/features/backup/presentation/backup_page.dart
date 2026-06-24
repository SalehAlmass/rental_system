import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/downloader/downloader.dart';

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
  bool working = false;
  String? error;
  List<BackupItem> items = const [];

  String backupType = 'full';

  final _path1Ctrl = TextEditingController();
  final _path2Ctrl = TextEditingController();
  bool _savingSettings = false;

  @override
  void initState() {
    super.initState();
    repo = BackupRepository(context.read<ApiClient>());
    _load();
  }

  @override
  void dispose() {
    _path1Ctrl.dispose();
    _path2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final list = await repo.list();
      final settings = await repo.getSettings();
      if (!mounted) return;
      setState(() {
        items = list;
        _path1Ctrl.text = settings['backup_custom_path_1'] ?? '';
        _path2Ctrl.text = settings['backup_custom_path_2'] ?? '';
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = _errorMessage(e);
        loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _savingSettings = true);
    try {
      await repo.saveSettings(
        path1: _path1Ctrl.text.trim(),
        path2: _path2Ctrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم حفظ مسارات النسخ الاحتياطي بنجاح')),
      );
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  String _errorMessage(Object e) {
    if (e is ApiFailure) return e.message;
    return e.toString();
  }

  String _fmtSize(int bytes) {
    if (bytes <= 0) return '0 KB';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }


  String _buildLocalBackupName() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');

    return 'alkhair_backup_${now.year}-${two(now.month)}-${two(now.day)}_${two(now.hour)}-${two(now.minute)}.sql';
  }

  Future<void> _createBackupOnly() async {
    setState(() => working = true);

    try {
      await repo.create(type: backupType);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم إنشاء النسخة داخل النظام')),
      );

      await _load();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _createBackupChooseLocation() async {
    setState(() => working = true);

    try {
      // أولاً: إنشاء النسخة الاحتياطية في الخادم وتحميلها
      final created = await repo.create(type: backupType);
      final rawBytes = await repo.download(file: created.file);
      final bytes = Uint8List.fromList(rawBytes);

      if (bytes.isEmpty) {
        throw ApiFailure('تم إنشاء النسخة لكن تعذر تحميل الملف');
      }

      final fileName = _buildLocalBackupName();

      if (kIsWeb) {
        await downloadBytesWeb(bytes, fileName);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم بدء تحميل النسخة')),
        );
        await _load();
        return;
      }

      // فتح نافذة "حفظ باسم" لاختيار المكان واسم الملف (للديسكتوب فقط)
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'احفظ النسخة الاحتياطية',
        fileName: fileName,
        type: FileType.any,
        bytes: bytes, // Uint8List - النوع الصحيح
      );

      if (!mounted) return;

      if (savePath == null) {
        // المستخدم ألغى العملية
        return;
      }

      // على Windows/Linux/macOS: نكتب الملف يدوياً
      if (!savePath.contains('://')) {
        try {
          final file = File(savePath);
          await file.writeAsBytes(bytes, flush: true);
        } catch (_) {
          // على الويب: file_picker يكتب الملف تلقائياً عبر bytes
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم حفظ النسخة في:\n$savePath')),
      );

      await _load();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _restoreFromLocalFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sql'],
        withData: true,
        dialogTitle: 'اختر ملف النسخة الاحتياطية',
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        throw ApiFailure('تعذر قراءة محتوى الملف');
      }

      final ok = await _confirm(
        title: 'استرجاع من ملف خارجي',
        body: 'سيتم مسح قاعدة البيانات الحالية واسترجاع البيانات من الملف:\n${file.name}\n\nهل أنت متأكد؟',
        confirmText: 'نعم، استرجاع',
        danger: true,
      );

      if (!ok) return;

      setState(() => working = true);

      await repo.uploadAndRestore(
        bytes: bytes,
        filename: file.name,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم استرجاع النسخة بنجاح')),
      );

      await _load();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _restoreBackup(String file) async {
    final ok = await _confirm(
      title: 'استرجاع نسخة',
      body: 'سيتم استرجاع النسخة:\n$file\n\nهل تريد المتابعة؟',
      confirmText: 'استرجاع',
    );

    if (!ok) return;

    setState(() => working = true);

    try {
      await repo.restore(file: file);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم الاسترجاع بنجاح')),
      );

      await _load();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => working = false);
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

    setState(() => working = true);

    try {
      await repo.delete(file: file);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ تم حذف النسخة')),
      );

      await _load();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _clearAll() async {
    final ok = await _confirm(
      title: 'حذف جميع النسخ',
      body: 'سيتم حذف جميع النسخ الاحتياطية الموجودة داخل النظام.\nهل أنت متأكد؟',
      confirmText: 'حذف الكل',
      danger: true,
    );

    if (!ok) return;

    setState(() => working = true);

    try {
      await repo.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ تم حذف جميع النسخ')),
      );

      await _load();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  void _showError(Object e) {
    final msg = _errorMessage(e);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('خطأ'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
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

  Future<void> _pickDirectory(TextEditingController ctrl) async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ميزة اختيار المجلد غير مدعومة على متصفح الويب. يرجى كتابة المسار يدوياً.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    try {
      final String? dir = await FilePicker.platform.getDirectoryPath();
      if (dir != null && mounted) {
        setState(() {
          ctrl.text = dir;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء اختيار المجلد: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = loading || working;

    return Scaffold(
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: disabled ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.black.withOpacity(0.08)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إنشاء نسخة احتياطية',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: backupType,
                            decoration: const InputDecoration(
                              labelText: 'نوع النسخة',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'full',
                                child: Text('كامل'),
                              ),
                              DropdownMenuItem(
                                value: 'def',
                                child: Text('هيكل فقط'),
                              ),
                              DropdownMenuItem(
                                value: 'log',
                                child: Text('سجل / بيانات'),
                              ),
                            ],
                            onChanged: disabled
                                ? null
                                : (v) => setState(
                                      () => backupType = v ?? 'full',
                                    ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: disabled ? null : _createBackupOnly,
                          icon: const Icon(Icons.add),
                          label: const Text('إنشاء'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed:
                              disabled ? null : _createBackupChooseLocation,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('اختيار مكان وحفظ'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: disabled ? null : _restoreFromLocalFile,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('استرجاع من ملف'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: disabled ? null : _clearAll,
                          icon: const Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                          ),
                          label: const Text('حذف الكل'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'زر "اختيار مكان وحفظ" ينشئ النسخة ثم يحفظها في المجلد الذي يختاره المدير مثل سطح المكتب أو فلاش USB أو قرص D.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (working) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.black.withOpacity(0.08)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مسارات حفظ النسخ الاحتياطية تلقائياً وعبر الجدولة (على السيرفر)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _path1Ctrl,
                            enabled: !disabled && !_savingSettings,
                            decoration: InputDecoration(
                              labelText: 'مسار الحفظ المخصص الأول (مثال: D:/backups)',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.folder_outlined),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.folder_open),
                                onPressed: () => _pickDirectory(_path1Ctrl),
                                tooltip: 'اختيار مجلد',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _path2Ctrl,
                            enabled: !disabled && !_savingSettings,
                            decoration: InputDecoration(
                              labelText: 'مسار الحفظ المخصص الثاني (مثال: E:/backups)',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.folder_outlined),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.folder_open),
                                onPressed: () => _pickDirectory(_path2Ctrl),
                                tooltip: 'اختيار مجلد',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: (disabled || _savingSettings) ? null : _saveSettings,
                          icon: _savingSettings
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save),
                          label: const Text('حفظ الإعدادات'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),

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
                            leading: const CircleAvatar(
                              child: Icon(Icons.storage),
                            ),
                            title: Text(
                              b.file,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${_fmtSize(b.size)} • ${b.createdAt}',
                            ),
                            trailing: PopupMenuButton<String>(
                              enabled: !working,
                              onSelected: (v) async {
                                if (v == 'restore') {
                                  await _restoreBackup(b.file);
                                }
                                if (v == 'delete') {
                                  await _deleteBackup(b.file);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'restore',
                                  child: Text('استرجاع'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('حذف'),
                                ),
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