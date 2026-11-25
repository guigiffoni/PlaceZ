import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';
import 'api_mode.dart';
import 'api_preferences.dart';
import 'mock_backend.dart';

class ApiClient {
  final ApiMode mode;
  final String baseUrl;
  final http.Client _httpClient;
  final Future<String?> Function()? tokenProvider;
  final Future<void> Function()? onUnauthorized;

  Map<String, dynamic>? _mockCache;

  ApiClient({
    required this.mode,
    String? baseUrl,
    http.Client? httpClient,
    this.tokenProvider,
    this.onUnauthorized,
  }) : baseUrl = baseUrl ?? ApiConfig.baseUrl,
       _httpClient = httpClient ?? http.Client();

  static Future<ApiClient> create({
    String? baseUrl,
    Future<String?> Function()? tokenProvider,
    Future<void> Function()? onUnauthorized,
  }) async {
    final modo = await ApiPreferences.carregaModo();
    return ApiClient(
      mode: modo,
      baseUrl: baseUrl,
      tokenProvider: tokenProvider,
      onUnauthorized: onUnauthorized,
    );
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) {
    return request('GET', path, query: query);
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? query,
  }) {
    return request('POST', path, body: body, query: query);
  }

  Future<dynamic> put(String path, {Object? body, Map<String, String>? query}) {
    return request('PUT', path, body: body, query: query);
  }

  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, String>? query,
  }) {
    return request('PATCH', path, body: body, query: query);
  }

  Future<dynamic> delete(String path, {Map<String, String>? query}) {
    return request('DELETE', path, query: query);
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    if (mode == ApiMode.mock) {
      return _mockRequest(method, path, query: query, body: body);
    }
    return _remoteRequest(method, path, query: query, body: body);
  }

  Future<dynamic> _remoteRequest(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }

    final token = await tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final uri = _montaUri(path, query);
    final requisicao = http.Request(method, uri);
    requisicao.headers.addAll(headers);
    if (body != null) {
      requisicao.body = jsonEncode(body);
    }

    late http.Response resposta;
    try {
      final streamed = await _httpClient
          .send(requisicao)
          .timeout(ApiConfig.requestTimeout);
      resposta = await http.Response.fromStream(streamed)
          .timeout(ApiConfig.requestTimeout);
    } on TimeoutException {
      throw const ApiException(
        code: 'TIMEOUT',
        message: 'A requisição demorou demais. Verifique sua conexão.',
      );
    } on http.ClientException catch (erro) {
      throw ApiException(
        code: 'REDE',
        message: 'Não foi possível conectar à API: ${erro.message}',
      );
    } on Exception catch (erro) {
      throw ApiException(code: 'REDE', message: 'Falha de rede: $erro');
    }

    final payload = _decodifica(resposta.body);

    if (resposta.statusCode == 401) {
      try {
        await onUnauthorized?.call();
      } catch (_) {
        // A Fase 1 conecta o tratamento visual da sessão expirada.
      }
    }

    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      throw _erroDaResposta(resposta.statusCode, payload);
    }

    return payload;
  }

  Future<dynamic> _mockRequest(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    // O backend mock stateful cobre autenticação e amigos. Rotas ainda não
    // implementadas continuam usando o arquivo de fixtures.
    final token = await tokenProvider?.call();
    final backend = await MockBackend.carrega();
    final respostaMock = await backend.handle(
      method: method,
      path: path,
      query: query,
      body: body,
      token: token,
    );

    if (respostaMock != null) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (respostaMock.status == 401) {
        try {
          await onUnauthorized?.call();
        } catch (_) {
          // A sessão local é tratada pelo AuthController.
        }
      }
      if (respostaMock.status < 200 || respostaMock.status >= 300) {
        throw _erroDaResposta(respostaMock.status, respostaMock.body);
      }
      return respostaMock.body;
    }

    final dados = await _carregaMock();
    final chave = _encontraRotaMock(dados, method, path);
    if (chave == null) {
      throw ApiException(
        statusCode: 404,
        code: 'MOCK_NAO_ENCONTRADO',
        message: 'Rota mock não encontrada: $method $path',
      );
    }

    // Delay pequeno para a UI exercitar estados de carregamento.
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final fixture = dados[chave];
    if (fixture is Map<String, dynamic> && fixture.containsKey('__status')) {
      final status = fixture['__status'] as int? ?? 200;
      final corpo = fixture['__body'];
      if (status < 200 || status >= 300) {
        throw _erroDaResposta(status, corpo);
      }
      return corpo;
    }
    return fixture;
  }

  Future<Map<String, dynamic>> _carregaMock() async {
    if (_mockCache != null) return _mockCache!;
    final texto = await rootBundle.loadString(ApiConfig.mockAsset);
    final dados = jsonDecode(texto);
    if (dados is! Map<String, dynamic>) {
      throw const ApiException(
        code: 'MOCK_INVALIDO',
        message: 'O arquivo de mock não contém um objeto JSON.',
      );
    }
    _mockCache = dados;
    return dados;
  }

  String? _encontraRotaMock(
    Map<String, dynamic> dados,
    String method,
    String path,
  ) {
    final caminho = _normalizaCaminho(path);
    final exata = '$method $caminho';
    if (dados.containsKey(exata)) return exata;

    for (final chave in dados.keys) {
      final partes = chave.split(' ');
      if (partes.length != 2 || partes.first != method) continue;
      if (_combinaRota(partes[1], caminho)) return chave;
    }

    final curinga = '$method *';
    if (dados.containsKey(curinga)) return curinga;

    return null;
  }

  bool _combinaRota(String padrao, String caminho) {
    if (padrao == '*') return true;
    final partesPadrao = padrao.split('/');
    final partesCaminho = caminho.split('/');
    if (partesPadrao.length != partesCaminho.length) return false;

    for (var i = 0; i < partesPadrao.length; i++) {
      final segmento = partesPadrao[i];
      if (segmento.startsWith(':') || segmento.startsWith('{')) continue;
      if (segmento != partesCaminho[i]) return false;
    }
    return true;
  }

  Uri _montaUri(String path, Map<String, String>? query) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final caminho = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$base$caminho');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  String _normalizaCaminho(String path) {
    final semQuery = path.split('?').first;
    if (semQuery.length > 1 && semQuery.endsWith('/')) {
      return semQuery.substring(0, semQuery.length - 1);
    }
    return semQuery;
  }

  dynamic _decodifica(String corpo) {
    if (corpo.trim().isEmpty) return null;
    try {
      return jsonDecode(corpo);
    } on FormatException {
      return corpo;
    }
  }

  ApiException _erroDaResposta(int status, dynamic payload) {
    if (payload is Map && payload['error'] is Map) {
      final erro = payload['error'] as Map;
      return ApiException(
        statusCode: status,
        code: (erro['code'] ?? 'ERRO_API').toString(),
        message: (erro['message'] ?? 'Falha na requisição.').toString(),
        details: erro['details'],
      );
    }

    final mensagem = payload is String && payload.trim().isNotEmpty
        ? payload
        : 'Falha na requisição.';
    return ApiException(
      statusCode: status,
      code: 'ERRO_API',
      message: mensagem,
    );
  }

  void close() {
    _httpClient.close();
  }
}
