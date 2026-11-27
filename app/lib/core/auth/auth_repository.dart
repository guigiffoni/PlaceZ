import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'auth_session.dart';

class AuthRepository {
  final Future<String?> Function()? tokenProvider;
  final Future<void> Function()? onUnauthorized;

  AuthRepository({this.tokenProvider, this.onUnauthorized});

  Future<ApiClient> _criarCliente({bool tratar401 = true}) {
    return ApiClient.create(
      tokenProvider: tokenProvider,
      onUnauthorized: tratar401 ? onUnauthorized : null,
    );
  }

  Future<AuthSession> login({required String username, required String senha}) {
    return _autenticar('/auth/login', {'username': username, 'senha': senha});
  }

  Future<AuthSession> registro({
    required String nome,
    required String username,
    required String senha,
  }) {
    return _autenticar('/auth/registro', {
      'nome': nome,
      'username': username,
      'senha': senha,
    });
  }

  Future<AuthSession> _autenticar(
    String caminho,
    Map<String, dynamic> corpo,
  ) async {
    // Login/registro não usam onUnauthorized: um 401 aqui é credencial
    // inválida, não sessão expirada.
    final client = await _criarCliente(tratar401: false);
    try {
      final resposta = await client.post(caminho, body: corpo);
      return _sessaoDaResposta(resposta);
    } finally {
      client.close();
    }
  }

  Future<void> logout() async {
    final client = await _criarCliente();
    try {
      await client.post('/auth/logout');
    } finally {
      client.close();
    }
  }

  Future<AuthUsuario> me() async {
    final client = await _criarCliente();
    try {
      final resposta = await client.get('/me');
      if (resposta is! Map) {
        throw const ApiException(
          code: 'RESPOSTA_INVALIDA',
          message: 'A API não retornou um usuário válido.',
        );
      }
      return AuthUsuario.fromJson(Map<String, dynamic>.from(resposta));
    } finally {
      client.close();
    }
  }

  Future<void> enviarFoto(String imagemBase64, String mime) async {
    final client = await _criarCliente();
    try {
      await client.put(
        '/me/foto',
        body: {'imagemBase64': imagemBase64, 'mime': mime},
      );
    } finally {
      client.close();
    }
  }

  Future<void> removerFoto() async {
    final client = await _criarCliente();
    try {
      await client.delete('/me/foto');
    } finally {
      client.close();
    }
  }

  Future<AuthUsuario> atualizarPerfil(String nome) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.patch('/me', body: {'nome': nome});
      if (resposta is! Map) {
        throw const ApiException(
          code: 'RESPOSTA_INVALIDA',
          message: 'A API não retornou o perfil atualizado.',
        );
      }
      try {
        return AuthUsuario.fromJson(Map<String, dynamic>.from(resposta));
      } on FormatException catch (erro) {
        throw ApiException(code: 'RESPOSTA_INVALIDA', message: erro.message);
      }
    } finally {
      client.close();
    }
  }

  AuthSession _sessaoDaResposta(dynamic resposta) {
    if (resposta is! Map) {
      throw const ApiException(
        code: 'RESPOSTA_INVALIDA',
        message: 'A API não retornou uma sessão válida.',
      );
    }

    try {
      return AuthSession.fromJson(Map<String, dynamic>.from(resposta));
    } on FormatException {
      throw const ApiException(
        code: 'RESPOSTA_INVALIDA',
        message: 'A API retornou uma sessão em formato inesperado.',
      );
    }
  }
}
