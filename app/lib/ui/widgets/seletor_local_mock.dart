import 'package:flutter/material.dart';

import '../../core/events/local_catalog.dart';
import '../../data/models/local.dart';

/// Diálogo de busca no catálogo mock de lugares.
class SeletorLocalMock extends StatefulWidget {
  const SeletorLocalMock({super.key});

  static Future<Local?> abrir(BuildContext context) {
    return showDialog<Local>(
      context: context,
      builder: (context) => const SeletorLocalMock(),
    );
  }

  @override
  State<SeletorLocalMock> createState() => _SeletorLocalMockState();
}

class _SeletorLocalMockState extends State<SeletorLocalMock> {
  late Future<List<Local>> _futuro;
  final TextEditingController _busca = TextEditingController();
  String _termo = '';

  @override
  void initState() {
    super.initState();
    _futuro = LocalCatalog.carregar();
    _busca.addListener(() {
      setState(() => _termo = _busca.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  List<Local> _filtrar(List<Local> locais) {
    if (_termo.isEmpty) return locais;
    return locais.where((local) {
      final campos = [
        local.nome,
        local.endereco,
        local.categoria,
      ].whereType<String>().map((valor) => valor.toLowerCase());
      return campos.any((valor) => valor.contains(_termo));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buscar lugar'),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _busca,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Nome, endereço ou categoria',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
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
                        'Não foi possível carregar o catálogo de lugares.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    );
                  }

                  final locais = _filtrar(snapshot.data ?? const []);
                  if (locais.isEmpty) {
                    return const Center(
                      child: Text('Nenhum lugar encontrado.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: locais.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final local = locais[index];
                      return ListTile(
                        leading: Icon(_icone(local.categoria)),
                        title: Text(local.nome ?? 'Lugar'),
                        subtitle: Text(
                          local.endereco ?? 'Endereço não informado',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              local.categoria ?? 'Lugar',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatarDistancia(local.distanciaMetros),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                        onTap: () => Navigator.of(context).pop(local),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
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
