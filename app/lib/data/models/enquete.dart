enum VotoDisponibilidade {
  disponivel,
  indisponivel;

  String get api =>
      this == VotoDisponibilidade.disponivel ? 'DISPONIVEL' : 'INDISPONIVEL';

  String get rotulo =>
      this == VotoDisponibilidade.disponivel ? 'Disponível' : 'Indisponível';

  static VotoDisponibilidade? fromApi(dynamic valor) {
    switch (valor?.toString().toUpperCase()) {
      case 'DISPONIVEL':
        return VotoDisponibilidade.disponivel;
      case 'INDISPONIVEL':
        return VotoDisponibilidade.indisponivel;
      default:
        return null;
    }
  }
}

class OpcaoDisponibilidade {
  final int id;
  final String data;
  final String horaInicio;
  final String horaFim;
  final int disponiveis;
  final int indisponiveis;
  final int totalVotos;
  final int percentual;
  final VotoDisponibilidade? meuVoto;

  const OpcaoDisponibilidade({
    required this.id,
    required this.data,
    required this.horaInicio,
    required this.horaFim,
    this.disponiveis = 0,
    this.indisponiveis = 0,
    this.totalVotos = 0,
    this.percentual = 0,
    this.meuVoto,
  });

  /// Data de calendário, sem deslocamento de fuso.
  DateTime get dataCalendario {
    final partes = data.split('-');
    if (partes.length != 3) return DateTime(2000, 1, 1);
    return DateTime(
      int.tryParse(partes[0]) ?? 2000,
      int.tryParse(partes[1]) ?? 1,
      int.tryParse(partes[2]) ?? 1,
    );
  }

  factory OpcaoDisponibilidade.fromJson(Map<String, dynamic> json) {
    final id = _comoInt(json['id']);
    final data = (json['data'] ?? '').toString();
    if (id == null || data.isEmpty) {
      throw const FormatException('Opção de data inválida na resposta da API.');
    }
    return OpcaoDisponibilidade(
      id: id,
      data: data,
      horaInicio: (json['horaInicio'] ?? '').toString(),
      horaFim: (json['horaFim'] ?? '').toString(),
      disponiveis: _comoInt(json['disponiveis']) ?? 0,
      indisponiveis: _comoInt(json['indisponiveis']) ?? 0,
      totalVotos: _comoInt(json['totalVotos']) ?? 0,
      percentual: _comoInt(json['percentual']) ?? 0,
      meuVoto: VotoDisponibilidade.fromApi(json['meuVoto']),
    );
  }
}

class EnqueteDisponibilidade {
  final int id;
  final int eventoId;
  final String dataInicio;
  final String dataFim;
  final List<int> diasSemana;
  final String horaInicio;
  final String horaFim;
  final int fusoOffsetMinutos;
  final List<OpcaoDisponibilidade> opcoes;

  const EnqueteDisponibilidade({
    required this.id,
    required this.eventoId,
    required this.dataInicio,
    required this.dataFim,
    this.diasSemana = const [],
    required this.horaInicio,
    required this.horaFim,
    this.fusoOffsetMinutos = 0,
    this.opcoes = const [],
  });

  factory EnqueteDisponibilidade.fromJson(Map<String, dynamic> json) {
    final id = _comoInt(json['id']);
    final eventoId = _comoInt(json['eventoId']);
    if (id == null || eventoId == null) {
      throw const FormatException(
        'Combinação de dias inválida na resposta da API.',
      );
    }

    final opcoes = json['opcoes'];
    final dias = json['diasSemana'];

    return EnqueteDisponibilidade(
      id: id,
      eventoId: eventoId,
      dataInicio: (json['dataInicio'] ?? '').toString(),
      dataFim: (json['dataFim'] ?? '').toString(),
      diasSemana: dias is List
          ? dias.map(_comoInt).whereType<int>().toList()
          : const [],
      horaInicio: (json['horaInicio'] ?? '').toString(),
      horaFim: (json['horaFim'] ?? '').toString(),
      fusoOffsetMinutos: _comoInt(json['fusoOffsetMinutos']) ?? 0,
      opcoes: opcoes is List
          ? opcoes
                .whereType<Map>()
                .map(
                  (item) => OpcaoDisponibilidade.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class ConsultaEnquete {
  final EnqueteDisponibilidade enquete;
  final OpcaoDisponibilidade? melhorDia;

  const ConsultaEnquete({required this.enquete, this.melhorDia});

  factory ConsultaEnquete.fromJson(Map<String, dynamic> json) {
    final enquete = json['enquete'];
    if (enquete is! Map) {
      throw const FormatException(
        'A API não retornou uma combinação de dias válida.',
      );
    }
    final melhor = json['melhorDia'];
    return ConsultaEnquete(
      enquete: EnqueteDisponibilidade.fromJson(
        Map<String, dynamic>.from(enquete),
      ),
      melhorDia: melhor is Map
          ? OpcaoDisponibilidade.fromJson(Map<String, dynamic>.from(melhor))
          : null,
    );
  }
}

class VotoEnquete {
  final int opcaoId;
  final VotoDisponibilidade status;

  const VotoEnquete({required this.opcaoId, required this.status});

  Map<String, dynamic> toJson() => {'opcaoId': opcaoId, 'status': status.api};
}

int? _comoInt(dynamic valor) {
  if (valor == null) return null;
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse(valor.toString());
}
