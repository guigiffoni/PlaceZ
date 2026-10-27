class Pessoa {
  final int? id;
  final String nome;
  // final String username;

  Pessoa({
    this.id,
    required this.nome,
    // required this.username,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      // 'username': username,
    };
  }

  factory Pessoa.fromMap(Map<String, dynamic> map) {
    return Pessoa(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      // username: map['username'] as String,
    );
  }
}