import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/events/events_controller.dart';
import '../../core/events/local_catalog.dart';
import '../../core/friends/friends_repository.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/amizade.dart';
import '../../data/models/evento.dart';
import '../widgets/seletor_mapa.dart';
import 'cadastro.dart';

class TelaDetalheEvento extends StatefulWidget {
  final EventsController eventsController;
  final int eventoId;
  final Evento? eventoInicial;

  const TelaDetalheEvento({
    super.key,
    required this.eventsController,
    required this.eventoId,
    this.eventoInicial,
  });

  @override
  State<TelaDetalheEvento> createState() => _TelaDetalheEventoState();
}

class _TelaDetalheEventoState extends State<TelaDetalheEvento> {
  bool _carregandoAmigos = false;

  EventsController get _controller => widget.eventsController;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    await _controller.detalhar(widget.eventoId);
  }

  Evento? get _evento =>
      _controller.eventoPorId(widget.eventoId) ?? widget.eventoInicial;

  Future<void> _responder(RsvpStatus rsvp) async {
    if (_controller.acaoEmAndamento) return;
    final erro = await _controller.responderRsvp(widget.eventoId, rsvp);
    if (!mounted) return;
    _avisar(erro ?? 'Presença atualizada.');
  }

  Future<void> _abrirEdicao(Evento evento) async {
    final alterou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => TelaCadastroEvento(
          eventsController: _controller,
          eventoParaEditar: evento,
        ),
      ),
    );
    if (alterou == true && mounted) {
      await _controller.detalhar(widget.eventoId, silencioso: true);
    }
  }

  Future<void> _cancelarEvento(Evento evento) async {
    final confirmou = await _confirmar(
      titulo: 'Cancelar evento?',
      mensagem:
          'O evento "${evento.titulo}" será cancelado e deixará de aparecer '
          'no calendário dos convidados.',
      rotulo: 'Cancelar evento',
    );
    if (confirmou != true || !mounted) return;

    final erro = await _controller.cancelar(widget.eventoId);
    if (!mounted) return;
    if (erro != null) {
      _avisar(erro);
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _alternarConfig({
    bool? privado,
    bool? permitirMembrosConvidar,
  }) async {
    if (_controller.acaoEmAndamento) return;
    final erro = await _controller.atualizarConfig(
      widget.eventoId,
      privado: privado,
      permitirMembrosConvidar: permitirMembrosConvidar,
    );
    if (!mounted) return;
    _avisar(erro ?? 'Configuração atualizada.');
  }

  Future<void> _abrirConvite(Evento evento) async {
    if (_controller.acaoEmAndamento || _carregandoAmigos) return;

    setState(() => _carregandoAmigos = true);
    List<Amigo> amigos;
    try {
      final auth = _controller.auth;
      final repositorio = FriendsRepository(
        tokenProvider: () async => auth.sessao?.token,
        onUnauthorized: auth.tratarNaoAutorizado,
      );
      amigos = await repositorio.listarAmigos();
    } on ApiException catch (erro) {
      if (mounted) _avisar(erro.message);
      return;
    } catch (erro) {
      if (mounted) _avisar('Não foi possível carregar seus amigos: $erro');
      return;
    } finally {
      if (mounted) setState(() => _carregandoAmigos = false);
    }

    final jaConvidados = evento.convidados
        .map((convidado) => convidado.usuario.id)
        .toSet();
    final disponiveis = amigos
        .where((amigo) => !jaConvidados.contains(amigo.usuario.id))
        .toList();

    if (!mounted) return;
    if (disponiveis.isEmpty) {
      _avisar('Todos os seus amigos já foram convidados.');
      return;
    }

    final selecao = <int>{};
    final resultado = await showDialog<Set<int>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Convidar amigos'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  itemCount: disponiveis.length,
                  itemBuilder: (context, index) {
                    final amigo = disponiveis[index];
                    return CheckboxListTile(
                      value: selecao.contains(amigo.usuario.id),
                      title: Text(amigo.usuario.nome),
                      subtitle: Text(amigo.usuario.identificador),
                      onChanged: (valor) {
                        setDialogState(() {
                          if (valor == true) {
                            selecao.add(amigo.usuario.id);
                          } else {
                            selecao.remove(amigo.usuario.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: selecao.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(selecao),
                  child: const Text('Convidar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado == null || resultado.isEmpty || !mounted) return;

    final erro = await _controller.convidar(
      widget.eventoId,
      resultado.toList(),
    );
    if (!mounted) return;
    _avisar(erro ?? 'Convite(s) enviado(s).');
  }

  Future<void> _convidarTodos() async {
    if (_controller.acaoEmAndamento) return;
    final erro = await _controller.convidarTodos(widget.eventoId);
    if (!mounted) return;
    _avisar(erro ?? 'Convites enviados para todos os amigos.');
  }

  Future<void> _removerConvidado(ConvidadoEvento convidado) async {
    final confirmou = await _confirmar(
      titulo: 'Remover convidado?',
      mensagem:
          'Remover ${convidado.usuario.nome} do evento "${_evento?.titulo ?? ''}"?',
      rotulo: 'Remover',
    );
    if (confirmou != true || !mounted) return;

    final erro = await _controller.removerConvidado(
      widget.eventoId,
      convidado.usuario.id,
    );
    if (!mounted) return;
    _avisar(erro ?? 'Convidado removido.');
  }

  Future<bool?> _confirmar({
    required String titulo,
    required String mensagem,
    required String rotulo,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(titulo),
          content: Text(mensagem),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(rotulo),
            ),
          ],
        );
      },
    );
  }

  void _avisar(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final evento = _evento;

        if (evento == null) {
          if (_controller.detalhando) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Evento')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _controller.erro ?? 'Evento não encontrado.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _carregar,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return _montarScaffold(evento);
      },
    );
  }

  Widget _montarScaffold(Evento evento) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(evento.titulo),
        actions: [
          if (evento.souCriador)
            PopupMenuButton<String>(
              enabled: !_controller.acaoEmAndamento && !evento.cancelado,
              tooltip: 'Opções do evento',
              onSelected: (valor) {
                if (valor == 'editar') _abrirEdicao(evento);
                if (valor == 'cancelar') _cancelarEvento(evento);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'editar',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Editar evento'),
                  ),
                ),
                PopupMenuItem(
                  value: 'cancelar',
                  child: ListTile(
                    leading: Icon(Icons.event_busy_outlined),
                    title: Text('Cancelar evento'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (_controller.erro != null) ...[
              _Aviso(
                mensagem: _controller.erro!,
                erro: true,
                onFechar: _controller.limparErro,
              ),
              const SizedBox(height: 12),
            ],
            if (_controller.mostrandoCache) ...[
              const _Aviso(
                mensagem: 'Sem conexão com a API. Mostrando dados salvos no aparelho.',
              ),
              const SizedBox(height: 12),
            ],
            _cabecalho(evento, theme),
            const SizedBox(height: 16),
            _card(
              theme,
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Início'),
                  subtitle: Text(_formatarDataHora(evento.inicioEm)),
                ),
                ListTile(
                  leading: const Icon(Icons.event_available),
                  title: const Text('Fim'),
                  subtitle: Text(_formatarDataHora(evento.fimEm)),
                ),
                if (evento.local != null)
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(evento.local!.rotulo),
                    subtitle: Text(
                      [
                        evento.local!.endereco,
                        evento.local!.categoria,
                        formatarDistancia(evento.local!.distanciaMetros),
                      ].whereType<String>().join(' · '),
                    ),
                    trailing:
                        evento.local!.latitude != null &&
                            evento.local!.longitude != null
                        ? IconButton(
                            tooltip: 'Ver no mapa',
                            onPressed: () => _abrirMapa(evento),
                            icon: const Icon(Icons.map_outlined),
                          )
                        : null,
                  ),
              ],
            ),
            if (evento.descricao != null) ...[
              const SizedBox(height: 16),
              Text(
                'Descrição',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(evento.descricao!),
            ],
            const SizedBox(height: 20),
            Text(
              'Presenças',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            _contagem(evento, theme),
            if (!evento.cancelado) ...[
              const SizedBox(height: 12),
              if (evento.souCriador)
                const _Aviso(
                  mensagem: 'Você é o criador do evento e está confirmado automaticamente.',
                )
              else
                _acoesRsvp(evento, theme),
            ],
            const SizedBox(height: 20),
            _configuracoes(evento, theme),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Convidados',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (evento.podeConvidar && !evento.cancelado) ...[
                  if (_carregandoAmigos)
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    TextButton.icon(
                      onPressed: _controller.acaoEmAndamento
                          ? null
                          : () => _abrirConvite(evento),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Convidar'),
                    ),
                ],
              ],
            ),
            if (evento.podeConvidar && !evento.cancelado)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _controller.acaoEmAndamento
                      ? null
                      : _convidarTodos,
                  icon: const Icon(Icons.group_add_outlined, size: 18),
                  label: const Text('Convidar todos os amigos'),
                ),
              ),
            const SizedBox(height: 4),
            _card(
              theme,
              children: evento.convidados.isEmpty
                  ? [const ListTile(title: Text('Nenhum convidado ainda.'))]
                  : evento.convidados
                        .map((convidado) => _convidadoTile(evento, convidado))
                        .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cabecalho(Evento evento, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            evento.titulo,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.end,
          children: [
            Chip(
              avatar: Icon(
                evento.cancelado ? Icons.cancel_outlined : Icons.check_circle,
                size: 16,
              ),
              label: Text(evento.cancelado ? 'Cancelado' : 'Confirmado'),
            ),
            Chip(
              avatar: Icon(
                evento.privado ? Icons.lock_outline : Icons.public,
                size: 16,
              ),
              label: Text(evento.privado ? 'Privado' : 'Aberto'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _contagem(Evento evento, ThemeData theme) {
    return Row(
      children: [
        _contagemItem(
          theme,
          Icons.check_circle_outline,
          'Vou',
          evento.contagem.vou,
        ),
        const SizedBox(width: 8),
        _contagemItem(
          theme,
          Icons.help_outline,
          'Talvez',
          evento.contagem.talvez,
        ),
        const SizedBox(width: 8),
        _contagemItem(
          theme,
          Icons.hourglass_empty,
          'Sem resposta',
          evento.contagem.semResposta,
        ),
      ],
    );
  }

  Widget _contagemItem(
    ThemeData theme,
    IconData icone,
    String rotulo,
    int valor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icone, size: 20, color: theme.colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              '$valor',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(rotulo, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  Widget _acoesRsvp(Evento evento, ThemeData theme) {
    final desabilitado = _controller.acaoEmAndamento;
    return Row(
      children: [
        Expanded(
          child: evento.meuRsvp == RsvpStatus.vou
              ? FilledButton.icon(
                  onPressed: desabilitado
                      ? null
                      : () => _responder(RsvpStatus.vou),
                  icon: const Icon(Icons.check),
                  label: const Text('Vou'),
                )
              : OutlinedButton.icon(
                  onPressed: desabilitado
                      ? null
                      : () => _responder(RsvpStatus.vou),
                  icon: const Icon(Icons.check),
                  label: const Text('Vou'),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: evento.meuRsvp == RsvpStatus.talvez
              ? FilledButton.tonalIcon(
                  onPressed: desabilitado
                      ? null
                      : () => _responder(RsvpStatus.talvez),
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Talvez'),
                )
              : OutlinedButton.icon(
                  onPressed: desabilitado
                      ? null
                      : () => _responder(RsvpStatus.talvez),
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Talvez'),
                ),
        ),
      ],
    );
  }

  Widget _configuracoes(Evento evento, ThemeData theme) {
    if (!evento.souCriador) {
      return _Aviso(
        mensagem: evento.podeConvidar
            ? 'O criador permitiu que membros também convidem amigos.'
            : 'Somente o criador pode convidar por enquanto.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configurações',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: evento.privado,
          onChanged: evento.cancelado || _controller.acaoEmAndamento
              ? null
              : (valor) => _alternarConfig(privado: valor),
          title: const Text('Evento privado'),
          subtitle: const Text('Somente convidados podem ver o evento.'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: evento.permitirMembrosConvidar,
          onChanged: evento.cancelado || _controller.acaoEmAndamento
              ? null
              : (valor) => _alternarConfig(permitirMembrosConvidar: valor),
          title: const Text('Membros também podem convidar'),
          subtitle: const Text(
            'Permite que qualquer convidado traga novos amigos.',
          ),
        ),
      ],
    );
  }

  Widget _convidadoTile(Evento evento, ConvidadoEvento convidado) {
    final rsvp = convidado.isCriador
        ? 'Criador · Vou'
        : switch (convidado.rsvp) {
            RsvpStatus.vou => 'Vou',
            RsvpStatus.talvez => 'Talvez',
            null => 'Sem resposta',
          };

    return ListTile(
      leading: CircleAvatar(child: Text(_iniciais(convidado.usuario.nome))),
      title: Text(convidado.usuario.nome),
      subtitle: Text('${convidado.usuario.identificador} · $rsvp'),
      trailing: evento.souCriador && !convidado.isCriador
          ? IconButton(
              tooltip: 'Remover convidado',
              onPressed: _controller.acaoEmAndamento
                  ? null
                  : () => _removerConvidado(convidado),
              icon: const Icon(Icons.person_remove_outlined),
            )
          : null,
    );
  }

  Widget _card(ThemeData theme, {required List<Widget> children}) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(children: children),
    );
  }

  String _formatarDataHora(DateTime? data) {
    if (data == null) return 'A definir';
    final local = data.toLocal();
    final dia = local.day.toString().padLeft(2, '0');
    final mes = local.month.toString().padLeft(2, '0');
    final hora = local.hour.toString().padLeft(2, '0');
    final minuto = local.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${local.year} às $hora:$minuto';
  }

  String _iniciais(String nome) {
    final partes = nome
        .trim()
        .split(RegExp(r'\s+'))
        .where((parte) => parte.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  void _abrirMapa(Evento evento) {
    final local = evento.local;
    if (local?.latitude == null || local?.longitude == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SeletorMapa(
          posicaoInicial: LatLng(local!.latitude!, local.longitude!),
          apenasVisualizacao: true,
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String mensagem;
  final VoidCallback? onFechar;
  final bool erro;

  const _Aviso({required this.mensagem, this.onFechar, this.erro = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fundo = erro
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.secondaryContainer;
    final frente = erro
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, onFechar == null ? 12 : 4, 10),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            erro ? Icons.error_outline : Icons.info_outline,
            color: frente,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensagem,
              style: theme.textTheme.bodySmall?.copyWith(color: frente),
            ),
          ),
          if (onFechar != null)
            IconButton(
              onPressed: onFechar,
              icon: Icon(Icons.close, size: 18, color: frente),
              tooltip: 'Fechar aviso',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
