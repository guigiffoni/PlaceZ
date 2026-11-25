/// Amigo confirmado que aparece no filtro do calendário.
///
/// A ordem e a contagem vêm do servidor; o app só apresenta os chips e
/// reutiliza o ranking salvo no cache quando a API está indisponível.
class PessoaRanking {
  final int usuarioId;
  final String nome;
  final int contagem;

  const PessoaRanking({
    required this.usuarioId,
    required this.nome,
    required this.contagem,
  });

  factory PessoaRanking.fromJson(Map<String, dynamic> json) {
    final usuarioId = _comoInt(json['usuarioId'] ?? json['usuario_id']);
    final nome = (json['nome'] ?? '').toString().trim();
    if (usuarioId == null || nome.isEmpty) {
      throw const FormatException('Pessoa inválida no ranking do calendário.');
    }

    return PessoaRanking(
      usuarioId: usuarioId,
      nome: nome,
      contagem: _comoInt(json['contagem']) ?? 0,
    );
  }

  factory PessoaRanking.fromMap(Map<String, dynamic> map) {
    return PessoaRanking(
      usuarioId: _comoInt(map['usuario_id']) ?? 0,
      nome: (map['nome'] ?? '').toString(),
      contagem: _comoInt(map['contagem']) ?? 0,
    );
  }
}

int? _comoInt(dynamic valor) {
  if (valor == null) return null;
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse(valor.toString());
}
