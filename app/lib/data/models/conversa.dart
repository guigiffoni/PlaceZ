import 'amizade.dart';

class UltimaMensagem {
  final int id;
  final String texto;
  final int? autorId;
  final DateTime? criadoEm;

  const UltimaMensagem({
    required this.id,
    required this.texto,
    this.autorId,
    this.criadoEm,
  });

  factory UltimaMensagem.fromJson(Map<String, dynamic> json) {
    return UltimaMensagem(
      id: _comoInt(json['id']) ?? 0,
      texto: (json['texto'] ?? '').toString(),
      autorId: _comoInt(json['autorId']),
      criadoEm: _comoData(json['criadoEm']),
    );
  }
}

class Conversa {
  final int id;
  final String tipo;
  final int? eventoId;
  final UsuarioResumo? outroUsuario;
  final String? tituloCache;
  final UltimaMensagem? ultimaMensagem;
  final DateTime? criadoEm;
  final DateTime? atualizadoEm;
  final bool bloqueada;
  final bool podeEnviar;

  const Conversa({
    required this.id,
    this.tipo = 'DIRETA',
    this.eventoId,
    this.outroUsuario,
    this.tituloCache,
    this.ultimaMensagem,
    this.criadoEm,
    this.atualizadoEm,
    this.bloqueada = false,
    this.podeEnviar = true,
  });

  String get nome => outroUsuario?.nome ?? tituloCache ?? 'Conversa';

  String get iniciais {
    if (outroUsuario != null) return outroUsuario!.iniciais;
    final partes = nome
        .trim()
        .split(RegExp(r'\s+'))
        .where((parte) => parte.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  factory Conversa.fromJson(Map<String, dynamic> json) {
    final id = _comoInt(json['id']);
    if (id == null) {
      throw const FormatException('Conversa inválida na resposta da API.');
    }

    final outro = json['outroUsuario'];
    final ultima = json['ultimaMensagem'];
    final titulo = (json['titulo'] ?? '').toString().trim();

    return Conversa(
      id: id,
      tipo: (json['tipo'] ?? 'DIRETA').toString(),
      eventoId: _comoInt(json['eventoId']),
      outroUsuario: outro is Map
          ? UsuarioResumo.fromJson(Map<String, dynamic>.from(outro))
          : null,
      tituloCache: titulo.isEmpty ? null : titulo,
      ultimaMensagem: ultima is Map
          ? UltimaMensagem.fromJson(Map<String, dynamic>.from(ultima))
          : null,
      criadoEm: _comoData(json['criadoEm']),
      atualizadoEm: _comoData(json['atualizadoEm']),
      bloqueada: _comoBool(json['bloqueada']),
      podeEnviar: _comoBool(json['podeEnviar'], padrao: true),
    );
  }

  Map<String, dynamic> toMap() {
    final referencia =
        ultimaMensagem?.criadoEm ?? atualizadoEm ?? criadoEm ?? DateTime.now();
    return {
      'id': id,
      'tipo': tipo,
      'evento_id': eventoId,
      'titulo': nome,
      'outro_usuario_id': outroUsuario?.id,
      'ultima_mensagem': ultimaMensagem?.texto,
      'atualizado_em': referencia.toUtc().millisecondsSinceEpoch,
    };
  }

  factory Conversa.fromMap(Map<String, dynamic> map) {
    final atualizado = _comoData(map['atualizado_em']);
    final texto = (map['ultima_mensagem'] ?? '').toString();
    return Conversa(
      id: _comoInt(map['id']) ?? 0,
      tipo: (map['tipo'] ?? 'DIRETA').toString(),
      eventoId: _comoInt(map['evento_id']),
      tituloCache: (map['titulo'] ?? '').toString().trim().isEmpty
          ? null
          : map['titulo'].toString(),
      ultimaMensagem: texto.isEmpty
          ? null
          : UltimaMensagem(id: 0, texto: texto, criadoEm: atualizado),
      atualizadoEm: atualizado,
      podeEnviar: true,
    );
  }
}

class Mensagem {
  final int id;
  final int conversaId;
  final UsuarioResumo? autor;
  final int? autorId;
  final String texto;
  final DateTime? criadoEm;

  const Mensagem({
    required this.id,
    required this.conversaId,
    this.autor,
    this.autorId,
    required this.texto,
    this.criadoEm,
  });

  bool ehMinha(int? meuUsuarioId) => autorId == meuUsuarioId;

  factory Mensagem.fromJson(Map<String, dynamic> json) {
    final id = _comoInt(json['id']);
    final conversaId = _comoInt(json['conversaId']);
    if (id == null || conversaId == null) {
      throw const FormatException('Mensagem inválida na resposta da API.');
    }
    final autor = json['autor'];
    final autorObj = autor is Map
        ? UsuarioResumo.fromJson(Map<String, dynamic>.from(autor))
        : null;

    return Mensagem(
      id: id,
      conversaId: conversaId,
      autor: autorObj,
      autorId: autorObj?.id ?? _comoInt(json['autorId']),
      texto: (json['texto'] ?? '').toString(),
      criadoEm: _comoData(json['criadoEm']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversa_id': conversaId,
      'autor_id': autorId ?? autor?.id,
      'texto': texto,
      'criado_em': criadoEm?.toUtc().millisecondsSinceEpoch ?? 0,
    };
  }

  factory Mensagem.fromMap(Map<String, dynamic> map) {
    return Mensagem(
      id: _comoInt(map['id']) ?? 0,
      conversaId: _comoInt(map['conversa_id']) ?? 0,
      autorId: _comoInt(map['autor_id']),
      texto: (map['texto'] ?? '').toString(),
      criadoEm: _comoData(map['criado_em']),
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

bool _comoBool(dynamic valor, {bool padrao = false}) {
  if (valor == null) return padrao;
  if (valor is bool) return valor;
  if (valor is num) return valor != 0;
  return valor == 'S' || valor == '1' || valor == 'true';
}
