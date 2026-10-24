class Local {
  final int? id;
  final String? nome;
  final String? endereco;
  final int? numero;
  final String? complemento;

  Local({
    this.id,
    this.nome,
    this.endereco,
    this.numero,
    this.complemento,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'endereco': endereco,
      'numero': numero,
      'complemento': complemento,
    };
  }

  factory Local.fromMap(Map<String, dynamic> map) {
    return Local(
      id: map['id'] as int?,
      nome: map['nome'] as String?,
      endereco: map['endereco'] as String?,
      numero: map['numero'] as int?,
      complemento: map['complemento'] as String?,
    );
  }
}