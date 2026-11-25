import '../../data/models/evento.dart';
import '../../data/models/local.dart';
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

  const EventoEntrada({
    required this.titulo,
    this.descricao,
    this.inicioEm,
    this.fimEm,
    this.local,
    this.privado = true,
    this.permitirMembrosConvidar = false,
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

  Future<List<Evento>> listar({DateTime? de, DateTime? ate}) async {
    final client = await _criarCliente();
    try {
      final query = <String, String>{};
      if (de != null) query['de'] = de.toUtc().toIso8601String();
      if (ate != null) query['ate'] = ate.toUtc().toIso8601String();

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
