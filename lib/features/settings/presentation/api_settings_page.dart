import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/storage/base_url_storage.dart';

/// صفحة إعدادات بسيطة لتغيير Base URL للـ API من داخل التطبيق.
///
/// مثال:
/// - Emulator Android: http://10.0.2.2/rental_api/index.php?path=
/// - Localhost wamp/xampp: http://localhost/rental_api/index.php?path=
/// - IP الجهاز: http://192.168.1.10/rental_api/index.php?path=
class ApiSettingsPage extends StatefulWidget {
  const ApiSettingsPage({super.key});

  @override
  State<ApiSettingsPage> createState() => _ApiSettingsPageState();
}

class _ApiSettingsPageState extends State<ApiSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = TextEditingController();
  final _storage = BaseUrlStorage();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = await _storage.getBaseUrl();
    if (!mounted) return;
    setState(() => _ctrl.text = url);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات السيرفر (API)')
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Base URL',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _ctrl,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  hintText: 'http://10.0.2.2/rental_api/index.php?path=',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'أدخل الرابط';
                  if (!s.startsWith('http://') && !s.startsWith('https://')) {
                    return 'لازم يبدأ بـ http:// أو https://';
                  }
                  if (!s.contains('index.php?path=')) {
                    return 'لازم يحتوي على index.php?path=';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'ملاحظة: بعد الحفظ، التطبيق سيستخدم الرابط الجديد مباشرة (بدون إعادة تشغيل).',
                style: TextStyle(color: Colors.grey),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _saving ? null : () => _save(context),
                icon: const Icon(Icons.save),
                label: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saving ? null : () async {
                  setState(() => _saving = true);
                  await _storage.clear();
                  final url = await _storage.getBaseUrl();
                  if (!mounted) return;
                  setState(() {
                    _ctrl.text = url;
                    _saving = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت إعادة الرابط الافتراضي')),
                  );
                },
                icon: const Icon(Icons.restore),
                label: const Text('إرجاع الافتراضي'),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final url = _ctrl.text.trim();
    setState(() => _saving = true);
    await _storage.setBaseUrl(url);

    // Ping a light endpoint to confirm.
    try {
      final api = context.read<ApiClient>().dio;
      await api.get('');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ والاتصال ناجح ✅')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ، لكن فشل الاتصال (تحقق من الرابط)')),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
  }
}
