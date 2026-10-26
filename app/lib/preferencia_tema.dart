import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferenciaTema {
  static const String _modoTema = 'theme_mode';
  static const String _seedCor = 'seed_color';


  static Future<void> salvaModoTema(ThemeMode modo) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_modoTema, modo.name);
  }

  static Future<ThemeMode> carregaModoTema() async {
    final prefs = await SharedPreferences.getInstance();
    final String? modo = prefs.getString(_modoTema);

    switch (modo) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> salvaSeedCor(Color color) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(_seedCor, color.toARGB32());
  }

  static Future<Color> carregaSeedCor() async {
    final prefs = await SharedPreferences.getInstance();
    final int? cor = prefs.getInt(_seedCor);

    if (cor != null) {
      return Color(cor);
    }

    return Colors.deepPurple;
  }
}
