import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Stores API base URL override in SharedPreferences.
///
/// Default falls back to [AppConfig.baseUrl].
class BaseUrlStorage {
  static const String _key = 'api_base_url';
  String? _cachedUrl;

  Future<String> getBaseUrl() async {
    if (_cachedUrl != null) return _cachedUrl!;
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_key);
    _cachedUrl = (v == null || v.trim().isEmpty) ? AppConfig.baseUrl : v.trim();
    return _cachedUrl!;
  }

  Future<void> setBaseUrl(String url) async {
    final trimmed = url.trim();
    _cachedUrl = trimmed.isEmpty ? AppConfig.baseUrl : trimmed;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, _cachedUrl!);
  }

  Future<void> clear() async {
    _cachedUrl = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
