import 'package:flutter/material.dart';

class AvaliacaoEstrelas extends StatelessWidget {
  final double? nota;
  final int? total;
  final double tamanho;
  final bool mostrarValor;
  final Color? cor;

  const AvaliacaoEstrelas({
    super.key,
    required this.nota,
    this.total,
    this.tamanho = 16,
    this.mostrarValor = true,
    this.cor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valor = nota ?? 0;
    final corEstrela = cor ?? theme.colorScheme.tertiary;
    final rotulo = valor > 0
        ? valor.toStringAsFixed(1).replaceAll('.', ',')
        : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 1),
            child: Icon(
              _icone(i, valor),
              size: tamanho,
              color: valor > 0 ? corEstrela : theme.colorScheme.outlineVariant,
            ),
          ),
        if (mostrarValor) ...[
          const SizedBox(width: 6),
          Text(
            rotulo ?? 'Sem avaliações',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: valor > 0
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (total != null && total! > 0) ...[
            const SizedBox(width: 4),
            Text(
              '($total)',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ],
    );
  }

  IconData _icone(int posicao, double valor) {
    if (valor >= posicao - 0.25) return Icons.star;
    if (valor >= posicao - 0.75) return Icons.star_half;
    return Icons.star_border;
  }
}
