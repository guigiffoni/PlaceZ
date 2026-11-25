import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../../data/models/amizade.dart';

class FriendsRepository {
  final Future<String?> Function()? tokenProvider;
  final Future<void> Function()? onUnauthorized;

  FriendsRepository({this.tokenProvider, this.onUnauthorized});

  Future<ApiClient> _criarCliente() {
    return ApiClient.create(
      tokenProvider: tokenProvider,
      onUnauthorized: onUnauthorized,
    );
  }

  Future<List<ResultadoBuscaUsuario>> buscar(String termo) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.get(
        '/usuarios/busca',
        query: {'q': termo.trim()},
      );
      final mapa = _comoMapa(resposta);
      return _converteLista(mapa['usuarios'], ResultadoBuscaUsuario.fromJson);
    } finally {
      client.close();
    }
  }

  Future<List<Amigo>> listarAmigos() async {
    final client = await _criarCliente();
    try {
      final resposta = await client.get('/amigos');
      final mapa = _comoMapa(resposta);
      return _converteLista(mapa['amigos'], Amigo.fromJson);
    } finally {
      client.close();
    }
  }

  Future<SolicitacoesAmizade> listarSolicitacoes() async {
    final client = await _criarCliente();
    try {
      final resposta = await client.get('/amigos/solicitacoes');
      return SolicitacoesAmizade.fromJson(_comoMapa(resposta));
    } finally {
      client.close();
    }
  }

  Future<SolicitacaoAmizade> enviarSolicitacao(String username) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.post(
        '/amigos/solicitacoes',
        body: {'username': username.trim()},
      );
      return SolicitacaoAmizade.fromJson(_comoMapa(resposta));
    } finally {
      client.close();
    }
  }

  Future<void> aceitar(int solicitacaoId) async {
    await _acaoSimples(
      (client) => client.post('/amigos/solicitacoes/$solicitacaoId/aceitar'),
    );
  }

  Future<void> recusar(int solicitacaoId) async {
    await _acaoSimples(
      (client) => client.post('/amigos/solicitacoes/$solicitacaoId/recusar'),
    );
  }

  Future<void> cancelar(int solicitacaoId) async {
    await _acaoSimples(
      (client) => client.delete('/amigos/solicitacoes/$solicitacaoId'),
    );
  }

  Future<void> remover(int usuarioId) async {
    await _acaoSimples((client) => client.delete('/amigos/$usuarioId'));
  }

  Future<List<Bloqueio>> listarBloqueios() async {
    final client = await _criarCliente();
    try {
      final resposta = await client.get('/bloqueios');
      final mapa = _comoMapa(resposta);
      return _converteLista(mapa['bloqueios'], Bloqueio.fromJson);
    } finally {
      client.close();
    }
  }

  Future<void> bloquear(int usuarioId) async {
    await _acaoSimples(
      (client) => client.post('/bloqueios', body: {'usuarioId': usuarioId}),
    );
  }

  Future<void> desbloquear(int usuarioId) async {
    await _acaoSimples((client) => client.delete('/bloqueios/$usuarioId'));
  }

  Future<void> _acaoSimples(
    Future<dynamic> Function(ApiClient client) acao,
  ) async {
    final client = await _criarCliente();
    try {
      await acao(client);
    } finally {
      client.close();
    }
  }

  Map<String, dynamic> _comoMapa(dynamic resposta) {
    if (resposta is! Map) {
      throw const ApiException(
        code: 'RESPOSTA_INVALIDA',
        message: 'A API não retornou dados de amigos válidos.',
      );
    }
    return Map<String, dynamic>.from(resposta);
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
