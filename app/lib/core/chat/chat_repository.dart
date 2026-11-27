import '../../data/models/conversa.dart';
import '../../data/models/grupo.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

class ChatRepository {
  final Future<String?> Function()? tokenProvider;
  final Future<void> Function()? onUnauthorized;

  ChatRepository({this.tokenProvider, this.onUnauthorized});

  Future<ApiClient> _criarCliente() {
    return ApiClient.create(
      tokenProvider: tokenProvider,
      onUnauthorized: onUnauthorized,
    );
  }

  Future<List<Conversa>> listarConversas() async {
    final client = await _criarCliente();
    try {
      final resposta = await client.get('/conversas');
      final mapa = _comoMapa(resposta);
      return _converteLista(mapa['conversas'], Conversa.fromJson);
    } finally {
      client.close();
    }
  }

  Future<Conversa> criarDireta(int usuarioId) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.post(
        '/conversas/diretas',
        body: {'usuarioId': usuarioId},
      );
      return _conversaDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<Conversa> buscarChatEvento(int eventoId) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.get('/eventos/$eventoId/chat');
      return _conversaDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<Conversa> criarChatEvento(int eventoId) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.post('/eventos/$eventoId/chat');
      return _conversaDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<void> marcarLida(int conversaId, {int? ultimaMensagemId}) async {
    final client = await _criarCliente();
    try {
      await client.post(
        '/conversas/$conversaId/lido',
        body: ultimaMensagemId == null
            ? null
            : {'ultimaMensagemId': ultimaMensagemId},
      );
    } finally {
      client.close();
    }
  }

  Future<GrupoCriado> criarGrupo(String nome, List<int> usuarioIds) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.post(
        '/grupos',
        body: {'nome': nome, 'usuarioIds': usuarioIds},
      );
      final mapa = _comoMapa(resposta);
      try {
        return GrupoCriado.fromJson(mapa);
      } on FormatException catch (erro) {
        throw ApiException(code: 'RESPOSTA_INVALIDA', message: erro.message);
      }
    } finally {
      client.close();
    }
  }

  Future<Grupo> buscarGrupo(int grupoId) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.get('/grupos/$grupoId');
      return _grupoDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<Grupo> adicionarMembrosGrupo(int grupoId, List<int> usuarioIds) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.post(
        '/grupos/$grupoId/membros',
        body: {'usuarioIds': usuarioIds},
      );
      return _grupoDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<Grupo> atualizarConfiguracaoGrupo(
    int grupoId, {
    required bool membrosPodemAdicionar,
  }) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.patch(
        '/grupos/$grupoId',
        body: {'membrosPodemAdicionar': membrosPodemAdicionar},
      );
      return _grupoDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<Grupo> transferirAdministracao(int grupoId, int usuarioId) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.patch(
        '/grupos/$grupoId/admin',
        body: {'usuarioId': usuarioId},
      );
      return _grupoDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<Grupo> removerMembroGrupo(int grupoId, int usuarioId) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.delete(
        '/grupos/$grupoId/membros/$usuarioId',
      );
      return _grupoDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<void> apagarConversa(int conversaId) async {
    final client = await _criarCliente();
    try {
      await client.delete('/conversas/$conversaId');
    } finally {
      client.close();
    }
  }

  Future<void> sairGrupo(int grupoId) async {
    final client = await _criarCliente();
    try {
      await client.post('/grupos/$grupoId/sair');
    } finally {
      client.close();
    }
  }

  Future<List<Mensagem>> listarMensagens(int conversaId, {int? afterId}) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.get(
        '/conversas/$conversaId/mensagens',
        query: afterId == null ? null : {'afterId': '$afterId'},
      );
      final mapa = _comoMapa(resposta);
      return _converteLista(mapa['mensagens'], Mensagem.fromJson);
    } finally {
      client.close();
    }
  }

  Future<Mensagem> enviarMensagem(int conversaId, String texto) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.post(
        '/conversas/$conversaId/mensagens',
        body: {'texto': texto},
      );
      final mapa = _comoMapa(resposta);
      final mensagem = mapa['mensagem'];
      if (mensagem is! Map) {
        throw const ApiException(
          code: 'RESPOSTA_INVALIDA',
          message: 'A API não retornou a mensagem enviada.',
        );
      }
      try {
        return Mensagem.fromJson(Map<String, dynamic>.from(mensagem));
      } on FormatException catch (erro) {
        throw ApiException(code: 'RESPOSTA_INVALIDA', message: erro.message);
      }
    } finally {
      client.close();
    }
  }

  Map<String, dynamic> _comoMapa(dynamic resposta) {
    if (resposta is! Map) {
      throw const ApiException(
        code: 'RESPOSTA_INVALIDA',
        message: 'A API não retornou dados de conversa válidos.',
      );
    }
    return Map<String, dynamic>.from(resposta);
  }

  Grupo _grupoDaResposta(dynamic resposta) {
    final mapa = _comoMapa(resposta);
    final grupo = mapa['grupo'] ?? mapa;
    if (grupo is! Map) {
      throw const ApiException(
        code: 'RESPOSTA_INVALIDA',
        message: 'A API não retornou um grupo válido.',
      );
    }
    try {
      return Grupo.fromJson(Map<String, dynamic>.from(grupo));
    } on FormatException catch (erro) {
      throw ApiException(code: 'RESPOSTA_INVALIDA', message: erro.message);
    }
  }

  Conversa _conversaDaResposta(dynamic resposta) {
    final mapa = _comoMapa(resposta);
    final conversa = mapa['conversa'] ?? mapa;
    if (conversa is! Map) {
      throw const ApiException(
        code: 'RESPOSTA_INVALIDA',
        message: 'A API não retornou uma conversa válida.',
      );
    }
    try {
      return Conversa.fromJson(Map<String, dynamic>.from(conversa));
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
