import 'package:shared_preferences/shared_preferences.dart';

/// Persistent settings for the app (offline/local):
/// - Theme (light/dark)
/// - Branch name (for printing/export headers)
class AppSettingsStorage {
  static const _kThemeMode = 'app_theme_mode'; // 'light'|'dark'
  static const _kBranchName = 'branch_name';
  static const _kLastAutoBackupAt = 'last_auto_backup_at'; // ISO8601

  Future<String> getBranchName() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kBranchName) ?? 'الفرع الرئيسي';
  }

  Future<void> setBranchName(String name) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kBranchName, name.trim().isEmpty ? 'الفرع الرئيسي' : name.trim());
  }

  Future<String> getThemeMode() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kThemeMode) ?? 'light';
  }

  Future<void> setThemeMode(String mode) async {
    final sp = await SharedPreferences.getInstance();
    if (mode != 'light' && mode != 'dark') mode = 'light';
    await sp.setString(_kThemeMode, mode);
  }

  Future<String?> getLastAutoBackupAt() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kLastAutoBackupAt);
  }

  Future<void> setLastAutoBackupAt(String iso) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLastAutoBackupAt, iso);
  }
}
