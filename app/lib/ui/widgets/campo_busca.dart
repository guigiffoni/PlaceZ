import 'package:flutter/material.dart';

import '../../tema.dart';

/// Campo de busca padrão do app: sem ícone à esquerda e com botão de ação
/// à direita. Enter e o botão executam a mesma ação.
class CampoBusca extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onSearch;
  final VoidCallback? onClear;
  final String? helperText;
  final bool autofocus;
  final bool enabled;
  final String searchTooltip;

  const CampoBusca({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onSearch,
    this.onClear,
    this.helperText,
    this.autofocus = false,
    this.enabled = true,
    this.searchTooltip = 'Buscar',
  });

  @override
  State<CampoBusca> createState() => _CampoBuscaState();
}

class _CampoBuscaState extends State<CampoBusca> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_aoMudarTexto);
  }

  @override
  void didUpdateWidget(covariant CampoBusca oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_aoMudarTexto);
      widget.controller.addListener(_aoMudarTexto);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_aoMudarTexto);
    super.dispose();
  }

  void _aoMudarTexto() {
    if (mounted) setState(() {});
  }

  void _executarBusca() {
    FocusScope.of(context).unfocus();
    final texto = widget.controller.text;
    widget.onSearch?.call();
    widget.onSubmitted?.call(texto);
  }

  void _limpar() {
    widget.controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final temTexto = widget.controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                autofocus: widget.autofocus,
                enabled: widget.enabled,
                textInputAction: TextInputAction.search,
                onChanged: widget.onChanged,
                onSubmitted: (_) => _executarBusca(),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  suffixIcon: temTexto
                      ? IconButton(
                          tooltip: 'Limpar',
                          onPressed: _limpar,
                          icon: const Icon(Icons.close),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: PlacezTokens.espSm),
            SizedBox(
              width: 52,
              height: 52,
              child: IconButton.filled(
                tooltip: widget.searchTooltip,
                onPressed: widget.enabled ? _executarBusca : null,
                icon: const Icon(Icons.search),
              ),
            ),
          ],
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PlacezTokens.espXs),
            child: Text(
              widget.helperText!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
