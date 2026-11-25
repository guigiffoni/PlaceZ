import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session.dart';

class AuthStorage {
  static const String _chaveSessao = 'auth_session';

  Future<AuthSession?> carrega() async {
    final prefs = await SharedPreferences.getInstance();
    final texto = prefs.getString(_chaveSessao);
    if (texto == null || texto.isEmpty) return null;

    try {
      final dados = jsonDecode(texto);
      if (dados is! Map) {
        await limpa();
        return null;
      }
      return AuthSession.fromJson(Map<String, dynamic>.from(dados));
    } on FormatException {
      // Sessão local corrompida: descarta para não travar o app no login.
      await limpa();
      return null;
    }
  }

  Future<void> salva(AuthSession sessao) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveSessao, jsonEncode(sessao.toJson()));
  }

  Future<void> limpa() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveSessao);
  }
}
