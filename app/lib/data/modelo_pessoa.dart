class Pessoa {
  final int? id;
  final String nome;

  Pessoa({
    this.id,
    required this.nome
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
    };
  }

  factory Pessoa.fromMap(Map<String, dynamic> map) {
    return Pessoa(
      id: map['id'] as int?,
      nome: map['nome'] as String,
    );
  }
}