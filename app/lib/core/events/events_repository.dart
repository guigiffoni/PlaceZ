import 'dart:convert';

import '../../data/models/enquete.dart';
import '../../data/models/evento.dart';
import '../../data/models/evento_resumo.dart';
import '../../data/models/local.dart';
import '../../data/models/ranking_pessoa.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

/// Dados editáveis de um evento enviados à API.
class EventoEntrada {
  final String titulo;
  final String? descricao;
  final DateTime? inicioEm;
  final DateTime? fimEm;
  final Local? local;
  final bool privado;
  final bool permitirMembrosConvidar;
  final bool rascunho;

  const EventoEntrada({
    required this.titulo,
    this.descricao,
    this.inicioEm,
    this.fimEm,
    this.local,
    this.privado = true,
    this.permitirMembrosConvidar = false,
    this.rascunho = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'descricao': descricao,
      'inicioEm': inicioEm?.toUtc().toIso8601String(),
      'fimEm': fimEm?.toUtc().toIso8601String(),
      'local': local?.toJson(),
      'privado': privado,
      'permitirMembrosConvidar': permitirMembrosConvidar,
      'rascunho': rascunho,
    };
  }

  /// A edição de dados usa PATCH sem as configurações; a permissão de convite
  /// e a privacidade têm rota própria.
  Map<String, dynamic> toPatchJson() {
    return {
      'titulo': titulo,
      'descricao': descricao,
      'inicioEm': inicioEm?.toUtc().toIso8601String(),
      'fimEm': fimEm?.toUtc().toIso8601String(),
      'local': local?.toJson(),
    };
  }
}

/// Configuração usada para gerar as opções da combinação de dias.
class EnqueteEntrada {
  final String dataInicio;
  final String dataFim;
  final List<int> diasSemana;
  final String horaInicio;
  final String horaFim;
  final int fusoOffsetMinutos;

  const EnqueteEntrada({
    required this.dataInicio,
    required this.dataFim,
    required this.diasSemana,
    required this.horaInicio,
    required this.horaFim,
    required this.fusoOffsetMinutos,
  });

  Map<String, dynamic> toJson() => {
    'dataInicio': dataInicio,
    'dataFim': dataFim,
    'diasSemana': diasSemana,
    'horaInicio': horaInicio,
    'horaFim': horaFim,
    'fusoOffsetMinutos': fusoOffsetMinutos,
  };
}

class EventsRepository {
  final Future<String?> Function()? tokenProvider;
  final Future<void> Function()? onUnauthorized;

  EventsRepository({this.tokenProvider, this.onUnauthorized});

  Future<ApiClient> _criarCliente() {
    return ApiClient.create(
      tokenProvider: tokenProvider,
      onUnauthorized: onUnauthorized,
    );
  }

  Future<List<Evento>> listar({
    DateTime? de,
    DateTime? ate,
    List<int> pessoas = const [],
  }) async {
    final client = await _criarCliente();
    try {
      final query = <String, String>{};
      if (de != null) query['de'] = de.toUtc().toIso8601String();
      if (ate != null) query['ate'] = ate.toUtc().toIso8601String();
      if (pessoas.isNotEmpty) query['pessoas'] = pessoas.join(',');

      final resposta = await client.get(
        '/eventos',
        query: query.isEmpty ? null : query,
      );
      final mapa = _comoMapa(resposta);
      return _converteLista(mapa['eventos'], Evento.fromJson);
    } finally {
      client.close();
    }
  }

  Future<List<Evento>> rascunhos() async {
    final client = await _criarCliente();
    try {
      final resposta = await client.get('/eventos/rascunhos');
      final mapa = _comoMapa(resposta);
      return _converteLista(mapa['eventos'], Evento.fromJson);
    } finally {
      client.close();
    }
  }

  Future<List<EventoResumo>> listarGerenciaveis() async {
    final client = await _criarCliente();
    try {
      final resposta = await client.get('/eventos/gerenciaveis');
      final mapa = _comoMapa(resposta);
      final eventos = mapa['eventos'];
      if (eventos is! List) return const [];
      try {
        return eventos
            .whereType<Map>()
            .map(
              (item) => EventoResumo.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      } on FormatException catch (erro) {
        throw ApiException(code: 'RESPOSTA_INVALIDA', message: erro.message);
      }
    } finally {
      client.close();
    }
  }

  Future<Evento> atualizarLocal(int id, Local local) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.patch(
        '/eventos/$id',
        body: {'local': local.toJson()},
      );
      return _eventoDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<void> atualizarImagem(int id, List<int> bytes, String mime) async {
    final client = await _criarCliente();
    try {
      await client.put(
        '/eventos/$id/imagem',
        body: {'imagemBase64': base64Encode(bytes), 'mime': mime},
      );
    } finally {
      client.close();
    }
  }

  Future<void> removerImagem(int id) async {
    final client = await _criarCliente();
    try {
      await client.delete('/eventos/$id/imagem');
    } finally {
      client.close();
    }
  }

  Future<List<PessoaRanking>> rankingPessoas() async {
    final client = await _criarCliente();
    try {
      final resposta = await client.get('/calendario/pessoas-frequentes');
      final mapa = _comoMapa(resposta);
      final pessoas = mapa['pessoas'];
      if (pessoas is! List) return const [];
      try {
        return pessoas
            .whereType<Map>()
            .map(
              (item) => PessoaRanking.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      } on FormatException catch (erro) {
        throw ApiException(code: 'RESPOSTA_INVALIDA', message: erro.message);
      }
    } finally {
      client.close();
    }
  }

  Future<Evento> detalhar(int id) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.get('/eventos/$id');
      return _eventoDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<Evento> criar(
    EventoEntrada entrada, {
    List<int> convidadoIds = const [],
  }) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.post(
        '/eventos',
        body: {...entrada.toJson(), 'convidadoIds': convidadoIds},
      );
      return _eventoDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<Evento> atualizar(int id, EventoEntrada entrada) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.patch(
        '/eventos/$id',
        body: entrada.toPatchJson(),
      );
      return _eventoDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<void> cancelar(int id) async {
    final client = await _criarCliente();
    try {
      await client.delete('/eventos/$id');
    } finally {
      client.close();
    }
  }

  Future<Evento> convidar(int id, List<int> usuarioIds) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.post(
        '/eventos/$id/convidados',
        body: {'usuarioIds': usuarioIds},
      );
      return _eventoDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<Evento> convidarTodos(int id) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.post('/eventos/$id/convidados/todos');
      return _eventoDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<Evento?> removerConvidado(int id, int usuarioId) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.delete(
        '/eventos/$id/convidados/$usuarioId',
      );
      if (resposta == null) return null;
      return _eventoDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<Evento> responderRsvp(int id, RsvpStatus rsvp) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.patch(
        '/eventos/$id/rsvp',
        body: {'rsvp': rsvp.api},
      );
      return _eventoDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<Evento> atualizarConfig(
    int id, {
    bool? privado,
    bool? permitirMembrosConvidar,
  }) async {
    final client = await _criarCliente();
    try {
      final corpo = <String, dynamic>{};
      if (privado != null) corpo['privado'] = privado;
      if (permitirMembrosConvidar != null) {
        corpo['permitirMembrosConvidar'] = permitirMembrosConvidar;
      }

      final resposta = await client.patch('/eventos/$id/config', body: corpo);
      return _eventoDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<ConsultaEnquete> consultarEnquete(int eventoId) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.get('/eventos/$eventoId/enquete');
      return _consultaDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<ConsultaEnquete> criarEnquete(
    int eventoId,
    EnqueteEntrada entrada,
  ) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.post(
        '/eventos/$eventoId/enquete',
        body: entrada.toJson(),
      );
      return _consultaDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<ConsultaEnquete> votarEnquete(
    int eventoId,
    List<VotoEnquete> votos,
  ) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.put(
        '/eventos/$eventoId/enquete/votos',
        body: {'votos': votos.map((voto) => voto.toJson()).toList()},
      );
      return _consultaDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<Evento> aplicarMelhorDia(int eventoId) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.post(
        '/eventos/$eventoId/enquete/aplicar-melhor-dia',
      );
      return _eventoDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  ConsultaEnquete _consultaDaResposta(dynamic resposta) {
    final mapa = _comoMapa(resposta);
    try {
      return ConsultaEnquete.fromJson(mapa);
    } on FormatException catch (erro) {
      throw ApiException(code: 'RESPOSTA_INVALIDA', message: erro.message);
    }
  }

  Map<String, dynamic> _comoMapa(dynamic resposta) {
    if (resposta is! Map) {
      throw const ApiException(
        code: 'RESPOSTA_INVALIDA',
        message: 'A API não retornou dados de eventos válidos.',
      );
    }
    return Map<String, dynamic>.from(resposta);
  }

  Evento _eventoDaResposta(dynamic resposta) {
    final mapa = _comoMapa(resposta);
    final evento = mapa['evento'] ?? mapa;
    if (evento is! Map) {
      throw const ApiException(
        code: 'RESPOSTA_INVALIDA',
        message: 'A API não retornou um evento válido.',
      );
    }
    try {
      return Evento.fromJson(Map<String, dynamic>.from(evento));
    } on FormatException catch (erro) {
      throw ApiException(code: 'RESPOSTA_INVALIDA', message: erro.message);
    }
  }

  List<T> _converteLista<T>(
    dynamic valor,
    T Function(Map<String, dynamic>) converter,
  ) {
    if (valor is! List) return const [];
    try {
      return valor
          .whereType<Map>()
          .map((item) => converter(Map<String, dynamic>.from(item)))
          .toList();
    } on FormatException catch (erro) {
      throw ApiException(code: 'RESPOSTA_INVALIDA', message: erro.message);
    }
  }
}
