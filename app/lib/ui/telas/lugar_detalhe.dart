import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/events/events_repository.dart';
import '../../core/events/local_catalog.dart' show formatarDistancia;
import '../../core/locations/fotos_lugar.dart';
import '../../core/locations/locations_repository.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/evento_resumo.dart';
import '../../data/models/local.dart';
import '../../data/models/lugar_detalhe.dart';
import '../../tema.dart';
import '../widgets/avaliacao_estrelas.dart';
import '../widgets/placez_componentes.dart';
import 'login.dart';

class TelaDetalheLugar extends StatefulWidget {
  final AuthController authController;
  final Local lugarInicial;
  final bool modoSelecao;

  const TelaDetalheLugar({
    super.key,
    required this.authController,
    required this.lugarInicial,
    this.modoSelecao = false,
  });

  @override
  State<TelaDetalheLugar> createState() => _TelaDetalheLugarState();
}

class _TelaDetalheLugarState extends State<TelaDetalheLugar> {
  late final LocationsRepository _repositorio;
  late final EventsRepository _eventosRepositorio;
  DetalheLugar? _detalhe;
  bool _carregando = true;
  bool _salvandoAvaliacao = false;
  bool _adicionandoEvento = false;
  int _paginaFoto = 0;
  String? _erro;

  Local get _lugar => _detalhe?.lugar ?? widget.lugarInicial;

  Local get _lugarComCatalogo {
    final lugar = _lugar;
    if (lugar.catalogoId != null || lugar.id == null) return lugar;
    return lugar.copyWith(catalogoId: lugar.id);
  }

  @override
  void initState() {
    super.initState();
    final auth = widget.authController;
    _repositorio = LocationsRepository(
      tokenProvider: () async => auth.sessao?.token,
      onUnauthorized: auth.tratarNaoAutorizado,
    );
    _eventosRepositorio = EventsRepository(
      tokenProvider: () async => auth.sessao?.token,
      onUnauthorized: auth.tratarNaoAutorizado,
    );
    _carregar();
  }

  Future<void> _carregar() async {
    final id = widget.lugarInicial.id;
    if (!widget.authController.autenticado || id == null) {
      _carregando = false;
      return;
    }

    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }

    try {
      final detalhe = await _repositorio.obterLugar(id);
      if (!mounted) return;
      setState(() => _detalhe = detalhe);
    } on ApiException catch (erro) {
      if (mounted) setState(() => _erro = erro.message);
    } catch (erro) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível carregar o lugar: $erro');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _avaliar() async {
    if (!widget.authController.autenticado) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => TelaLogin(
            authController: widget.authController,
            motivo: 'Entre para avaliar este lugar.',
          ),
        ),
      );
      if (mounted && widget.authController.autenticado) {
        await _carregar();
      }
      return;
    }

    final minha = _detalhe?.minhaAvaliacao;
    final resultado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FormularioAvaliacao(
        notaInicial: minha?.nota ?? 0,
        comentarioInicial: minha?.comentario,
      ),
    );
    if (resultado == null || !mounted) return;

    final id = _lugar.id;
    if (id == null) return;

    setState(() => _salvandoAvaliacao = true);
    try {
      await _repositorio.avaliarLugar(
        id,
        nota: resultado['nota'] as int,
        comentario: resultado['comentario'] as String?,
      );
      await _carregar();
      if (mounted) _avisar('Avaliação salva.');
    } on ApiException catch (erro) {
      if (mounted) _avisar(erro.message);
    } catch (erro) {
      if (mounted) _avisar('Não foi possível salvar a avaliação: $erro');
    } finally {
      if (mounted) setState(() => _salvandoAvaliacao = false);
    }
  }

  Future<void> _removerAvaliacao() async {
    final id = _lugar.id;
    if (id == null) return;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover sua avaliação?'),
        content: const Text(
          'A nota e o comentário serão removidos deste lugar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    setState(() => _salvandoAvaliacao = true);
    try {
      await _repositorio.removerAvaliacao(id);
      await _carregar();
      if (mounted) _avisar('Avaliação removida.');
    } on ApiException catch (erro) {
      if (mounted) _avisar(erro.message);
    } catch (erro) {
      if (mounted) _avisar('Não foi possível remover a avaliação: $erro');
    } finally {
      if (mounted) setState(() => _salvandoAvaliacao = false);
    }
  }

  Future<void> _adicionarAEvento() async {
    if (!widget.authController.autenticado) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => TelaLogin(
            authController: widget.authController,
            motivo: 'Entre para adicionar este local a um evento.',
          ),
        ),
      );
      if (!mounted || !widget.authController.autenticado) return;
    }
    if (_adicionandoEvento) return;

    setState(() => _adicionandoEvento = true);
    try {
      final eventos = await _eventosRepositorio.listarGerenciaveis();
      if (!mounted) return;

      if (eventos.isEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Nenhum evento disponível'),
            content: const Text(
              'Você ainda não tem eventos em que possa alterar o local. '
              'Crie um evento e tente novamente.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendi'),
              ),
            ],
          ),
        );
        return;
      }

      final escolhido = await showModalBottomSheet<EventoResumo>(
        context: context,
        builder: (context) => _SeletorEvento(eventos: eventos, lugar: _lugar),
      );
      if (escolhido == null || !mounted) return;

      await _eventosRepositorio.atualizarLocal(escolhido.id, _lugarComCatalogo);
      if (!mounted) return;
      _avisar('Local atualizado no evento "${escolhido.titulo}".');
    } on ApiException catch (erro) {
      if (mounted) _avisar(erro.message);
    } catch (erro) {
      if (mounted) _avisar('Não foi possível atualizar o evento: $erro');
    } finally {
      if (mounted) setState(() => _adicionandoEvento = false);
    }
  }

  Future<void> _abrirMapa() async {
    final lugar = _lugar;
    final latitude = lugar.latitude;
    final longitude = lugar.longitude;
    final endereco = lugar.endereco;

    final consulta = latitude != null && longitude != null
        ? '$latitude,$longitude'
        : (endereco ?? lugar.nome ?? '');
    if (consulta.trim().isEmpty) return;

    final escolha = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Abrir no Google Maps'),
              subtitle: Text(endereco ?? 'Abrir localização'),
              onTap: () => Navigator.of(context).pop('google'),
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Abrir no OpenStreetMap'),
              onTap: () => Navigator.of(context).pop('osm'),
            ),
          ],
        ),
      ),
    );
    if (escolha == null || !mounted) return;

    final codificado = Uri.encodeComponent(consulta);
    final uri = escolha == 'osm'
        ? Uri.parse(
            latitude != null && longitude != null
                ? 'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude#map=18/$latitude/$longitude'
                : 'https://www.openstreetmap.org/search?query=$codificado',
          )
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$codificado',
          );

    try {
      final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!abriu && mounted) _avisar('Nenhum aplicativo de mapa disponível.');
    } catch (erro) {
      if (mounted) _avisar('Não foi possível abrir o mapa: $erro');
    }
  }

  void _avisar(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lugar = _lugar;
    final detalhe = _detalhe;
    final fotos = FotosLugar.paraLugar(lugar.categoria, lugar.nome);
    final avaliacoes = detalhe?.avaliacoes ?? const <AvaliacaoLugar>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lugar'),
        actions: [
          IconButton(
            tooltip: 'Abrir no mapa',
            onPressed: _abrirMapa,
            icon: const Icon(Icons.map_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _galeria(fotos, theme),
          const SizedBox(height: PlacezTokens.espLg),
          Wrap(
            spacing: PlacezTokens.espSm,
            runSpacing: PlacezTokens.espSm,
            children: [
              _chip(theme, Icons.category_outlined, lugar.categoria ?? 'Lugar'),
              _chip(theme, Icons.location_city_outlined, lugar.cidade ?? ''),
              if (lugar.faixaPreco != null)
                _chip(theme, Icons.payments_outlined, lugar.faixaPreco!),
            ],
          ),
          const SizedBox(height: PlacezTokens.espMd),
          Text(
            lugar.rotulo,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: PlacezTokens.espSm),
          Row(
            children: [
              AvaliacaoEstrelas(
                nota: lugar.avaliacaoMedia,
                total: lugar.avaliacaoTotal,
              ),
              const Spacer(),
              if (lugar.distanciaMetros != null)
                Row(
                  children: [
                    Icon(
                      Icons.near_me_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatarDistancia(lugar.distanciaMetros),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_carregando) ...[
            const SizedBox(height: PlacezTokens.espMd),
            const LinearProgressIndicator(),
          ],
          if (_erro != null) ...[
            const SizedBox(height: PlacezTokens.espMd),
            AvisoPlacez(_erro!, erro: true),
          ],
          const SizedBox(height: PlacezTokens.espXl),
          CartaoSecao(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(lugar.endereco ?? 'Endereço não informado'),
              subtitle: Text(lugar.cidade ?? ''),
              trailing: const Icon(Icons.open_in_new),
              onTap: _abrirMapa,
            ),
          ),
          if (!widget.modoSelecao) ...[
            const SizedBox(height: PlacezTokens.espMd),
            OutlinedButton.icon(
              onPressed: _adicionandoEvento ? null : _adicionarAEvento,
              icon: _adicionandoEvento
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.event_available_outlined),
              label: const Text('Adicionar a um evento...'),
            ),
          ],
          if (detalhe != null && detalhe.itens.isNotEmpty) ...[
            const SizedBox(height: PlacezTokens.espXl),
            const TituloSecao('O que você encontra'),
            Wrap(
              spacing: PlacezTokens.espSm,
              runSpacing: PlacezTokens.espSm,
              children: [
                for (final item in detalhe.itens) Chip(label: Text(item)),
              ],
            ),
          ],
          if (lugar.descricao != null) ...[
            const SizedBox(height: PlacezTokens.espXl),
            const TituloSecao('Sobre o lugar'),
            Text(
              lugar.descricao!,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
          const SizedBox(height: PlacezTokens.espXl),
          Row(
            children: [
              Expanded(
                child: TituloSecao(
                  'Avaliações',
                  sufixo: avaliacoes.isEmpty ? null : '${avaliacoes.length}',
                ),
              ),
              TextButton.icon(
                onPressed: _salvandoAvaliacao ? null : _avaliar,
                icon: Icon(
                  detalhe?.minhaAvaliacao == null
                      ? Icons.star_outline
                      : Icons.edit_outlined,
                  size: 18,
                ),
                label: Text(
                  detalhe?.minhaAvaliacao == null
                      ? 'Avaliar'
                      : 'Editar avaliação',
                ),
              ),
            ],
          ),
          if (detalhe?.minhaAvaliacao != null) ...[
            Card(
              child: ListTile(
                leading: Icon(Icons.star, color: theme.colorScheme.tertiary),
                title: Text(
                  'Sua avaliação: '
                  '${detalhe!.minhaAvaliacao!.nota} '
                  '${detalhe.minhaAvaliacao!.nota == 1 ? 'estrela' : 'estrelas'}',
                ),
                subtitle: Text(
                  detalhe.minhaAvaliacao!.comentario ?? 'Sem comentário.',
                ),
                trailing: IconButton(
                  tooltip: 'Remover avaliação',
                  onPressed: _salvandoAvaliacao ? null : _removerAvaliacao,
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ),
            const SizedBox(height: PlacezTokens.espMd),
          ],
          if (!widget.authController.autenticado)
            const AvisoPlacez(
              'Entre para avaliar este lugar e ver os comentários da '
              'comunidade.',
            )
          else if (_carregando && detalhe == null)
            const Padding(
              padding: EdgeInsets.all(PlacezTokens.espXl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (avaliacoes.isEmpty)
            const EstadoVazio(
              icone: Icons.rate_review_outlined,
              titulo: 'Ainda não há comentários',
              descricao: 'Seja a primeira pessoa a avaliar este lugar.',
              padding: EdgeInsets.symmetric(vertical: PlacezTokens.espXl),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < avaliacoes.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _avaliacaoTile(avaliacoes[i], theme),
                  ],
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: widget.modoSelecao
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(_lugarComCatalogo),
                  icon: const Icon(Icons.check),
                  label: const Text('Usar este local'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _galeria(List<String> fotos, ThemeData theme) {
    return SizedBox(
      height: 210,
      child: ClipRRect(
        borderRadius: PlacezTokens.bordaLg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              itemCount: fotos.length,
              onPageChanged: (index) => setState(() => _paginaFoto = index),
              itemBuilder: (context, index) => Image.asset(
                fotos[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: theme.colorScheme.surfaceContainerHigh,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < fotos.length; i++)
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _paginaFoto
                            ? theme.colorScheme.primary
                            : Colors.white.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(ThemeData theme, IconData icone, String texto) {
    if (texto.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            texto,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avaliacaoTile(AvaliacaoLugar avaliacao, ThemeData theme) {
    final iniciais = avaliacao.autorNome.trim().isEmpty
        ? '?'
        : avaliacao.autorNome.trim()[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.all(PlacezTokens.espMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            child: Text(
              iniciais,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: PlacezTokens.espMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        avaliacao.autorNome,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _data(avaliacao.criadoEm),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                AvaliacaoEstrelas(
                  nota: avaliacao.nota.toDouble(),
                  tamanho: 13,
                  mostrarValor: false,
                ),
                if (avaliacao.comentario != null) ...[
                  const SizedBox(height: 4),
                  Text(avaliacao.comentario!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _data(DateTime? data) {
    if (data == null) return '';
    final local = data.toLocal();
    final dia = local.day.toString().padLeft(2, '0');
    final mes = local.month.toString().padLeft(2, '0');
    return '$dia/$mes/${local.year}';
  }
}

class _FormularioAvaliacao extends StatefulWidget {
  final int notaInicial;
  final String? comentarioInicial;

  const _FormularioAvaliacao({
    required this.notaInicial,
    this.comentarioInicial,
  });

  @override
  State<_FormularioAvaliacao> createState() => _FormularioAvaliacaoState();
}

class _FormularioAvaliacaoState extends State<_FormularioAvaliacao> {
  late int _nota = widget.notaInicial;
  late final TextEditingController _comentario = TextEditingController(
    text: widget.comentarioInicial ?? '',
  );

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        PlacezTokens.espLg,
        PlacezTokens.espLg,
        PlacezTokens.espLg,
        MediaQuery.viewInsetsOf(context).bottom + PlacezTokens.espLg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.notaInicial == 0 ? 'Avaliar lugar' : 'Editar avaliação',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: PlacezTokens.espSm),
            Text(
              'Dê de 1 a 5 estrelas.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: PlacezTokens.espMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: '$i ${i == 1 ? 'estrela' : 'estrelas'}',
                    onPressed: () => setState(() => _nota = i),
                    iconSize: 36,
                    icon: Icon(
                      i <= _nota ? Icons.star : Icons.star_border,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: PlacezTokens.espMd),
            TextField(
              controller: _comentario,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Comentário (opcional)',
                hintText: 'Conte como foi sua experiência...',
              ),
            ),
            const SizedBox(height: PlacezTokens.espSm),
            FilledButton.icon(
              onPressed: _nota == 0
                  ? null
                  : () => Navigator.of(context).pop({
                      'nota': _nota,
                      'comentario': _comentario.text.trim().isEmpty
                          ? null
                          : _comentario.text.trim(),
                    }),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Salvar avaliação'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeletorEvento extends StatelessWidget {
  final List<EventoResumo> eventos;
  final Local lugar;

  const _SeletorEvento({required this.eventos, required this.lugar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Adicionar a um evento',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              'Escolha um evento seu para receber o local "${lugar.rotulo}".',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: PlacezTokens.espMd),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: eventos.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final evento = eventos[index];
                  final mesmoLocal =
                      evento.localNome != null &&
                      evento.localNome == lugar.nome;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      child: Icon(
                        evento.rascunho
                            ? Icons.edit_note
                            : Icons.event_available,
                      ),
                    ),
                    title: Text(evento.titulo),
                    subtitle: Text(
                      [
                        _data(evento.inicioEm),
                        evento.rascunho ? 'Rascunho' : 'Confirmado',
                        mesmoLocal
                            ? 'já usa este local'
                            : (evento.localNome ?? 'sem local'),
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pop(evento),
                  );
                },
              ),
            ),
            const SizedBox(height: PlacezTokens.espSm),
            Text(
              'Mostrando os 5 eventos seus modificados mais recentemente.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _data(DateTime? data) {
    if (data == null) return 'data a definir';
    final local = data.toLocal();
    final dia = local.day.toString().padLeft(2, '0');
    final mes = local.month.toString().padLeft(2, '0');
    return '$dia/$mes/${local.year}';
  }
}
