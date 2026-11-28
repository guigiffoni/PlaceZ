import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/chat/chat_repository.dart';
import '../../core/events/events_controller.dart';
import '../../core/events/local_catalog.dart';
import '../../core/friends/friends_repository.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/amizade.dart';
import '../../data/models/conversa.dart';
import '../../data/models/enquete.dart';
import '../../data/models/evento.dart';
import '../../data/models/local.dart';
import '../../tema.dart';
import '../widgets/avatar_usuario.dart';
import '../widgets/formulario_combinacao.dart';
import '../widgets/imagem_evento.dart';
import '../widgets/placez_componentes.dart';
import 'cadastro.dart';
import 'combinacao.dart';
import 'conversa.dart';
import 'lugar_detalhe.dart';

class TelaDetalheEvento extends StatefulWidget {
  final EventsController eventsController;
  final int eventoId;
  final Evento? eventoInicial;
  final int abaInicial;

  const TelaDetalheEvento({
    super.key,
    required this.eventsController,
    required this.eventoId,
    this.eventoInicial,
    this.abaInicial = 0,
  });

  @override
  State<TelaDetalheEvento> createState() => _TelaDetalheEventoState();
}

class _TelaDetalheEventoState extends State<TelaDetalheEvento> {
  bool _carregandoAmigos = false;
  late final ChatRepository _chatRepository;
  Conversa? _chatEvento;
  bool _carregandoChat = false;
  bool _criandoChat = false;
  String? _erroChat;

  EventsController get _controller => widget.eventsController;

  @override
  void initState() {
    super.initState();
    final auth = _controller.auth;
    _chatRepository = ChatRepository(
      tokenProvider: () async => auth.sessao?.token,
      onUnauthorized: auth.tratarNaoAutorizado,
    );
    _carregar();
    _carregarChat();
  }

  Future<void> _carregar() async {
    await _controller.detalhar(widget.eventoId);
  }

  Future<void> _carregarChat() async {
    if (!_controller.auth.autenticado) return;

    setState(() {
      _carregandoChat = true;
      _erroChat = null;
    });

    try {
      final conversa = await _chatRepository.buscarChatEvento(widget.eventoId);
      if (!mounted) return;
      setState(() => _chatEvento = conversa);
    } on ApiException catch (erro) {
      if (!mounted) return;
      if (erro.statusCode == 404) {
        setState(() => _chatEvento = null);
      } else {
        setState(() => _erroChat = erro.message);
      }
    } catch (erro) {
      if (!mounted) return;
      setState(() => _erroChat = 'Não foi possível carregar o chat: $erro');
    } finally {
      if (mounted) setState(() => _carregandoChat = false);
    }
  }

  Future<void> _criarChatEvento() async {
    if (_criandoChat) return;

    setState(() => _criandoChat = true);
    try {
      final conversa = await _chatRepository.criarChatEvento(widget.eventoId);
      if (!mounted) return;
      setState(() {
        _chatEvento = conversa;
        _erroChat = null;
      });
      _avisar('Chat do evento criado.');
    } on ApiException catch (erro) {
      if (mounted) _avisar(erro.message);
    } catch (erro) {
      if (mounted) _avisar('Não foi possível criar o chat: $erro');
    } finally {
      if (mounted) setState(() => _criandoChat = false);
    }
  }

  Future<void> _abrirChatEvento(Conversa conversa) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TelaConversa(
          authController: _controller.auth,
          conversaId: conversa.id,
          titulo: conversa.nome,
          podeEnviarInicial: conversa.podeEnviar,
          bloqueadaInicial: conversa.bloqueada,
          ehEvento: true,
        ),
      ),
    );
    if (mounted) _carregarChat();
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

  List<Widget> _acoesEvento(Evento evento) {
    final habilitado = !_controller.acaoEmAndamento && !evento.cancelado;
    final compacto = MediaQuery.sizeOf(context).width < 360;
    if (compacto) {
      return [
        PopupMenuButton<String>(
          enabled: habilitado,
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
      ];
    }

    final theme = Theme.of(context);
    return [
      IconButton(
        tooltip: 'Editar evento',
        onPressed: habilitado ? () => _abrirEdicao(evento) : null,
        icon: const Icon(Icons.edit_outlined),
      ),
      IconButton(
        tooltip: 'Cancelar evento',
        onPressed: habilitado ? () => _cancelarEvento(evento) : null,
        icon: const Icon(Icons.event_busy_outlined),
        style: IconButton.styleFrom(
          foregroundColor: theme.colorScheme.error,
          disabledForegroundColor: theme.colorScheme.onSurface.withValues(
            alpha: 0.38,
          ),
        ),
      ),
    ];
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

    return DefaultTabController(
      length: 2,
      initialIndex: widget.abaInicial,
      child: Scaffold(
        appBar: AppBar(
          title: Text(evento.titulo),
          actions: [if (evento.souCriador) ..._acoesEvento(evento)],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Detalhes'),
              Tab(text: 'Combinação'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                await _carregar();
                await _carregarChat();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  if (_controller.erro != null) ...[
                    AvisoPlacez(
                      _controller.erro!,
                      erro: true,
                      onFechar: _controller.limparErro,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_controller.mostrandoCache) ...[
                    const AvisoPlacez(
                      'Sem conexão com a API. Mostrando dados salvos no '
                      'aparelho.',
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (evento.temImagem && evento.id != null) ...[
                    ClipRRect(
                      borderRadius: PlacezTokens.bordaLg,
                      child: SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: ImagemEvento(
                          auth: _controller.auth,
                          eventoId: evento.id!,
                          versao:
                              evento
                                  .imagemAtualizadaEm
                                  ?.millisecondsSinceEpoch ??
                              0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _cabecalho(evento, theme),
                  const SizedBox(height: 16),
                  _card(
                    theme,
                    children: [
                      if (evento.status == 'RASCUNHO')
                        ListTile(
                          leading: const Icon(Icons.auto_awesome_outlined),
                          title: const Text('Combinação de dias'),
                          subtitle: Text(
                            evento.souCriador
                                ? 'Defina ou regenere os dias possíveis'
                                : 'Aguardando o criador definir os dias',
                          ),
                          trailing: evento.souCriador
                              ? TextButton(
                                  onPressed: _abrirCombinacaoEvento,
                                  child: const Text('Definir'),
                                )
                              : null,
                          onTap: evento.souCriador
                              ? _abrirCombinacaoEvento
                              : null,
                        )
                      else ...[
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
                      ],
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
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () => _abrirOpcoesLocal(evento),
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
                    if (!evento.confirmado)
                      const AvisoPlacez(
                        'Este evento está em rascunho. A data e as presenças '
                        'serão definidas na aba Combinação.',
                      )
                    else if (evento.souCriador)
                      const AvisoPlacez(
                        'Você é o criador do evento e está confirmado '
                        'automaticamente.',
                      )
                    else
                      _acoesRsvp(evento, theme),
                  ],
                  const SizedBox(height: 20),
                  _configuracoes(evento, theme),
                  ..._chatEventoWidgets(evento, theme),
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
                        ? [
                            const ListTile(
                              title: Text('Nenhum convidado ainda.'),
                            ),
                          ]
                        : evento.convidados
                              .map(
                                (convidado) =>
                                    _convidadoTile(evento, convidado),
                              )
                              .toList(),
                  ),
                ],
              ),
            ),
            CombinacaoTab(
              eventsController: _controller,
              eventoId: widget.eventoId,
              eventoInicial: evento,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cabecalho(Evento evento, ThemeData theme) {
    final paletaStatus = evento.cancelado
        ? theme.colorScheme.cancelado
        : evento.confirmado
        ? theme.colorScheme.sucesso
        : theme.colorScheme.rascunho;
    final paletaPrivacidade = PaletaStatus(
      fundo: theme.colorScheme.secondaryContainer,
      frente: theme.colorScheme.onSecondaryContainer,
      borda: theme.colorScheme.secondary.withValues(alpha: 0.3),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PlacezTokens.espLg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: PlacezTokens.bordaLg,
        border: Border.all(color: theme.colorScheme.bordaSutil),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            evento.titulo,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: PlacezTokens.espMd),
          Wrap(
            spacing: PlacezTokens.espSm,
            runSpacing: PlacezTokens.espSm,
            children: [
              StatusEventoChip(
                rotulo: evento.cancelado
                    ? 'Cancelado'
                    : evento.confirmado
                    ? 'Confirmado'
                    : 'Rascunho',
                icone: evento.cancelado
                    ? Icons.cancel_outlined
                    : evento.confirmado
                    ? Icons.check_circle
                    : Icons.edit_note,
                paleta: paletaStatus,
              ),
              StatusEventoChip(
                rotulo: evento.privado ? 'Privado' : 'Aberto',
                icone: evento.privado ? Icons.lock_outline : Icons.public,
                paleta: paletaPrivacidade,
              ),
            ],
          ),
        ],
      ),
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
          paleta: theme.colorScheme.sucesso,
        ),
        const SizedBox(width: 8),
        _contagemItem(
          theme,
          Icons.help_outline,
          'Talvez',
          evento.contagem.talvez,
          paleta: theme.colorScheme.alerta,
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
    int valor, {
    PaletaStatus? paleta,
  }) {
    final fundo = paleta?.fundo ?? theme.colorScheme.surfaceContainerLow;
    final frente = paleta?.frente ?? theme.colorScheme.onSurfaceVariant;
    final borda = paleta?.borda ?? theme.colorScheme.bordaSutil;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: fundo,
          borderRadius: PlacezTokens.bordaMd,
          border: Border.all(color: borda),
        ),
        child: Column(
          children: [
            Icon(icone, size: 20, color: frente),
            const SizedBox(height: 4),
            Text(
              '$valor',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: paleta?.frente,
              ),
            ),
            Text(
              rotulo,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: paleta?.frente,
              ),
            ),
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

  List<Widget> _chatEventoWidgets(Evento evento, ThemeData theme) {
    if (_chatEvento != null) {
      final conversa = _chatEvento!;
      return [
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: theme.colorScheme.surfaceContainerLow,
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.groups)),
            title: const Text('Chat do evento'),
            subtitle: Text(
              conversa.ultimaMensagem?.texto ??
                  'Converse com os participantes do evento.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _abrirChatEvento(conversa),
          ),
        ),
      ];
    }

    if (!evento.souCriador || evento.cancelado) return const [];

    if (_carregandoChat) {
      return const [
        SizedBox(height: 20),
        Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ];
    }

    return [
      const SizedBox(height: 20),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _criandoChat ? null : _criarChatEvento,
          icon: _criandoChat
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.forum_outlined, size: 18),
          label: const Text('Criar chat do evento'),
        ),
      ),
      if (_erroChat != null)
        Text(
          _erroChat!,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
    ];
  }

  Widget _configuracoes(Evento evento, ThemeData theme) {
    if (!evento.souCriador) {
      return AvisoPlacez(
        evento.podeConvidar
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
      leading: AvatarUsuario(
        auth: _controller.auth,
        usuarioId: convidado.usuario.id,
        nome: convidado.usuario.nome,
        raio: 20,
      ),
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

  Future<void> _abrirOpcoesLocal(Evento evento) async {
    final local = evento.local;
    if (local == null) return;
    final podeInfo = local.catalogoId != null;

    final opcao = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              enabled: podeInfo,
              leading: const Icon(Icons.place_outlined),
              title: const Text('Abrir informações do local no app'),
              subtitle: Text(
                podeInfo
                    ? 'Ver fotos, avaliações e detalhes'
                    : 'Local não vinculado ao catálogo',
              ),
              onTap: podeInfo ? () => Navigator.of(context).pop('app') : null,
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Abrir no aplicativo de mapa padrão'),
              onTap: () => Navigator.of(context).pop('mapa'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || opcao == null) return;
    if (opcao == 'app') {
      final catalogoId = local.catalogoId;
      if (catalogoId == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TelaDetalheLugar(
            authController: _controller.auth,
            lugarInicial: Local(
              id: catalogoId,
              catalogoId: catalogoId,
              nome: local.nome,
              endereco: local.endereco,
              categoria: local.categoria,
              latitude: local.latitude,
              longitude: local.longitude,
              distanciaMetros: local.distanciaMetros,
            ),
          ),
        ),
      );
      return;
    }

    await _abrirMapaPadrao(local);
  }

  Future<void> _abrirMapaPadrao(Local local) async {
    final latitude = local.latitude;
    final longitude = local.longitude;
    final rotulo = Uri.encodeComponent(local.nome ?? 'Local do evento');
    final busca = Uri.encodeComponent(
      local.endereco ?? local.nome ?? 'Local do evento',
    );

    final geo = latitude != null && longitude != null
        ? Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude($rotulo)')
        : Uri.parse('geo:0,0?q=$busca');
    final fallback = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query='
      '${latitude != null && longitude != null ? '$latitude,$longitude' : busca}',
    );

    try {
      final abriu = await launchUrl(geo, mode: LaunchMode.externalApplication);
      if (!abriu) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      } catch (erro) {
        if (mounted) _avisar('Não foi possível abrir o mapa: $erro');
      }
    }
  }

  Future<void> _abrirCombinacaoEvento() async {
    EnqueteDisponibilidade? existente;
    var regenerar = false;

    try {
      final consulta = await _controller.consultarEnquete(widget.eventoId);
      existente = consulta.enquete;
      regenerar = true;
    } on ApiException catch (erro) {
      if (erro.statusCode != 404) {
        _avisar(erro.message);
        return;
      }
    } catch (erro) {
      _avisar('Não foi possível carregar a combinação: $erro');
      return;
    }
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (modalContext) => SizedBox(
        height: MediaQuery.sizeOf(modalContext).height * 0.9,
        child: FormularioCombinacao(
          inicial: existente,
          regenerar: regenerar,
          onCriar: (entrada) async {
            try {
              await _controller.criarEnquete(
                widget.eventoId,
                entrada,
                regenerar: regenerar,
              );
              if (modalContext.mounted) Navigator.of(modalContext).pop();
              if (mounted) {
                await _controller.detalhar(widget.eventoId, silencioso: true);
                _avisar(
                  regenerar
                      ? 'Opções de data regeradas.'
                      : 'Combinação de dias criada.',
                );
              }
              return null;
            } on ApiException catch (erro) {
              return erro.message;
            } catch (erro) {
              return 'Não foi possível salvar a combinação: $erro';
            }
          },
        ),
      ),
    );
  }
}
