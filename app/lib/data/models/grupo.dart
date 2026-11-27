import 'amizade.dart';
import 'conversa.dart';

class GrupoMembro {
  final UsuarioResumo usuario;
  final String papel;
  final DateTime? criadoEm;

  const GrupoMembro({
    required this.usuario,
    this.papel = 'MEMBRO',
    this.criadoEm,
  });

  bool get isCriador => papel == 'CRIADOR';

  factory GrupoMembro.fromJson(Map<String, dynamic> json) {
    final usuario = json['usuario'];
    if (usuario is! Map) {
      throw const FormatException('Membro de grupo inválido.');
    }
    return GrupoMembro(
      usuario: UsuarioResumo.fromJson(Map<String, dynamic>.from(usuario)),
      papel: (json['papel'] ?? 'MEMBRO').toString(),
      criadoEm: _comoData(json['criadoEm']),
    );
  }
}

class Grupo {
  final int id;
  final String nome;
  final int criadorId;
  final int conversaId;
  final bool membrosPodemAdicionar;
  final DateTime? criadoEm;
  final List<GrupoMembro> membros;

  const Grupo({
    required this.id,
    required this.nome,
    required this.criadorId,
    required this.conversaId,
    this.membrosPodemAdicionar = false,
    this.criadoEm,
    this.membros = const [],
  });

  bool souCriador(int? usuarioId) => criadorId == usuarioId;

  factory Grupo.fromJson(Map<String, dynamic> json) {
    final id = _comoInt(json['id']);
    final conversaId = _comoInt(json['conversaId']);
    final nome = (json['nome'] ?? '').toString().trim();
    if (id == null || conversaId == null || nome.isEmpty) {
      throw const FormatException('Grupo inválido na resposta da API.');
    }

    final membros = json['membros'];
    return Grupo(
      id: id,
      nome: nome,
      criadorId: _comoInt(json['criadorId']) ?? 0,
      conversaId: conversaId,
      membrosPodemAdicionar: json['membrosPodemAdicionar'] == true,
      criadoEm: _comoData(json['criadoEm']),
      membros: membros is List
          ? membros
                .whereType<Map>()
                .map(
                  (item) =>
                      GrupoMembro.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
  }
}

class GrupoCriado {
  final Grupo grupo;
  final Conversa conversa;

  const GrupoCriado({required this.grupo, required this.conversa});

  factory GrupoCriado.fromJson(Map<String, dynamic> json) {
    final grupo = json['grupo'];
    final conversa = json['conversa'];
    if (grupo is! Map || conversa is! Map) {
      throw const FormatException('A API não retornou o grupo criado.');
    }
    return GrupoCriado(
      grupo: Grupo.fromJson(Map<String, dynamic>.from(grupo)),
      conversa: Conversa.fromJson(Map<String, dynamic>.from(conversa)),
    );
  }
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
  if (valor is num) {
    return DateTime.fromMillisecondsSinceEpoch(valor.toInt(), isUtc: true);
  }
  return DateTime.tryParse(valor.toString())?.toUtc();
}
