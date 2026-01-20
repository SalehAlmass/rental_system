import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  // =======================
  // Keys
  // =======================
  static const _kTokenKey = 'auth_token';
  static const _kUsernameKey = 'profile_username';
  static const _kRoleKey = 'profile_role';

  // =======================
  // Token
  // =======================
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTokenKey);
  }

  // =======================
  // Profile Cache (username + role)
  // =======================
  Future<void> saveProfileCache({
    required String username,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUsernameKey, username);
    await prefs.setString(_kRoleKey, role);
  }

  Future<Map<String, String>?> getProfileCache() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_kUsernameKey);
    final role = prefs.getString(_kRoleKey);

    if (username == null || role == null) return null;

    return {
      'username': username,
      'role': role,
    };
  }

  Future<void> clearProfileCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUsernameKey);
    await prefs.remove(_kRoleKey);
  }

  // =======================
  // Clear All (Logout)
  // =======================
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kUsernameKey);
    await prefs.remove(_kRoleKey);
  }
}
