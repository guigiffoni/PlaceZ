import 'package:flutter/material.dart';

import '../core/auth/auth_controller.dart';
import '../core/chat/conversas_controller.dart';
import '../data/models/conversa.dart';
import '../data/models/grupo.dart';
import '../tema.dart';
import 'telas/conversa.dart';
import 'telas/criar_grupo.dart';
import 'telas/login.dart';
import 'widgets/avatar_usuario.dart';
import 'widgets/campo_busca.dart';
import 'widgets/placez_componentes.dart';

class TelaChat extends StatefulWidget {
  final AuthController authController;
  final bool ativo;

  const TelaChat({super.key, required this.authController, this.ativo = true});

  @override
  State<TelaChat> createState() => _TelaChatState();
}

class _TelaChatState extends State<TelaChat> with WidgetsBindingObserver {
  late final ConversasController _controller;
  final TextEditingController _buscaController = TextEditingController();
  String _filtro = '';
  late bool _ativo;

  @override
  void initState() {
    super.initState();
    _ativo = widget.ativo;
    _controller = ConversasController(auth: widget.authController);
    WidgetsBinding.instance.addObserver(this);
    if (_ativo) _controller.iniciarPolling();
  }

  @override
  void didUpdateWidget(covariant TelaChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ativo != widget.ativo) {
      _definirAtivo(widget.ativo);
    }
  }

  void _definirAtivo(bool ativo) {
    if (_ativo == ativo) return;
    _ativo = ativo;
    if (ativo) {
      _controller.iniciarPolling();
      _controller.carregar(silencioso: true);
    } else {
      _controller.pararPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _buscaController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      if (_ativo) {
        _controller.iniciarPolling();
        _controller.carregar(silencioso: true);
      }
    } else {
      _controller.pararPolling();
    }
  }

  Future<void> _abrirLogin() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => TelaLogin(
          authController: widget.authController,
          motivo: 'Entre para conversar com seus amigos.',
        ),
      ),
    );
    if (!mounted) return;
    _controller.iniciarPolling();
    _controller.carregar(silencioso: true);
  }

  Future<void> _abrirCriarGrupo() async {
    if (!widget.authController.autenticado) {
      await _abrirLogin();
      return;
    }

    final criado = await Navigator.of(context).push<GrupoCriado>(
      MaterialPageRoute(
        builder: (context) =>
            TelaCriarGrupo(authController: widget.authController),
      ),
    );
    if (criado == null || !mounted) return;

    _controller.carregar(silencioso: true);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TelaConversa(
          authController: widget.authController,
          conversaId: criado.conversa.id,
          titulo: criado.conversa.nome,
          podeEnviarInicial: criado.conversa.podeEnviar,
          bloqueadaInicial: criado.conversa.bloqueada,
          ehGrupo: true,
          grupoId: criado.grupo.id,
        ),
      ),
    );
    if (mounted) _controller.carregar(silencioso: true);
  }

  Future<void> _abrirConversa(Conversa conversa) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TelaConversa(
          authController: widget.authController,
          conversaId: conversa.id,
          titulo: conversa.nome,
          outroUsuarioId: conversa.outroUsuario?.id,
          podeEnviarInicial: conversa.podeEnviar,
          bloqueadaInicial: conversa.bloqueada,
          ehEvento: conversa.tipo == 'EVENTO',
          ehGrupo: conversa.tipo == 'GRUPO',
          grupoId: conversa.grupoId,
        ),
      ),
    );
    if (mounted) _controller.carregar(silencioso: true);
  }

  Future<void> _apagarConversa(Conversa conversa) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar conversa?'),
        content: const Text(
          'Ela será removida da sua lista e do cache do aparelho. Se chegar '
          'uma nova mensagem, a conversa volta a aparecer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    final erro = await _controller.apagarConversa(conversa);
    if (erro != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([widget.authController, _controller]),
        builder: (context, child) {
          if (!widget.authController.autenticado) {
            return _Visitante(onEntrar: _abrirLogin);
          }
          return _conteudo(context);
        },
      ),
    );
  }

  Widget _conteudo(BuildContext context) {
    final theme = Theme.of(context);
    final semDados = _controller.carregando && _controller.conversas.isEmpty;
    final conversas = _filtro.isEmpty
        ? _controller.conversas
        : _controller.conversas
              .where(
                (conversa) => conversa.nome.toLowerCase().contains(_filtro),
              )
              .toList();

    if (semDados) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _controller.carregar(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: TituloSecao(
                  'Suas conversas',
                  sufixo: _controller.conversas.isEmpty
                      ? null
                      : '${_controller.conversas.length}',
                ),
              ),
              TextButton.icon(
                onPressed: _abrirCriarGrupo,
                icon: const Icon(Icons.group_add_outlined, size: 18),
                label: const Text('Novo grupo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CampoBusca(
            controller: _buscaController,
            hintText: 'Pesquisar conversas e grupos',
            helperText: 'A busca filtra nomes de conversas, grupos e eventos.',
            onChanged: (valor) {
              setState(() => _filtro = valor.trim().toLowerCase());
            },
            onClear: () => setState(() => _filtro = ''),
          ),
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
              'Sem conexão com a API. Mostrando as conversas salvas no '
              'aparelho.',
            ),
            const SizedBox(height: 12),
          ],
          if (_controller.conversas.isEmpty)
            const _EstadoVazio()
          else if (conversas.isEmpty)
            EstadoVazio(
              icone: Icons.search_off,
              titulo: 'Nenhuma conversa encontrada',
              descricao: 'Nenhuma conversa corresponde a "$_filtro".',
            )
          else
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: theme.colorScheme.surfaceContainerLow,
              child: Column(
                children: conversas
                    .map((conversa) => _conversaTile(conversa, theme))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _conversaTile(Conversa conversa, ThemeData theme) {
    final ultima = conversa.ultimaMensagem;
    final meuId = widget.authController.usuario?.id;
    final minha = ultima?.autorId != null && ultima!.autorId == meuId;
    final ehEvento = conversa.tipo == 'EVENTO';
    final ehGrupo = conversa.tipo == 'GRUPO';
    final previa = ultima == null
        ? (ehEvento
              ? 'Chat do evento'
              : ehGrupo
              ? 'Grupo'
              : 'Nenhuma mensagem ainda')
        : '${minha ? 'Você: ' : ''}${ultima.texto}';

    return ListTile(
      leading: ehEvento
          ? CircleAvatar(
              backgroundColor: theme.colorScheme.acentoTeal.fundo,
              foregroundColor: theme.colorScheme.acentoTeal.frente,
              child: const Icon(Icons.groups),
            )
          : ehGrupo
          ? CircleAvatar(
              backgroundColor: theme.colorScheme.acentoRoxo.fundo,
              foregroundColor: theme.colorScheme.acentoRoxo.frente,
              child: const Icon(Icons.group),
            )
          : AvatarUsuario(
              auth: widget.authController,
              usuarioId: conversa.outroUsuario?.id ?? 0,
              nome: conversa.nome,
              raio: 20,
            ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversa.nome,
              style: conversa.naoLidas > 0
                  ? theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    )
                  : null,
            ),
          ),
          if (conversa.bloqueada)
            Icon(Icons.lock_outline, size: 16, color: theme.colorScheme.error)
          else if (!conversa.podeEnviar)
            Icon(
              Icons.person_off_outlined,
              size: 16,
              color: theme.colorScheme.outline,
            ),
        ],
      ),
      subtitle: Text(
        previa,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _rotuloData(ultima?.criadoEm ?? conversa.atualizadoEm),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (conversa.naoLidas > 0) ...[
                const SizedBox(height: 4),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    conversa.naoLidas > 99 ? '99+' : '${conversa.naoLidas}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          PopupMenuButton<String>(
            tooltip: 'Opções da conversa',
            padding: EdgeInsets.zero,
            iconSize: 20,
            onSelected: (valor) {
              if (valor == 'apagar') _apagarConversa(conversa);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'apagar',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Apagar conversa'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () => _abrirConversa(conversa),
    );
  }

  String _rotuloData(DateTime? data) {
    if (data == null) return '';
    final local = data.toLocal();
    final agora = DateTime.now();
    if (local.year == agora.year &&
        local.month == agora.month &&
        local.day == agora.day) {
      final hora = local.hour.toString().padLeft(2, '0');
      final minuto = local.minute.toString().padLeft(2, '0');
      return '$hora:$minuto';
    }
    final dia = local.day.toString().padLeft(2, '0');
    final mes = local.month.toString().padLeft(2, '0');
    return '$dia/$mes';
  }
}

class _Visitante extends StatelessWidget {
  final VoidCallback onEntrar;

  const _Visitante({required this.onEntrar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: theme.colorScheme.acentoAmbar.frente,
              ),
              const SizedBox(height: 16),
              Text(
                'Entre para conversar',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Converse com seus amigos confirmados. O histórico fica salvo '
                'no aparelho para consulta offline.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onEntrar,
                icon: const Icon(Icons.login),
                label: const Text('Entrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  const _EstadoVazio();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          Icon(
            Icons.forum_outlined,
            size: 48,
            color: theme.colorScheme.acentoAmbar.frente,
          ),
          const SizedBox(height: 12),
          Text('Nenhuma conversa ainda', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Abra a aba Amigos e toque em um amigo para começar a conversar.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
