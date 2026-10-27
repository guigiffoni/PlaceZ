class Local {
  final int? id;
  final String? nome;
  final String? endereco;
  final int? numero;
  final String? complemento;
  final double? nota;
  final double? latitude;
  final double? longitude;

  Local({
    this.id,
    this.nome,
    this.endereco,
    this.numero,
    this.complemento,
    this.nota,
    this.latitude,
    this.longitude,
  });

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
    };
  }

  factory Local.fromMap(Map<String, dynamic> map) {
    return Local(
      id: map['id'] as int?,
      nome: map['nome'] as String?,
      endereco: map['endereco'] as String?,
      numero: map['numero'] as int?,
      complemento: map['complemento'] as String?,
      nota: map['nota'] as double?,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
    );
  }
}