import 'dart:convert';

import 'package:flutter/services.dart';

import '../../data/models/local.dart';

/// Catálogo estático de lugares usado na busca mock da Fase 3.
///
/// O lugar escolhido é enviado como snapshot no evento; este catálogo não é
/// fonte de verdade do Oracle.
class LocalCatalog {
  static const String _asset = 'assets/mock/locais.json';
  static List<Local>? _cache;

  static Future<List<Local>> carregar() async {
    final cache = _cache;
    if (cache != null) return cache;

    final texto = await rootBundle.loadString(_asset);
    final dados = jsonDecode(texto);
    final lista = dados is Map ? dados['locais'] : dados;
    if (lista is! List) {
      return const [];
    }

    final locais = lista
        .whereType<Map>()
        .map((item) => Local.fromJson(Map<String, dynamic>.from(item)))
        .where((local) => local.nome != null)
        .toList();
    locais.sort((a, b) => (a.nome ?? '').compareTo(b.nome ?? ''));
    _cache = locais;
    return locais;
  }

  static Future<List<Local>> buscar(String termo) async {
    final locais = await carregar();
    final alvo = termo.trim().toLowerCase();
    if (alvo.isEmpty) return locais;

    return locais.where((local) {
      final campos = [
        local.nome,
        local.endereco,
        local.categoria,
      ].whereType<String>().map((valor) => valor.toLowerCase());
      return campos.any((valor) => valor.contains(alvo));
    }).toList();
  }
}

String formatarDistancia(double? metros) {
  if (metros == null) return 'Distância não informada';
  if (metros < 1000) return '${metros.round()} m';
  final km = metros / 1000;
  return '${km.toStringAsFixed(km >= 10 ? 0 : 1).replaceAll('.', ',')} km';
}
