import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Stores API base URL override in SharedPreferences.
///
/// Default falls back to [AppConfig.baseUrl].
class BaseUrlStorage {
  static const String _key = 'api_base_url';

  Future<String> getBaseUrl() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_key);
    if (v == null || v.trim().isEmpty) return AppConfig.baseUrl;
    return v.trim();
  }

  Future<void> setBaseUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, url.trim());
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
