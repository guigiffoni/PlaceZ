import 'package:flutter/material.dart';
import 'preferencia_tema.dart';

class TemaController extends ChangeNotifier {
  ThemeMode _modoTema = ThemeMode.system;
  Color _seedCor = Colors.deepPurple;

  ThemeMode get modoTema => _modoTema;
  Color get seedCor => _seedCor;

  // Carrega as preferências salvas quando o aplicativo abre
  Future<void> carregaPreferencias() async {
    _modoTema = await PreferenciaTema.carregaModoTema();
    _seedCor = await PreferenciaTema.carregaSeedCor();

    notifyListeners();
  }

  Future<void> mudaModoTema(ThemeMode novoModo) async {
    if (_modoTema == novoModo) return;
    
    _modoTema = novoModo;
    notifyListeners();
    await PreferenciaTema.salvaModoTema(novoModo);
  }

  Future<void> mudaSeedCor(Color novaCor) async {
    if (_seedCor == novaCor) return;
    
    _seedCor = novaCor;
    notifyListeners();
    await PreferenciaTema.salvaSeedCor(novaCor);
  }
}