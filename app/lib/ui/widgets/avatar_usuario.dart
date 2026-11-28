import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_config.dart';
import '../../tema.dart';

class AvatarUsuario extends StatelessWidget {
  final AuthController auth;
  final int usuarioId;
  final String nome;
  final double raio;
  final int versao;

  const AvatarUsuario({
    super.key,
    required this.auth,
    required this.usuarioId,
    required this.nome,
    this.raio = 20,
    this.versao = 0,
  });

  String get _iniciais {
    final partes = nome
        .trim()
        .split(RegExp(r'\s+'))
        .where((parte) => parte.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final token = auth.sessao?.token;
    final iniciais = _iniciais;
    final theme = Theme.of(context);
    final paleta = theme.colorScheme.paletaAvatar(nome, usuarioId);
    final fundo = Color.alphaBlend(paleta.fundo, theme.colorScheme.surface);

    Widget fallback() {
      return Center(
        child: Text(
          iniciais,
          style: theme.textTheme.titleSmall?.copyWith(color: paleta.frente),
        ),
      );
    }

    if (token == null || token.isEmpty) {
      return CircleAvatar(
        radius: raio,
        backgroundColor: fundo,
        child: fallback(),
      );
    }

    return Semantics(
      label: nome,
      child: CircleAvatar(
        radius: raio,
        backgroundColor: fundo,
        child: ClipOval(
          child: Image.network(
            '${ApiConfig.baseUrl}/usuarios/$usuarioId/foto?v=$versao',
            headers: {'Authorization': 'Bearer $token'},
            width: raio * 2,
            height: raio * 2,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => fallback(),
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : fallback(),
          ),
        ),
      ),
    );
  }
}
