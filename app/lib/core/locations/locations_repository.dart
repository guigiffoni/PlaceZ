import '../../data/models/local.dart';
import '../../data/models/localizacao.dart';
import '../../data/models/lugar_detalhe.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

class LocationsRepository {
  final Future<String?> Function()? tokenProvider;
  final Future<void> Function()? onUnauthorized;

  LocationsRepository({this.tokenProvider, this.onUnauthorized});

  Future<ApiClient> _criarCliente() {
    return ApiClient.create(
      tokenProvider: tokenProvider,
      onUnauthorized: onUnauthorized,
    );
  }

  Future<LocalizacaoUsuario?> obterMinhaLocalizacao() async {
    final client = await _criarCliente();
    try {
      final resposta = await client.get('/me/localizacao');
      final mapa = _comoMapa(resposta);
      return LocalizacaoUsuario.fromResposta(mapa['localizacao']);
    } finally {
      client.close();
    }
  }

  Future<LocalizacaoUsuario?> salvarLocalizacaoAproximada({
    required String bairro,
    String? cidade,
    required double latitude,
    required double longitude,
    required String origem,
  }) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.put(
        '/me/localizacao',
        body: {
          'bairro': bairro,
          'cidade': cidade,
          'latitude': latitude,
          'longitude': longitude,
          'origem': origem,
        },
      );
      final mapa = _comoMapa(resposta);
      return LocalizacaoUsuario.fromResposta(mapa['localizacao']);
    } finally {
      client.close();
    }
  }

  Future<void> removerLocalizacao() async {
    final client = await _criarCliente();
    try {
      await client.delete('/me/localizacao');
    } finally {
      client.close();
    }
  }

  Future<List<Local>> listarCatalogo({String? termo}) async {
    final client = await _criarCliente();
    try {
      final query = <String, String>{};
      if (termo != null && termo.trim().isNotEmpty) {
        query['q'] = termo.trim();
      }
      final resposta = await client.get(
        '/locais/catalogo',
        query: query.isEmpty ? null : query,
      );
      final mapa = _comoMapa(resposta);
      return _converteLista(mapa['locais'], Local.fromJson);
    } finally {
      client.close();
    }
  }

  Future<DetalheLugar> obterLugar(int lugarId) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.get('/locais/catalogo/$lugarId');
      final mapa = _comoMapa(resposta);
      final lugar = mapa['lugar'];
      if (lugar is! Map) {
        throw const ApiException(
          code: 'RESPOSTA_INVALIDA',
          message: 'A API não retornou o lugar.',
        );
      }
      try {
        return DetalheLugar.fromJson(Map<String, dynamic>.from(lugar));
      } on FormatException catch (erro) {
        throw ApiException(code: 'RESPOSTA_INVALIDA', message: erro.message);
      }
    } finally {
      client.close();
    }
  }

  Future<void> avaliarLugar(
    int lugarId, {
    required int nota,
    String? comentario,
  }) async {
    final client = await _criarCliente();
    try {
      await client.put(
        '/locais/catalogo/$lugarId/avaliacao',
        body: {
          'nota': nota,
          if (comentario != null && comentario.trim().isNotEmpty)
            'comentario': comentario.trim(),
        },
      );
    } finally {
      client.close();
    }
  }

  Future<void> removerAvaliacao(int lugarId) async {
    final client = await _criarCliente();
    try {
      await client.delete('/locais/catalogo/$lugarId/avaliacao');
    } finally {
      client.close();
    }
  }

  Future<ResultadoSugestoes> sugerirLocais(
    List<int> usuarioIds,
    String modo,
  ) async {
    final client = await _criarCliente();
    try {
      final resposta = await client.post(
        '/locais/sugestoes',
        body: {'usuarioIds': usuarioIds, 'modo': modo},
      );
      final mapa = _comoMapa(resposta);
      try {
        return ResultadoSugestoes.fromJson(mapa);
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
        message: 'A API não retornou dados de locais válidos.',
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
