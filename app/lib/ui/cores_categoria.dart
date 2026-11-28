import 'package:flutter/material.dart';

import '../tema.dart';

/// Paleta fixa por categoria de lugar, usada em cartões, chips e eventos.
PaletaStatus paletaCategoria(ColorScheme scheme, String? categoria) {
  final valor = (categoria ?? '').toLowerCase();

  if (valor.contains('restaurante') ||
      valor.contains('gastronomia') ||
      valor.contains('café') ||
      valor.contains('cafe') ||
      valor.contains('padaria') ||
      valor.contains('bar') ||
      valor.contains('pizza') ||
      valor.contains('açaí') ||
      valor.contains('acai') ||
      valor.contains('doceria')) {
    return scheme.acentoAmbar;
  }

  if (valor.contains('parque') ||
      valor.contains('praça') ||
      valor.contains('praca') ||
      valor.contains('mirante') ||
      valor.contains('lagoa') ||
      valor.contains('jardim') ||
      valor.contains('gruta')) {
    return scheme.acentoTeal;
  }

  if (valor.contains('museu') ||
      valor.contains('teatro') ||
      valor.contains('centro cultural') ||
      valor.contains('cinema') ||
      valor.contains('galeria')) {
    return scheme.acentoRoxo;
  }

  if (valor.contains('shopping') ||
      valor.contains('mercado') ||
      valor.contains('feira') ||
      valor.contains('loja')) {
    return scheme.acentoRosa;
  }

  if (valor.contains('estádio') ||
      valor.contains('estadio') ||
      valor.contains('esporte')) {
    return scheme.acentoAzul;
  }

  return PaletaStatus(
    fundo: scheme.primaryContainer,
    frente: scheme.onPrimaryContainer,
    borda: scheme.primary.withValues(alpha: 0.3),
  );
}
