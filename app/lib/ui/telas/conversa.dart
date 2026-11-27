import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/chat/chat_repository.dart';
import '../../core/chat/polling_service.dart';
import '../../core/network/api_exception.dart';
import '../../data/dao/chat_dao.dart';
import '../../data/models/conversa.dart';
import '../../tema.dart';
import 'grupo.dart';

class TelaConversa extends StatefulWidget {
  final AuthController authController;
  final int conversaId;
  final String titulo;
  final int? outroUsuarioId;
  final bool podeEnviarInicial;
  final bool bloqueadaInicial;
  final bool ehEvento;
  final bool ehGrupo;
  final int? grupoId;

  const TelaConversa({
    super.key,
    required this.authController,
    required this.conversaId,
    required this.titulo,
    this.outroUsuarioId,
    this.podeEnviarInicial = true,
    this.bloqueadaInicial = false,
    this.ehEvento = false,
    this.ehGrupo = false,
    this.grupoId,
  });

  @override
  State<TelaConversa> createState() => _TelaConversaState();
}

class _TelaConversaState extends State<TelaConversa>
    with WidgetsBindingObserver {
  final ChatDao _cache = ChatDao();
  final TextEditingController _textoController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final ChatRepository _repositorio;
  late final PollingService _polling;

  List<Mensagem> _mensagens = [];
  int _ultimaId = 0;
  bool _carregando = true;
  bool _buscandoNovas = false;
  bool _enviando = false;
  bool _mostrandoCache = false;
  bool _podeEnviar = true;
  bool _bloqueada = false;
  String? _erro;

  int? get _meuId => widget.authController.usuario?.id;

  @override
  void initState() {
    super.initState();
    _podeEnviar = widget.podeEnviarInicial;
    _bloqueada = widget.bloqueadaInicial;
    _repositorio = ChatRepository(
      tokenProvider: () async => widget.authController.sessao?.token,
      onUnauthorized: widget.authController.tratarNaoAutorizado,
    );
    _polling = PollingService(
      intervalo: const Duration(seconds: 5),
      acao: _buscarNovas,
    );
    WidgetsBinding.instance.addObserver(this);
    _carregar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _polling.parar();
    _textoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      _polling.iniciar();
      _buscarNovas();
    } else {
      _polling.parar();
    }
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    var temCache = false;
    try {
      final cacheadas = await _cache.carregarMensagens(widget.conversaId);
      if (cacheadas.isNotEmpty && mounted) {
        temCache = true;
        setState(() {
          _mensagens = cacheadas;
          _ultimaId = cacheadas.last.id;
          _mostrandoCache = true;
        });
        _agendarScroll();
      }
    } catch (_) {
      // Cache é apenas conveniência.
    }

    try {
      final mensagens = await _repositorio.listarMensagens(widget.conversaId);
      if (!mounted) return;
      setState(() {
        _mensagens = mensagens;
        _ultimaId = mensagens.isEmpty ? 0 : mensagens.last.id;
        _mostrandoCache = false;
        _erro = null;
      });
      await _cache.salvarMensagens(mensagens);
      if (mensagens.isNotEmpty) {
        unawaited(_marcarLida(mensagens.last.id));
      }
      _agendarScroll();
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = erro.message;
        if (temCache) _mostrandoCache = true;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar as mensagens: $erro';
        if (temCache) _mostrandoCache = true;
      });
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
        _polling.iniciar();
      }
    }
  }

  Future<void> _buscarNovas() async {
    if (_buscandoNovas || !mounted) return;
    _buscandoNovas = true;
    try {
      final novas = await _repositorio.listarMensagens(
        widget.conversaId,
        afterId: _ultimaId == 0 ? null : _ultimaId,
      );
      if (!mounted) return;
      if (_mostrandoCache) {
        setState(() => _mostrandoCache = false);
      }
      if (novas.isEmpty) return;

      final existentes = _mensagens.map((item) => item.id).toSet();
      final filtradas = novas
          .where((item) => !existentes.contains(item.id))
          .toList();
      if (filtradas.isEmpty) return;

      final estavaNoFinal = _estaNoFinal();
      setState(() {
        _mensagens = [..._mensagens, ...filtradas]
          ..sort((a, b) => a.id.compareTo(b.id));
        _ultimaId = _mensagens.last.id;
        _mostrandoCache = false;
        _erro = null;
      });
      await _cache.salvarMensagens(filtradas);
      unawaited(_marcarLida(_ultimaId));
      if (estavaNoFinal) _agendarScroll();
    } catch (_) {
      // O polling silencioso não interrompe a conversa por falha de rede.
    } finally {
      _buscandoNovas = false;
    }
  }

  Future<void> _enviar() async {
    final texto = _textoController.text.trim();
    if (texto.isEmpty || _enviando || !_podeEnviar) return;

    setState(() => _enviando = true);
    try {
      final mensagem = await _repositorio.enviarMensagem(
        widget.conversaId,
        texto,
      );
      if (!mounted) return;
      _textoController.clear();
      setState(() {
        if (!_mensagens.any((item) => item.id == mensagem.id)) {
          _mensagens = [..._mensagens, mensagem]
            ..sort((a, b) => a.id.compareTo(b.id));
        }
        _ultimaId = _mensagens.last.id;
      });
      await _cache.salvarMensagens([mensagem]);
      unawaited(_marcarLida(_ultimaId));
      _agendarScroll();
    } on ApiException catch (erro) {
      if (!mounted) return;
      if (erro.code == 'CONVERSA_BLOQUEADA' ||
          erro.code == 'CONVERSA_NAO_PERMITIDA') {
        setState(() {
          _podeEnviar = false;
          _bloqueada = erro.code == 'CONVERSA_BLOQUEADA';
        });
      }
      _avisar(erro.message);
    } catch (erro) {
      if (mounted) _avisar('Não foi possível enviar a mensagem: $erro');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _abrirGrupo() async {
    final grupoId = widget.grupoId;
    if (grupoId == null) return;

    final saiu = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => TelaGrupo(
          authController: widget.authController,
          grupoId: grupoId,
          nomeInicial: widget.titulo,
        ),
      ),
    );
    if (saiu == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _marcarLida(int ultimaId) async {
    if (ultimaId <= 0) return;
    try {
      await _repositorio.marcarLida(
        widget.conversaId,
        ultimaMensagemId: ultimaId,
      );
    } catch (_) {
      // A marcação de leitura é best-effort; o polling tenta novamente.
    }
  }

  bool _estaNoFinal() {
    if (!_scrollController.hasClients) return true;
    final posicao = _scrollController.position;
    return posicao.maxScrollExtent - posicao.pixels < 120;
  }

  void _agendarScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.titulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.ehGrupo && widget.grupoId != null)
            IconButton(
              tooltip: 'Membros do grupo',
              onPressed: _abrirGrupo,
              icon: const Icon(Icons.people_outline),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_bloqueada)
            _faixa(
              theme,
              'Não é possível enviar mensagens enquanto houver bloqueio.',
            )
          else if (!_podeEnviar)
            _faixa(
              theme,
              'Vocês não são mais amigos. O histórico continua visível.',
            ),
          if (_erro != null && _mensagens.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_erro!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _carregar,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(child: _lista(theme)),
          _campoEnvio(theme),
        ],
      ),
    );
  }

  Widget _faixa(ThemeData theme, String mensagem) {
    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        mensagem,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }

  Widget _lista(ThemeData theme) {
    if (_carregando && _mensagens.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_mensagens.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Envie a primeira mensagem para começar a conversa.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final itens = <Widget>[];
    DateTime? diaAnterior;
    for (final mensagem in _mensagens) {
      final data = mensagem.criadoEm?.toLocal();
      if (data != null) {
        final dia = DateTime(data.year, data.month, data.day);
        if (diaAnterior == null || !dia.isAtSameMomentAs(diaAnterior)) {
          itens.add(_separadorData(dia, theme));
          diaAnterior = dia;
        }
      }
      itens.add(_bolha(mensagem, theme));
    }

    return Column(
      children: [
        if (_mostrandoCache)
          Container(
            width: double.infinity,
            color: theme.colorScheme.secondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Sem conexão. Mostrando mensagens salvas no aparelho.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            children: itens,
          ),
        ),
      ],
    );
  }

  Widget _separadorData(DateTime dia, ThemeData theme) {
    final hoje = DateTime.now();
    final referencia = DateTime(hoje.year, hoje.month, hoje.day);
    final ontem = referencia.subtract(const Duration(days: 1));

    final String rotulo;
    if (dia.isAtSameMomentAs(referencia)) {
      rotulo = 'Hoje';
    } else if (dia.isAtSameMomentAs(ontem)) {
      rotulo = 'Ontem';
    } else {
      rotulo = _capitalizar(
        DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(dia),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: theme.colorScheme.bordaSutil)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              rotulo,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: theme.colorScheme.bordaSutil)),
        ],
      ),
    );
  }

  String _capitalizar(String texto) {
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1);
  }

  Widget _bolha(Mensagem mensagem, ThemeData theme) {
    final minha = mensagem.ehMinha(_meuId);
    final fundo = minha
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHigh;
    final frente = minha
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
    final raio = Radius.circular(PlacezTokens.raioLg);
    final canto = const Radius.circular(6);
    final larguraMaxima = MediaQuery.sizeOf(context).width * 0.78;

    return Align(
      alignment: minha ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: larguraMaxima.clamp(220, 420)),
        margin: const EdgeInsets.only(bottom: PlacezTokens.espSm),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: fundo,
          borderRadius: BorderRadius.only(
            topLeft: raio,
            topRight: raio,
            bottomLeft: minha ? raio : canto,
            bottomRight: minha ? canto : raio,
          ),
          border: Border.all(
            color: minha
                ? theme.colorScheme.primary.withValues(alpha: 0.18)
                : theme.colorScheme.bordaSutil,
          ),
        ),
        child: Column(
          crossAxisAlignment: minha
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if ((widget.ehEvento || widget.ehGrupo) &&
                !minha &&
                mensagem.autor != null) ...[
              Text(
                mensagem.autor!.nome,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: frente.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              mensagem.texto,
              style: theme.textTheme.bodyMedium?.copyWith(color: frente),
            ),
            const SizedBox(height: 2),
            Text(
              _hora(mensagem.criadoEm),
              style: theme.textTheme.labelSmall?.copyWith(
                color: frente.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoEnvio(ThemeData theme) {
    final habilitado = _podeEnviar && !_bloqueada;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _textoController,
                enabled: habilitado,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Mensagem',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: habilitado && !_enviando ? _enviar : null,
              tooltip: 'Enviar',
              icon: _enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  String _hora(DateTime? data) {
    if (data == null) return '';
    final local = data.toLocal();
    final hora = local.hour.toString().padLeft(2, '0');
    final minuto = local.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }
}
