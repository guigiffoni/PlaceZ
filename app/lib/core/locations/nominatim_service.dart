import 'dart:convert';

import 'package:http/http.dart' as http;

class ResultadoEnderecoNominatim {
  final String descricao;
  final double latitude;
  final double longitude;

  const ResultadoEnderecoNominatim({
    required this.descricao,
    required this.latitude,
    required this.longitude,
  });
}

class LocalizacaoReversa {
  final String bairro;
  final String? cidade;
  final String descricao;

  const LocalizacaoReversa({
    required this.bairro,
    this.cidade,
    required this.descricao,
  });
}

class NominatimService {
  static const String _host = 'nominatim.openstreetmap.org';
  static const Map<String, String> _headers = {
    'User-Agent': 'PlaceZ/1.0 (projeto academico)',
    'Accept-Language': 'pt-BR',
    'Accept': 'application/json',
  };

  Future<List<ResultadoEnderecoNominatim>> buscar(String termo) async {
    final texto = termo.trim();
    if (texto.isEmpty) return const [];

    final uri = Uri.https(_host, '/search', {
      'q': texto,
      'format': 'jsonv2',
      'limit': '6',
      'addressdetails': '1',
      'accept-language': 'pt-BR',
    });

    final resposta = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (resposta.statusCode != 200) {
      throw Exception('A busca de endereço retornou ${resposta.statusCode}.');
    }

    final dados = jsonDecode(resposta.body);
    if (dados is! List) return const [];

    return dados
        .whereType<Map>()
        .map((item) {
          final descricao = (item['display_name'] ?? '').toString();
          final latitude = double.tryParse((item['lat'] ?? '').toString());
          final longitude = double.tryParse((item['lon'] ?? '').toString());
          if (descricao.isEmpty || latitude == null || longitude == null) {
            return null;
          }
          return ResultadoEnderecoNominatim(
            descricao: descricao,
            latitude: latitude,
            longitude: longitude,
          );
        })
        .whereType<ResultadoEnderecoNominatim>()
        .toList();
  }

  Future<LocalizacaoReversa> reverter(double latitude, double longitude) async {
    final uri = Uri.https(_host, '/reverse', {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'format': 'jsonv2',
      'zoom': '16',
      'addressdetails': '1',
      'accept-language': 'pt-BR',
    });

    final resposta = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (resposta.statusCode != 200) {
      throw Exception('O reverse geocoding retornou ${resposta.statusCode}.');
    }

    final dados = jsonDecode(resposta.body);
    if (dados is! Map) {
      throw Exception('O Nominatim não retornou um endereço válido.');
    }

    final endereco = dados['address'];
    final mapa = endereco is Map
        ? Map<String, dynamic>.from(endereco)
        : <String, dynamic>{};

    String? texto(String chave) {
      final valor = mapa[chave]?.toString().trim();
      return valor == null || valor.isEmpty ? null : valor;
    }

    final descricao = (dados['display_name'] ?? '').toString();
    final bairro =
        texto('suburb') ??
        texto('neighbourhood') ??
        texto('city_district') ??
        texto('quarter') ??
        texto('town') ??
        texto('village') ??
        descricao.split(',').first.trim();
    final cidade =
        texto('city') ??
        texto('town') ??
        texto('municipality') ??
        texto('village') ??
        texto('county');

    if (bairro.isEmpty) {
      throw Exception('Não foi possível identificar o bairro do local.');
    }

    return LocalizacaoReversa(
      bairro: bairro,
      cidade: cidade,
      descricao: descricao,
    );
  }
}
