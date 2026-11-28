import 'package:flutter/material.dart';

import '../../tema.dart';

/// Título de seção com contador opcional e ação à direita.
class TituloSecao extends StatelessWidget {
  final String titulo;
  final String? sufixo;
  final Widget? acao;

  const TituloSecao(this.titulo, {super.key, this.sufixo, this.acao});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: PlacezTokens.espSm),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    titulo,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (sufixo != null) ...[
                  const SizedBox(width: PlacezTokens.espSm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      sufixo!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?acao,
        ],
      ),
    );
  }
}

/// Estado vazio padronizado, com ícone em destaque.
class EstadoVazio extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String? descricao;
  final Widget? acao;
  final EdgeInsetsGeometry padding;
  final Color? cor;

  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    this.descricao,
    this.acao,
    this.cor,
    this.padding = const EdgeInsets.symmetric(
      horizontal: PlacezTokens.espXl,
      vertical: PlacezTokens.espXl,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final corIcone = cor ?? theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: corIcone.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, size: 30, color: corIcone),
          ),
          const SizedBox(height: PlacezTokens.espMd),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (descricao != null) ...[
            const SizedBox(height: PlacezTokens.espXs),
            Text(
              descricao!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (acao != null) ...[
            const SizedBox(height: PlacezTokens.espLg),
            acao!,
          ],
        ],
      ),
    );
  }
}

/// Faixa de aviso (erro, cache, visitante etc.).
class AvisoPlacez extends StatelessWidget {
  final String mensagem;
  final bool erro;
  final VoidCallback? onFechar;
  final IconData? icone;

  const AvisoPlacez(
    this.mensagem, {
    super.key,
    this.erro = false,
    this.onFechar,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paleta = erro
        ? theme.colorScheme.cancelado
        : _paleta(theme.colorScheme);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        PlacezTokens.espMd,
        10,
        onFechar == null ? PlacezTokens.espMd : PlacezTokens.espXs,
        10,
      ),
      decoration: BoxDecoration(
        color: paleta.fundo,
        borderRadius: PlacezTokens.bordaMd,
        border: Border.all(color: paleta.borda),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icone ?? (erro ? Icons.error_outline : Icons.info_outline),
            color: paleta.frente,
            size: 20,
          ),
          const SizedBox(width: PlacezTokens.espSm),
          Expanded(
            child: Text(
              mensagem,
              style: theme.textTheme.bodySmall?.copyWith(
                color: paleta.frente,
                height: 1.35,
              ),
            ),
          ),
          if (onFechar != null)
            IconButton(
              onPressed: onFechar,
              icon: Icon(Icons.close, size: 18, color: paleta.frente),
              tooltip: 'Fechar aviso',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  PaletaStatus _paleta(ColorScheme scheme) {
    if (scheme.ehEscuro) {
      return PaletaStatus(
        fundo: scheme.secondaryContainer.withValues(alpha: 0.55),
        frente: scheme.onSecondaryContainer,
        borda: scheme.secondary.withValues(alpha: 0.25),
      );
    }
    return PaletaStatus(
      fundo: scheme.secondaryContainer,
      frente: scheme.onSecondaryContainer,
      borda: scheme.secondary.withValues(alpha: 0.25),
    );
  }
}

/// Chip de status de evento, coerente com o tema.
class StatusEventoChip extends StatelessWidget {
  final String rotulo;
  final IconData icone;
  final PaletaStatus paleta;

  const StatusEventoChip({
    super.key,
    required this.rotulo,
    required this.icone,
    required this.paleta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: paleta.fundo,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: paleta.borda),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: paleta.frente),
          const SizedBox(width: 4),
          Text(
            rotulo,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: paleta.frente, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Cartão de seção com espaçamento interno opcional.
class CartaoSecao extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? cor;

  const CartaoSecao({super.key, required this.child, this.padding, this.cor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: cor ?? theme.colorScheme.surfaceContainerLow,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

/// Título interno de cartão, para agrupar informações.
class TituloCartao extends StatelessWidget {
  final String titulo;
  final IconData? icone;
  final Widget? acao;

  const TituloCartao(this.titulo, {super.key, this.icone, this.acao});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (icone != null) ...[
          Icon(icone, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: PlacezTokens.espSm),
        ],
        Expanded(
          child: Text(
            titulo,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?acao,
      ],
    );
  }
}
