import 'local.dart';

class AvaliacaoLugar {
  final int id;
  final int? usuarioId;
  final String autorNome;
  final String? autorUsername;
  final int nota;
  final String? comentario;
  final DateTime? criadoEm;
  final DateTime? atualizadoEm;
  final bool minha;

  const AvaliacaoLugar({
    required this.id,
    this.usuarioId,
    required this.autorNome,
    this.autorUsername,
    required this.nota,
    this.comentario,
    this.criadoEm,
    this.atualizadoEm,
    this.minha = false,
  });

  factory AvaliacaoLugar.fromJson(Map<String, dynamic> json) {
    final id = _comoInt(json['id']);
    final nota = _comoInt(json['nota']);
    if (id == null || nota == null) {
      throw const FormatException('Avaliação inválida.');
    }

    return AvaliacaoLugar(
      id: id,
      usuarioId: _comoInt(json['usuarioId']),
      autorNome: (json['autorNome'] ?? 'Usuário do PlaceZ').toString(),
      autorUsername: _texto(json['autorUsername']),
      nota: nota,
      comentario: _texto(json['comentario']),
      criadoEm: _comoData(json['criadoEm']),
      atualizadoEm: _comoData(json['atualizadoEm']),
      minha: json['minha'] == true,
    );
  }
}

class DetalheLugar {
  final Local lugar;
  final List<String> itens;
  final List<AvaliacaoLugar> avaliacoes;
  final AvaliacaoLugar? minhaAvaliacao;

  const DetalheLugar({
    required this.lugar,
    this.itens = const [],
    this.avaliacoes = const [],
    this.minhaAvaliacao,
  });

  factory DetalheLugar.fromJson(Map<String, dynamic> json) {
    final base = Local.fromJson(json);
    final lugar = base.catalogoId == null && base.id != null
        ? base.copyWith(catalogoId: base.id)
        : base;
    final itens = json['itens'];
    final avaliacoes = json['avaliacoes'];
    final minha = json['minhaAvaliacao'];

    return DetalheLugar(
      lugar: lugar,
      itens: itens is List
          ? itens.map((item) => item.toString()).toList()
          : const [],
      avaliacoes: avaliacoes is List
          ? avaliacoes
                .whereType<Map>()
                .map(
                  (item) =>
                      AvaliacaoLugar.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      minhaAvaliacao: minha is Map
          ? AvaliacaoLugar.fromJson(Map<String, dynamic>.from(minha))
          : null,
    );
  }
}

String? _texto(dynamic valor) {
  final texto = valor?.toString().trim();
  return texto == null || texto.isEmpty ? null : texto;
}

int? _comoInt(dynamic valor) {
  if (valor == null) return null;
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse(valor.toString());
}

DateTime? _comoData(dynamic valor) {
  if (valor == null) return null;
  if (valor is DateTime) return valor.toUtc();
  return DateTime.tryParse(valor.toString())?.toUtc();
}
