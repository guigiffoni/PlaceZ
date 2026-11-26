import '../../data/models/conversa.dart';
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
