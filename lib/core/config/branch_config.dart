import 'package:shared_preferences/shared_preferences.dart';

class BranchConfig {
  static Future<String> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('branch_name') ?? 'الفرع الرئيسي';
  }

  static Future<void> setName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('branch_name', name);
  }
}
