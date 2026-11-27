import 'amizade.dart';
import 'local.dart';

enum RsvpStatus {
  vou,
  talvez;

  String get api => this == RsvpStatus.vou ? 'VOU' : 'TALVEZ';

  String get rotulo => this == RsvpStatus.vou ? 'Vou' : 'Talvez';

  static RsvpStatus? fromApi(dynamic valor) {
    switch (valor?.toString().toUpperCase()) {
      case 'VOU':
        return RsvpStatus.vou;
      case 'TALVEZ':
        return RsvpStatus.talvez;
      default:
        return null;
    }
  }
}

class ContagemRsvp {
  final int vou;
  final int talvez;
  final int semResposta;

  const ContagemRsvp({this.vou = 0, this.talvez = 0, this.semResposta = 0});

  static const vazia = ContagemRsvp();

  int get total => vou + talvez + semResposta;

  factory ContagemRsvp.fromJson(Map<String, dynamic> json) {
    return ContagemRsvp(
      vou: _comoInt(json['vou']) ?? 0,
      talvez: _comoInt(json['talvez']) ?? 0,
      semResposta: _comoInt(json['semResposta']) ?? 0,
    );
  }
}

class ConvidadoEvento {
  final UsuarioResumo usuario;
  final String papel;
  final RsvpStatus? rsvp;
  final UsuarioResumo? convidadoPor;
  final DateTime? criadoEm;
  final DateTime? respondidoEm;

  const ConvidadoEvento({
    required this.usuario,
    this.papel = 'CONVIDADO',
    this.rsvp,
    this.convidadoPor,
    this.criadoEm,
    this.respondidoEm,
  });

  bool get isCriador => papel == 'CRIADOR';

  factory ConvidadoEvento.fromJson(Map<String, dynamic> json) {
    final usuario = json['usuario'];
    if (usuario is! Map) {
      throw const FormatException('Convidado inválido na resposta da API.');
    }
    final convidadoPor = json['convidadoPor'];

    return ConvidadoEvento(
      usuario: UsuarioResumo.fromJson(Map<String, dynamic>.from(usuario)),
      papel: (json['papel'] ?? 'CONVIDADO').toString(),
      rsvp: RsvpStatus.fromApi(json['rsvp']),
      convidadoPor: convidadoPor is Map
          ? UsuarioResumo.fromJson(Map<String, dynamic>.from(convidadoPor))
          : null,
      criadoEm: _comoData(json['criadoEm']),
      respondidoEm: _comoData(json['respondidoEm']),
    );
  }
}

class Evento {
  final int? id;
  final String titulo;
  final String? descricao;
  final DateTime? inicioEm;
  final DateTime? fimEm;
  final Local? local;
  final UsuarioResumo? criador;
  final int? criadorId;
  final bool privado;
  final bool permitirMembrosConvidar;
  final String status;
  final DateTime? criadoEm;
  final DateTime? atualizadoEm;
  final List<ConvidadoEvento> convidados;
  final ContagemRsvp contagem;
  final RsvpStatus? meuRsvp;
  final bool souCriador;
  final bool podeConvidar;
  final bool temImagem;
  final DateTime? imagemAtualizadaEm;

  Evento({
    this.id,
    required this.titulo,
    this.descricao,
    this.inicioEm,
    this.fimEm,
    this.local,
    this.criador,
    this.criadorId,
    this.privado = true,
    this.permitirMembrosConvidar = false,
    this.status = 'CONFIRMADO',
    this.criadoEm,
    this.atualizadoEm,
    this.temImagem = false,
    this.imagemAtualizadaEm,
    this.convidados = const [],
    this.contagem = ContagemRsvp.vazia,
    this.meuRsvp,
    this.souCriador = false,
    this.podeConvidar = false,
  });

  int? get localId => local?.id;

  bool get cancelado => status == 'CANCELADO';

  bool get confirmado => status == 'CONFIRMADO';

  Evento copyWith({
    int? id,
    String? titulo,
    String? descricao,
    DateTime? inicioEm,
    DateTime? fimEm,
    Local? local,
    UsuarioResumo? criador,
    int? criadorId,
    bool? privado,
    bool? permitirMembrosConvidar,
    String? status,
    DateTime? criadoEm,
    DateTime? atualizadoEm,
    bool? temImagem,
    DateTime? imagemAtualizadaEm,
    List<ConvidadoEvento>? convidados,
    ContagemRsvp? contagem,
    RsvpStatus? meuRsvp,
    bool? souCriador,
    bool? podeConvidar,
  }) {
    return Evento(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      inicioEm: inicioEm ?? this.inicioEm,
      fimEm: fimEm ?? this.fimEm,
      local: local ?? this.local,
      criador: criador ?? this.criador,
      criadorId: criadorId ?? this.criadorId,
      privado: privado ?? this.privado,
      permitirMembrosConvidar:
          permitirMembrosConvidar ?? this.permitirMembrosConvidar,
      status: status ?? this.status,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      temImagem: temImagem ?? this.temImagem,
      imagemAtualizadaEm: imagemAtualizadaEm ?? this.imagemAtualizadaEm,
      convidados: convidados ?? this.convidados,
      contagem: contagem ?? this.contagem,
      meuRsvp: meuRsvp ?? this.meuRsvp,
      souCriador: souCriador ?? this.souCriador,
      podeConvidar: podeConvidar ?? this.podeConvidar,
    );
  }

  factory Evento.fromJson(Map<String, dynamic> json) {
    final id = _comoInt(json['id']);
    final titulo = (json['titulo'] ?? '').toString().trim();
    if (id == null || titulo.isEmpty) {
      throw const FormatException('Evento inválido na resposta da API.');
    }

    final local = json['local'];
    final criador = json['criador'];
    final contagem = json['contagem'];
    final convidados = json['convidados'];

    return Evento(
      id: id,
      titulo: titulo,
      descricao: _texto(json['descricao']),
      inicioEm: _comoData(json['inicioEm']),
      fimEm: _comoData(json['fimEm']),
      local: local is Map
          ? Local.fromJson(Map<String, dynamic>.from(local))
          : null,
      criador: criador is Map
          ? UsuarioResumo.fromJson(Map<String, dynamic>.from(criador))
          : null,
      criadorId: _comoInt(json['criadorId']) ?? _idDoCriador(criador),
      privado: _comoBool(json['privado'], padrao: true),
      permitirMembrosConvidar: _comoBool(
        json['permitirMembrosConvidar'],
        padrao: false,
      ),
      status: (json['status'] ?? 'CONFIRMADO').toString(),
      criadoEm: _comoData(json['criadoEm']),
      atualizadoEm: _comoData(json['atualizadoEm']),
      temImagem: json['temImagem'] == true,
      imagemAtualizadaEm: _comoData(json['imagemAtualizadaEm']),
      convidados: convidados is List
          ? convidados
                .whereType<Map>()
                .map(
                  (item) =>
                      ConvidadoEvento.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      contagem: contagem is Map
          ? ContagemRsvp.fromJson(Map<String, dynamic>.from(contagem))
          : ContagemRsvp.vazia,
      meuRsvp: RsvpStatus.fromApi(json['meuRsvp']),
      souCriador: _comoBool(json['souCriador'], padrao: false),
      podeConvidar: _comoBool(json['podeConvidar'], padrao: false),
    );
  }

  /// Serialização usada apenas como cache local (tabela cache_evento).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descricao': descricao,
      'inicio_em': inicioEm?.toUtc().millisecondsSinceEpoch,
      'fim_em': fimEm?.toUtc().millisecondsSinceEpoch,
      'local_id': local?.id,
      'criador_id': criadorId ?? criador?.id,
      'privado': privado ? 1 : 0,
      'permitir_membros_convidar': permitirMembrosConvidar ? 1 : 0,
      'status': status,
      'criado_em': criadoEm?.toUtc().millisecondsSinceEpoch ?? 0,
      'atualizado_em': atualizadoEm?.toUtc().millisecondsSinceEpoch ?? 0,
      'local_nome': local?.nome,
      'local_endereco': local?.endereco,
      'local_categoria': local?.categoria,
      'local_distancia_metros': local?.distanciaMetros,
    };
  }

  factory Evento.fromMap(Map<String, dynamic> map) {
    final localId = _comoInt(map['local_id']);
    return Evento(
      id: _comoInt(map['id']),
      titulo: (map['titulo'] ?? '').toString(),
      descricao: _texto(map['descricao']),
      inicioEm: _comoData(map['inicio_em']),
      fimEm: _comoData(map['fim_em']),
      local: localId == null
          ? null
          : Local(
              id: localId,
              nome: _texto(map['local_nome']),
              endereco: _texto(map['local_endereco']),
              categoria: _texto(map['local_categoria']),
              distanciaMetros: _comoDouble(map['local_distancia_metros']),
              latitude: _comoDouble(map['local_latitude']),
              longitude: _comoDouble(map['local_longitude']),
            ),
      criadorId: _comoInt(map['criador_id']),
      privado: _comoBool(map['privado'], padrao: true),
      permitirMembrosConvidar: _comoBool(
        map['permitir_membros_convidar'],
        padrao: false,
      ),
      status: (map['status'] ?? 'CONFIRMADO').toString(),
      criadoEm: _comoData(map['criado_em']),
      atualizadoEm: _comoData(map['atualizado_em']),
      contagem: ContagemRsvp(
        vou: _comoInt(map['total_vou']) ?? 0,
        talvez: _comoInt(map['total_talvez']) ?? 0,
        semResposta: _comoInt(map['total_sem_resposta']) ?? 0,
      ),
      meuRsvp: RsvpStatus.fromApi(map['meu_rsvp']),
      souCriador: _comoBool(map['sou_criador'], padrao: false),
      podeConvidar: _comoBool(map['pode_convidar'], padrao: false),
    );
  }
}

int? _idDoCriador(dynamic criador) {
  if (criador is! Map) return null;
  return _comoInt(criador['id']);
}

String? _texto(dynamic valor) {
  if (valor == null) return null;
  final texto = valor.toString().trim();
  return texto.isEmpty ? null : texto;
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

DateTime? _comoData(dynamic valor) {
  if (valor == null) return null;
  if (valor is DateTime) return valor.toUtc();
  if (valor is num) {
    return DateTime.fromMillisecondsSinceEpoch(valor.toInt(), isUtc: true);
  }
  return DateTime.tryParse(valor.toString())?.toUtc();
}

bool _comoBool(dynamic valor, {required bool padrao}) {
  if (valor == null) return padrao;
  if (valor is bool) return valor;
  if (valor is num) return valor != 0;
  return valor == 'S' || valor == '1' || valor == 'true';
}
