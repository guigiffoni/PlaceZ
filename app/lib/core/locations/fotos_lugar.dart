/// Fotos locais por categoria do catálogo.
///
/// As imagens são ilustrativas e ficam empacotadas no app para funcionar
/// offline. O detalhe monta uma pequena galeria com três variações.
class FotosLugar {
  const FotosLugar._();

  static const List<String> _restaurante = [
    'assets/lugares/restaurante_1.jpg',
    'assets/lugares/restaurante_2.jpg',
    'assets/lugares/restaurante_3.jpg',
  ];
  static const List<String> _cafe = [
    'assets/lugares/cafe_1.jpg',
    'assets/lugares/cafe_2.jpg',
    'assets/lugares/cafe_3.jpg',
  ];
  static const List<String> _parque = [
    'assets/lugares/parque_3.jpg',
    'assets/lugares/parque_2.jpg',
    'assets/lugares/parque_1.jpg',
  ];
  static const List<String> _cultura = [
    'assets/lugares/cultura_1.jpg',
    'assets/lugares/cultura_2.jpg',
    'assets/lugares/cultura_3.jpg',
  ];
  static const List<String> _shopping = [
    'assets/lugares/shopping_1.jpg',
    'assets/lugares/shopping_2.jpg',
    'assets/lugares/shopping_3.jpg',
  ];
  static const List<String> _esporte = [
    'assets/lugares/esporte_1.jpg',
    'assets/lugares/esporte_2.jpg',
    'assets/lugares/cidade_1.jpg',
  ];
  static const List<String> _praca = [
    'assets/lugares/praca_1.jpg',
    'assets/lugares/praca_2.jpg',
    'assets/lugares/praca_3.jpg',
  ];
  static const List<String> _cidade = [
    'assets/lugares/cidade_1.jpg',
    'assets/lugares/praca_3.jpg',
    'assets/lugares/parque_1.jpg',
  ];

  static List<String> paraCategoria(String? categoria) {
    final valor = (categoria ?? '').toLowerCase();
    if (valor.contains('restaurante') ||
        valor.contains('gastronomia') ||
        valor.contains('pizza')) {
      return _restaurante;
    }
    if (valor.contains('café') ||
        valor.contains('cafe') ||
        valor.contains('padaria') ||
        valor.contains('doceria')) {
      return _cafe;
    }
    if (valor.contains('praça') || valor.contains('praca')) {
      return _praca;
    }
    if (valor.contains('mirante')) return _cidade;
    if (valor.contains('parque') ||
        valor.contains('lagoa') ||
        valor.contains('jardim')) {
      return _parque;
    }
    if (valor.contains('museu') ||
        valor.contains('teatro') ||
        valor.contains('cinema') ||
        valor.contains('centro cultural') ||
        valor.contains('galeria')) {
      return _cultura;
    }
    if (valor.contains('shopping') ||
        valor.contains('mercado') ||
        valor.contains('feira') ||
        valor.contains('loja')) {
      return _shopping;
    }
    if (valor.contains('estádio') ||
        valor.contains('estadio') ||
        valor.contains('esporte')) {
      return _esporte;
    }
    return _cidade;
  }

  /// Varia a ordem das fotos pelo nome do lugar, para que locais da mesma
  /// categoria não usem sempre a mesma imagem principal.
  static List<String> paraLugar(String? categoria, String? nome) {
    final lista = paraCategoria(categoria);
    if (lista.length < 2) return lista;

    final soma = (nome ?? '').codeUnits.fold<int>(0, (a, b) => a + b);
    final inicio = soma % lista.length;
    return [
      for (var i = 0; i < lista.length; i++) lista[(inicio + i) % lista.length],
    ];
  }

  static String principal(String? categoria, [String? nome]) =>
      paraLugar(categoria, nome).first;
}
