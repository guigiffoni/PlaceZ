class Local {
  final int? id;
  final String? nome;
  final String? endereco;
  final int? numero;
  final String? complemento;
  final double? nota;
  final double? latitude;
  final double? longitude;
  final String? categoria;
  final String? cidade;
  final double? distanciaMetros;
  final String? descricao;
  final String? faixaPreco;
  final double? avaliacaoMedia;
  final int? avaliacaoTotal;
  final int? catalogoId;

  Local({
    this.id,
    this.nome,
    this.endereco,
    this.numero,
    this.complemento,
    this.nota,
    this.latitude,
    this.longitude,
    this.categoria,
    this.cidade,
    this.distanciaMetros,
    this.descricao,
    this.faixaPreco,
    this.avaliacaoMedia,
    this.avaliacaoTotal,
    this.catalogoId,
  });

  Local copyWith({
    int? id,
    String? nome,
    String? endereco,
    int? numero,
    String? complemento,
    double? nota,
    double? latitude,
    double? longitude,
    String? categoria,
    String? cidade,
    double? distanciaMetros,
    String? descricao,
    String? faixaPreco,
    double? avaliacaoMedia,
    int? avaliacaoTotal,
    int? catalogoId,
  }) {
    return Local(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      endereco: endereco ?? this.endereco,
      numero: numero ?? this.numero,
      complemento: complemento ?? this.complemento,
      nota: nota ?? this.nota,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      categoria: categoria ?? this.categoria,
      cidade: cidade ?? this.cidade,
      distanciaMetros: distanciaMetros ?? this.distanciaMetros,
      descricao: descricao ?? this.descricao,
      faixaPreco: faixaPreco ?? this.faixaPreco,
      avaliacaoMedia: avaliacaoMedia ?? this.avaliacaoMedia,
      avaliacaoTotal: avaliacaoTotal ?? this.avaliacaoTotal,
      catalogoId: catalogoId ?? this.catalogoId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'endereco': endereco,
      'numero': numero,
      'complemento': complemento,
      'nota': nota,
      'latitude': latitude,
      'longitude': longitude,
      'categoria': categoria,
      'distancia_metros': distanciaMetros,
    };
  }

  factory Local.fromMap(Map<String, dynamic> map) {
    return Local(
      id: _comoInt(map['id']),
      nome: _texto(map['nome']),
      endereco: _texto(map['endereco']),
      numero: _comoInt(map['numero']),
      complemento: _texto(map['complemento']),
      nota: _comoDouble(map['nota']),
      latitude: _comoDouble(map['latitude']),
      longitude: _comoDouble(map['longitude']),
      categoria: _texto(map['categoria']),
      cidade: _texto(map['cidade']),
      distanciaMetros: _comoDouble(map['distancia_metros']),
      descricao: _texto(map['descricao']),
      faixaPreco: _texto(map['faixa_preco']),
      avaliacaoMedia: _comoDouble(map['avaliacao_media']),
      avaliacaoTotal: _comoInt(map['avaliacao_total']),
      catalogoId: _comoInt(map['catalogo_id']),
    );
  }

  /// Local vindo da API de eventos ou do catálogo mock (camelCase).
  factory Local.fromJson(Map<String, dynamic> json) {
    return Local(
      id: _comoInt(json['id']),
      nome: _texto(json['nome']),
      endereco: _texto(json['endereco']),
      numero: _comoInt(json['numero']),
      complemento: _texto(json['complemento']),
      nota: _comoDouble(json['nota']),
      latitude: _comoDouble(json['latitude']),
      longitude: _comoDouble(json['longitude']),
      categoria: _texto(json['categoria']),
      cidade: _texto(json['cidade']),
      distanciaMetros: _comoDouble(
        json['distanciaMetros'] ?? json['distancia_metros'],
      ),
      descricao: _texto(json['descricao']),
      faixaPreco: _texto(json['faixaPreco'] ?? json['faixa_preco']),
      avaliacaoMedia: _comoDouble(
        json['avaliacaoMedia'] ?? json['avaliacao_media'],
      ),
      avaliacaoTotal: _comoInt(
        json['avaliacaoTotal'] ?? json['avaliacao_total'],
      ),
      catalogoId: _comoInt(json['catalogoId'] ?? json['catalogo_id']),
    );
  }

  /// Snapshot enviado no corpo do evento. O id local não é enviado.
  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'endereco': endereco,
      'categoria': categoria,
      'distanciaMetros': distanciaMetros,
      'latitude': latitude,
      'longitude': longitude,
      'catalogoId': catalogoId,
    };
  }

  String get rotulo => nome ?? 'Local sem nome';
}

String? _texto(dynamic valor) {
  if (valor == null) return null;
  final texto = valor.toString().trim();
  return texto.isEmpty ? null : texto;
}

int? _comoInt(dynamic valor) {
  if (valor == null) return null;
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse(valor.toString());
}

double? _comoDouble(dynamic valor) {
  if (valor == null) return null;
  if (valor is double) return valor;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString());
}
