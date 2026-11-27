import 'localizacao.dart';

enum RelacaoUsuario {
  nenhuma,
  amigos,
  solicitacaoEnviada,
  solicitacaoRecebida;

  static RelacaoUsuario fromApi(String? valor) {
    switch (valor) {
      case 'amigos':
        return RelacaoUsuario.amigos;
      case 'solicitacao_enviada':
        return RelacaoUsuario.solicitacaoEnviada;
      case 'solicitacao_recebida':
        return RelacaoUsuario.solicitacaoRecebida;
      default:
        return RelacaoUsuario.nenhuma;
    }
  }
}

class UsuarioResumo {
  final int id;
  final String nome;
  final String username;

  const UsuarioResumo({
    required this.id,
    required this.nome,
    required this.username,
  });

  String get identificador => '@$username';

  String get iniciais {
    final partes = nome
        .trim()
        .split(RegExp(r'\s+'))
        .where((parte) => parte.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    final primeira = partes.first[0].toUpperCase();
    if (partes.length == 1) return primeira;
    return '$primeira${partes.last[0].toUpperCase()}';
  }

  factory UsuarioResumo.fromJson(Map<String, dynamic> json) {
    final id = _comoInt(json['id']);
    final nome = (json['nome'] ?? '').toString().trim();
    final username = (json['username'] ?? '').toString().trim();

    if (id == null || nome.isEmpty || username.isEmpty) {
      throw const FormatException('Usuário inválido na resposta da API.');
    }

    return UsuarioResumo(id: id, nome: nome, username: username);
  }
}

class Amigo {
  final int amizadeId;
  final UsuarioResumo usuario;
  final LocalizacaoAproximada? localizacaoAproximada;
  final bool favorito;

  const Amigo({
    required this.amizadeId,
    required this.usuario,
    this.localizacaoAproximada,
    this.favorito = false,
  });

  Amigo copyWith({
    int? amizadeId,
    UsuarioResumo? usuario,
    LocalizacaoAproximada? localizacaoAproximada,
    bool? favorito,
  }) {
    return Amigo(
      amizadeId: amizadeId ?? this.amizadeId,
      usuario: usuario ?? this.usuario,
      localizacaoAproximada:
          localizacaoAproximada ?? this.localizacaoAproximada,
      favorito: favorito ?? this.favorito,
    );
  }

  factory Amigo.fromJson(Map<String, dynamic> json) {
    final amizadeId = _comoInt(json['amizadeId']);
    final usuario = json['usuario'];

    if (amizadeId == null || usuario is! Map) {
      throw const FormatException('Amizade inválida na resposta da API.');
    }

    return Amigo(
      amizadeId: amizadeId,
      usuario: UsuarioResumo.fromJson(Map<String, dynamic>.from(usuario)),
      localizacaoAproximada: LocalizacaoAproximada.fromResposta(
        json['localizacaoAproximada'],
      ),
      favorito: json['favorito'] == true,
    );
  }
}

class SolicitacaoAmizade {
  final int id;
  final UsuarioResumo usuario;
  final DateTime? criadoEm;

  const SolicitacaoAmizade({
    required this.id,
    required this.usuario,
    this.criadoEm,
  });

  factory SolicitacaoAmizade.fromJson(Map<String, dynamic> json) {
    final id = _comoInt(json['id']);
    final usuario = json['usuario'];

    if (id == null || usuario is! Map) {
      throw const FormatException('Solicitação inválida na resposta da API.');
    }

    return SolicitacaoAmizade(
      id: id,
      usuario: UsuarioResumo.fromJson(Map<String, dynamic>.from(usuario)),
      criadoEm: _comoData(json['criadoEm']),
    );
  }
}

class SolicitacoesAmizade {
  final List<SolicitacaoAmizade> recebidas;
  final List<SolicitacaoAmizade> enviadas;

  const SolicitacoesAmizade({required this.recebidas, required this.enviadas});

  static const vazia = SolicitacoesAmizade(recebidas: [], enviadas: []);

  factory SolicitacoesAmizade.fromJson(Map<String, dynamic> json) {
    return SolicitacoesAmizade(
      recebidas: _lista(json['recebidas'], SolicitacaoAmizade.fromJson),
      enviadas: _lista(json['enviadas'], SolicitacaoAmizade.fromJson),
    );
  }
}

class ResultadoBuscaUsuario {
  final UsuarioResumo usuario;
  final RelacaoUsuario relacao;
  final int? solicitacaoId;

  const ResultadoBuscaUsuario({
    required this.usuario,
    required this.relacao,
    this.solicitacaoId,
  });

  factory ResultadoBuscaUsuario.fromJson(Map<String, dynamic> json) {
    final usuario = json['usuario'];
    if (usuario is! Map) {
      throw const FormatException(
        'Resultado de busca inválido na resposta da API.',
      );
    }

    return ResultadoBuscaUsuario(
      usuario: UsuarioResumo.fromJson(Map<String, dynamic>.from(usuario)),
      relacao: RelacaoUsuario.fromApi(json['relacao']?.toString()),
      solicitacaoId: _comoInt(json['solicitacaoId']),
    );
  }
}

class Bloqueio {
  final UsuarioResumo usuario;
  final DateTime? criadoEm;

  const Bloqueio({required this.usuario, this.criadoEm});

  factory Bloqueio.fromJson(Map<String, dynamic> json) {
    final usuario = json['usuario'];
    if (usuario is! Map) {
      throw const FormatException('Bloqueio inválido na resposta da API.');
    }

    return Bloqueio(
      usuario: UsuarioResumo.fromJson(Map<String, dynamic>.from(usuario)),
      criadoEm: _comoData(json['criadoEm']),
    );
  }
}

List<T> _lista<T>(dynamic valor, T Function(Map<String, dynamic>) converter) {
  if (valor is! List) return const [];
  return valor
      .whereType<Map>()
      .map((item) => converter(Map<String, dynamic>.from(item)))
      .toList();
}

int? _comoInt(dynamic valor) {
  if (valor == null) return null;
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse(valor.toString());
}

DateTime? _comoData(dynamic valor) {
  if (valor == null) return null;
  return DateTime.tryParse(valor.toString())?.toUtc();
}
