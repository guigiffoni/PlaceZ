class AuthUsuario {
  final int id;
  final String nome;
  final String username;

  const AuthUsuario({
    required this.id,
    required this.nome,
    required this.username,
  });

  String get identificador => '@$username';

  factory AuthUsuario.fromJson(Map<String, dynamic> json) {
    final id = _comoInt(json['id']);
    final nome = (json['nome'] ?? '').toString().trim();
    final username = (json['username'] ?? '').toString().trim();

    if (id == null || nome.isEmpty || username.isEmpty) {
      throw const FormatException('Usuário inválido na resposta da API.');
    }

    return AuthUsuario(id: id, nome: nome, username: username);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'nome': nome, 'username': username};
  }
}

class AuthSession {
  final String token;
  final DateTime expiraEm;
  final AuthUsuario usuario;

  const AuthSession({
    required this.token,
    required this.expiraEm,
    required this.usuario,
  });

  bool get expirada => !expiraEm.isAfter(DateTime.now().toUtc());

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final token = (json['token'] ?? '').toString().trim();
    final expiraEm = DateTime.tryParse((json['expiraEm'] ?? '').toString())
        ?.toUtc();
    final usuarioJson = json['usuario'];

    if (token.isEmpty || expiraEm == null || usuarioJson is! Map) {
      throw const FormatException('Sessão inválida na resposta da API.');
    }

    return AuthSession(
      token: token,
      expiraEm: expiraEm,
      usuario: AuthUsuario.fromJson(Map<String, dynamic>.from(usuarioJson)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'expiraEm': expiraEm.toUtc().toIso8601String(),
      'usuario': usuario.toJson(),
    };
  }
}

int? _comoInt(dynamic valor) {
  if (valor == null) return null;
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse(valor.toString());
}
