import 'package:flutter/material.dart';

import '../core/auth/auth_controller.dart';
import '../core/events/local_catalog.dart';
import '../core/locations/fotos_lugar.dart';
import '../core/locations/locations_repository.dart';
import '../data/models/local.dart';
import '../tema.dart';
import 'telas/localizacao_aproximada.dart';
import 'telas/lugar_detalhe.dart';
import 'widgets/avaliacao_estrelas.dart';
import 'widgets/campo_busca.dart';
import 'widgets/placez_componentes.dart';

class TelaPesquisa extends StatefulWidget {
  final AuthController authController;
  final bool modoSelecao;
  final ValueChanged<Local>? onSelecionar;

  const TelaPesquisa({
    super.key,
    required this.authController,
    this.modoSelecao = false,
    this.onSelecionar,
  });

  @override
  State<TelaPesquisa> createState() => _TelaPesquisaState();
}

class _TelaPesquisaState extends State<TelaPesquisa> {
  final _controller = TextEditingController();
  LocationsRepository? _repositorio;
  late Future<List<Local>> _futuro;
  String _termoBusca = '';

  @override
  void initState() {
    super.initState();
    _carregarCatalogo();
    _controller.addListener(_onBusca);
  }

  void _carregarCatalogo({bool notificar = false}) {
    final auth = widget.authController;
    if (auth.autenticado) {
      _repositorio ??= LocationsRepository(
        tokenProvider: () async => auth.sessao?.token,
        onUnauthorized: auth.tratarNaoAutorizado,
      );
      _futuro = _repositorio!.listarCatalogo();
    } else {
      _repositorio = null;
      _futuro = LocalCatalog.carregar();
    }
    if (notificar && mounted) setState(() {});
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
        local.cidade,
      ].whereType<String>().map((valor) => valor.toLowerCase());
      return campos.any((valor) => valor.contains(_termoBusca));
    }).toList();
  }

  Future<void> _abrirDetalhe(Local local) async {
    final selecionado = await Navigator.of(context).push<Local>(
      MaterialPageRoute(
        builder: (context) => TelaDetalheLugar(
          authController: widget.authController,
          lugarInicial: local,
          modoSelecao: widget.modoSelecao,
        ),
      ),
    );

    if (!mounted) return;
    if (selecionado != null) {
      widget.onSelecionar?.call(selecionado);
      return;
    }
    _carregarCatalogo(notificar: true);
  }

  Future<void> _definirLocalizacao() async {
    final alterou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            TelaLocalizacaoAproximada(authController: widget.authController),
      ),
    );
    if (alterou == true && mounted) {
      _carregarCatalogo(notificar: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.modoSelecao)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AvisoPlacez(
              'Escolha um lugar para o evento. Toque em um item para ver os '
              'detalhes e usar o local.',
              icone: Icons.touch_app_outlined,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: CampoBusca(
            controller: _controller,
            hintText: 'Buscar por nome, endereço ou categoria',
            helperText: 'Digite para filtrar o catálogo da região.',
            onChanged: (_) => _onBusca(),
            onSearch: _onBusca,
            onClear: _onBusca,
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Local>>(
            future: _futuro,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(PlacezTokens.espXl),
                    child: Text(
                      'Não foi possível carregar os lugares.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                );
              }

              final todos = snapshot.data ?? const <Local>[];
              final locais = _filtrar(todos);
              final semLocalizacao =
                  widget.authController.autenticado &&
                  todos.isNotEmpty &&
                  todos.every((local) => local.distanciaMetros == null);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (semLocalizacao)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: _SemLocalizacao(onDefinir: _definirLocalizacao),
                    ),
                  if (locais.isEmpty)
                    const Expanded(
                      child: Center(child: Text('Nenhum lugar encontrado.')),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: locais.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) => LugarPesquisa(
                          locais[index],
                          onTap: () => _abrirDetalhe(locais[index]),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SemLocalizacao extends StatelessWidget {
  final VoidCallback onDefinir;

  const _SemLocalizacao({required this.onDefinir});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Icon(
              Icons.near_me_outlined,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Defina sua localização aproximada para ver as distâncias e '
                'ordenar os lugares mais próximos.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            TextButton(onPressed: onDefinir, child: const Text('Definir')),
          ],
        ),
      ),
    );
  }
}

class LugarPesquisa extends StatelessWidget {
  final Local lugar;
  final VoidCallback onTap;

  const LugarPesquisa(this.lugar, {super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foto = FotosLugar.principal(lugar.categoria, lugar.nome);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(PlacezTokens.espMd),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: PlacezTokens.bordaMd,
                child: Image.asset(
                  foto,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    width: 72,
                    height: 72,
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: PlacezTokens.espMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lugar.rotulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (lugar.categoria != null) lugar.categoria!,
                        if (lugar.cidade != null) lugar.cidade!,
                      ].join(' · '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (lugar.avaliacaoMedia != null &&
                            lugar.avaliacaoMedia! > 0)
                          AvaliacaoEstrelas(
                            nota: lugar.avaliacaoMedia,
                            tamanho: 13,
                            mostrarValor: true,
                          ),
                        const Spacer(),
                        if (lugar.distanciaMetros != null) ...[
                          Icon(
                            Icons.near_me_outlined,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            formatarDistancia(lugar.distanciaMetros),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
