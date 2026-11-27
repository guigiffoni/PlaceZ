import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../../data/models/amizade.dart';

class ResultadoBuscaPagina {
  final List<ResultadoBuscaUsuario> usuarios;
  final bool temMais;
  final int pagina;

  const ResultadoBuscaPagina({
    required this.usuarios,
    required this.temMais,
    required this.pagina,
  });
}

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

  Future<ResultadoBuscaPagina> buscar(
    String termo, {
    int pagina = 1,
    int limite = 20,
  }) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.get(
        '/usuarios/busca',
        query: {'q': termo.trim(), 'pagina': '$pagina', 'limite': '$limite'},
      );
      final mapa = _comoMapa(resposta);
      return ResultadoBuscaPagina(
        usuarios: _converteLista(
          mapa['usuarios'],
          ResultadoBuscaUsuario.fromJson,
        ),
        temMais: mapa['temMais'] == true,
        pagina: mapa['pagina'] is num
            ? (mapa['pagina'] as num).toInt()
            : pagina,
      );
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

  Future<bool> favoritar(int usuarioId) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.put('/amigos/$usuarioId/favorito');
      return _comoMapa(resposta)['favorito'] == true;
    } finally {
      client.close();
    }
  }

  Future<bool> desfavoritar(int usuarioId) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.delete('/amigos/$usuarioId/favorito');
      return _comoMapa(resposta)['favorito'] == true;
    } finally {
      client.close();
    }
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
