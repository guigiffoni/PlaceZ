import 'package:flutter/material.dart';

import '../core/events/local_catalog.dart';
import '../data/models/local.dart';

class TelaPesquisa extends StatefulWidget {
  const TelaPesquisa({super.key});

  @override
  State<TelaPesquisa> createState() => _TelaPesquisaState();
}

class _TelaPesquisaState extends State<TelaPesquisa> {
  final _controller = TextEditingController();
  late Future<List<Local>> _futuro;
  String _termoBusca = '';

  @override
  void initState() {
    super.initState();
    _futuro = LocalCatalog.carregar();
    _controller.addListener(_onBusca);
  }

  void _onBusca() {
    setState(() => _termoBusca = _controller.text.trim().toLowerCase());
  }

  @override
  void dispose() {
    _controller.removeListener(_onBusca);
    _controller.dispose();
    super.dispose();
  }

  List<Local> _filtrar(List<Local> locais) {
    if (_termoBusca.isEmpty) return locais;
    return locais.where((local) {
      final campos = [
        local.nome,
        local.endereco,
        local.categoria,
      ].whereType<String>().map((valor) => valor.toLowerCase());
      return campos.any((valor) => valor.contains(_termoBusca));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: FutureBuilder<List<Local>>(
            future: _futuro,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Não foi possível carregar os lugares.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              }

              final locais = _filtrar(snapshot.data ?? const []);
              if (locais.isEmpty) {
                return const Center(child: Text('Nenhum lugar encontrado.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: locais.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) => LugarPesquisa(locais[index]),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Buscar por nome, endereço ou categoria',
              prefixIcon: Icon(Icons.search),
            ),
            controller: _controller,
          ),
        ),
      ],
    );
  }
}

class LugarPesquisa extends StatelessWidget {
  const LugarPesquisa(this.lugar, {super.key});

  final Local lugar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Icon(_icone(lugar.categoria)),
        ),
        title: Text(lugar.rotulo),
        subtitle: Text(
          lugar.endereco ?? 'Endereço não informado',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(lugar.categoria ?? 'Lugar', style: theme.textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(
              formatarDistancia(lugar.distanciaMetros),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icone(String? categoria) {
    final valor = (categoria ?? '').toLowerCase();
    if (valor.contains('bar')) return Icons.local_bar_outlined;
    if (valor.contains('café') || valor.contains('padaria')) {
      return Icons.local_cafe_outlined;
    }
    if (valor.contains('parque')) return Icons.park_outlined;
    if (valor.contains('cinema')) return Icons.movie_outlined;
    if (valor.contains('mercado')) return Icons.storefront_outlined;
    if (valor.contains('pizza')) return Icons.local_pizza_outlined;
    if (valor.contains('açaí') || valor.contains('doceria')) {
      return Icons.icecream_outlined;
    }
    return Icons.restaurant_outlined;
  }
}
