import 'local.dart';

class LocalizacaoAproximada {
  final String bairro;
  final String? cidade;

  const LocalizacaoAproximada({required this.bairro, this.cidade});

  static LocalizacaoAproximada? fromResposta(dynamic valor) {
    if (valor is! Map) return null;
    final bairro = (valor['bairro'] ?? '').toString().trim();
    if (bairro.isEmpty) return null;
    final cidade = (valor['cidade'] ?? '').toString().trim();
    return LocalizacaoAproximada(
      bairro: bairro,
      cidade: cidade.isEmpty ? null : cidade,
    );
  }
}

class LocalizacaoUsuario {
  final String bairro;
  final String? cidade;
  final double? latitude;
  final double? longitude;
  final String origem;
  final bool aproximada;
  final bool legado;

  const LocalizacaoUsuario({
    required this.bairro,
    this.cidade,
    this.latitude,
    this.longitude,
    this.origem = 'MAPA',
    this.aproximada = true,
    this.legado = false,
  });

  String get origemRotulo {
    switch (origem.toUpperCase()) {
      case 'GPS':
        return 'GPS';
      case 'BUSCA':
        return 'Busca';
      case 'COORDENADAS':
        return 'Coordenadas';
      case 'REGIAO':
        return 'Região antiga';
      default:
        return 'Mapa';
    }
  }

  factory LocalizacaoUsuario.fromJson(Map<String, dynamic> json) {
    final bairro = (json['bairro'] ?? '').toString().trim();
    if (bairro.isEmpty) {
      throw const FormatException('Localização aproximada inválida.');
    }
    final cidade = (json['cidade'] ?? '').toString().trim();
    return LocalizacaoUsuario(
      bairro: bairro,
      cidade: cidade.isEmpty ? null : cidade,
      latitude: _comoDouble(json['latitude']),
      longitude: _comoDouble(json['longitude']),
      origem: (json['origem'] ?? 'MAPA').toString(),
      aproximada: json['aproximada'] != false,
      legado: json['legado'] == true,
    );
  }

  static LocalizacaoUsuario? fromResposta(dynamic valor) {
    if (valor is! Map) return null;
    try {
      return LocalizacaoUsuario.fromJson(Map<String, dynamic>.from(valor));
    } on FormatException {
      return null;
    }
  }
}

class SugestaoLocal {
  final Local lugar;
  final int distanciaMediaMetros;

  const SugestaoLocal({
    required this.lugar,
    required this.distanciaMediaMetros,
  });

  factory SugestaoLocal.fromJson(Map<String, dynamic> json) {
    final lugar = json['lugar'];
    if (lugar is! Map) {
      throw const FormatException('Sugestão de local inválida.');
    }
    return SugestaoLocal(
      lugar: Local.fromJson(Map<String, dynamic>.from(lugar)),
      distanciaMediaMetros: _comoInt(json['distanciaMediaMetros']) ?? 0,
    );
  }
}

class PessoaSemLocalizacao {
  final int usuarioId;
  final String nome;

  const PessoaSemLocalizacao({required this.usuarioId, required this.nome});

  factory PessoaSemLocalizacao.fromJson(Map<String, dynamic> json) {
    return PessoaSemLocalizacao(
      usuarioId: _comoInt(json['usuarioId']) ?? 0,
      nome: (json['nome'] ?? '').toString(),
    );
  }
}

class PessoaLocalizacaoAproximada {
  final int usuarioId;
  final String nome;
  final LocalizacaoAproximada localizacao;

  const PessoaLocalizacaoAproximada({
    required this.usuarioId,
    required this.nome,
    required this.localizacao,
  });

  factory PessoaLocalizacaoAproximada.fromJson(Map<String, dynamic> json) {
    final localizacao = LocalizacaoAproximada.fromResposta(json);
    if (localizacao == null) {
      throw const FormatException('Localização de participante inválida.');
    }
    return PessoaLocalizacaoAproximada(
      usuarioId: _comoInt(json['usuarioId']) ?? 0,
      nome: (json['nome'] ?? '').toString(),
      localizacao: localizacao,
    );
  }
}

class ResultadoSugestoes {
  final List<SugestaoLocal> sugestoes;
  final List<PessoaSemLocalizacao> semLocalizacao;
  final List<PessoaLocalizacaoAproximada> localizacoesAproximadas;
  final String modo;

  const ResultadoSugestoes({
    this.sugestoes = const [],
    this.semLocalizacao = const [],
    this.localizacoesAproximadas = const [],
    this.modo = 'todos',
  });

  factory ResultadoSugestoes.fromJson(Map<String, dynamic> json) {
    final sugestoes = json['sugestoes'];
    final sem = json['semLocalizacao'];
    final locais = json['localizacoesAproximadas'];
    return ResultadoSugestoes(
      sugestoes: sugestoes is List
          ? sugestoes
                .whereType<Map>()
                .map(
                  (item) =>
                      SugestaoLocal.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      semLocalizacao: sem is List
          ? sem
                .whereType<Map>()
                .map(
                  (item) => PessoaSemLocalizacao.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      localizacoesAproximadas: locais is List
          ? locais
                .whereType<Map>()
                .map(
                  (item) => PessoaLocalizacaoAproximada.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      modo: (json['modo'] ?? 'todos').toString(),
    );
  }
}

int? _comoInt(dynamic valor) {
  if (valor == null) return null;
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse(valor.toString());
}

double? _comoDouble(dynamic valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString());
}
