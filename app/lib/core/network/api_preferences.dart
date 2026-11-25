import 'package:shared_preferences/shared_preferences.dart';

import 'api_mode.dart';

class ApiPreferences {
  static const String _chaveApiMode = 'api_mode';

  static Future<ApiMode> carregaModo() async {
    final prefs = await SharedPreferences.getInstance();
    return ApiMode.fromStorage(prefs.getString(_chaveApiMode));
  }

  static Future<void> salvaModo(ApiMode modo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveApiMode, modo.storageValue);
  }
}
