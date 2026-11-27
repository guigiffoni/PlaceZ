import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_config.dart';

class ImagemEvento extends StatelessWidget {
  final AuthController auth;
  final int eventoId;
  final int versao;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ImagemEvento({
    super.key,
    required this.auth,
    required this.eventoId,
    this.versao = 0,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final token = auth.sessao?.token;

    Widget fallback() {
      return Container(
        width: width,
        height: height,
        color: theme.colorScheme.surfaceContainerHigh,
        child: Icon(
          Icons.image_outlined,
          color: theme.colorScheme.onSurfaceVariant,
          size: (height ?? 48) * 0.35,
        ),
      );
    }

    final conteudo = (token == null || token.isEmpty || eventoId <= 0)
        ? fallback()
        : Image.network(
            '${ApiConfig.baseUrl}/eventos/$eventoId/imagem?v=$versao',
            headers: {'Authorization': 'Bearer $token'},
            width: width,
            height: height,
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => fallback(),
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : fallback(),
          );

    if (borderRadius == null) return conteudo;
    return ClipRRect(borderRadius: borderRadius!, child: conteudo);
  }
}
