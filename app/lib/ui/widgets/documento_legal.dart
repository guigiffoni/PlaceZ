import 'package:flutter/material.dart';

import '../../tema.dart';
import 'placez_componentes.dart';

class SecaoLegal {
  final String titulo;
  final List<String> paragrafos;

  const SecaoLegal(this.titulo, this.paragrafos);
}

class TelaDocumentoLegal extends StatelessWidget {
  final String titulo;
  final String atualizadoEm;
  final List<SecaoLegal> secoes;
  final String? avisoFinal;

  const TelaDocumentoLegal({
    super.key,
    required this.titulo,
    required this.atualizadoEm,
    required this.secoes,
    this.avisoFinal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            atualizadoEm,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: PlacezTokens.espLg),
          for (final secao in secoes) ...[
            Text(
              secao.titulo,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            for (final paragrafo in secao.paragrafos) ...[
              Text(
                paragrafo,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: PlacezTokens.espMd),
          ],
          if (avisoFinal != null) AvisoPlacez(avisoFinal!),
        ],
      ),
    );
  }
}
