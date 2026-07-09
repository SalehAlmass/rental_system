import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _kTokenKey = 'auth_token';
  String? _cachedToken;
  bool _isLoaded = false;

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    _isLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
  }

  Future<String?> getToken() async {
    if (_isLoaded) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_kTokenKey);
    _isLoaded = true;
    return _cachedToken;
  }

  Future<void> clear() async {
    _cachedToken = null;
    _isLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
  }
}
