import 'package:flutter/material.dart';

import '../core/auth/auth_controller.dart';
import '../core/chat/conversas_controller.dart';
import '../data/models/conversa.dart';
import 'telas/conversa.dart';
import 'telas/login.dart';

class TelaChat extends StatefulWidget {
  final AuthController authController;

  const TelaChat({super.key, required this.authController});

  @override
  State<TelaChat> createState() => _TelaChatState();
}

class _TelaChatState extends State<TelaChat> with WidgetsBindingObserver {
  late final ConversasController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConversasController(auth: widget.authController);
    WidgetsBinding.instance.addObserver(this);
    _controller.iniciarPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      _controller.iniciarPolling();
      _controller.carregar(silencioso: true);
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
        ),
      ),
    );
    if (mounted) _controller.carregar(silencioso: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversas')),
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

    if (semDados) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _controller.carregar(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
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
              mensagem: 'Sem conexão com a API. Mostrando as conversas salvas no aparelho.',
            ),
            const SizedBox(height: 12),
          ],
          if (_controller.conversas.isEmpty)
            const _EstadoVazio()
          else
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: theme.colorScheme.surfaceContainerLow,
              child: Column(
                children: _controller.conversas
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
    final previa = ultima == null
        ? (ehEvento ? 'Chat do evento' : 'Nenhuma mensagem ainda')
        : '${minha ? 'Você: ' : ''}${ultima.texto}';

    return ListTile(
      leading: ehEvento
          ? const CircleAvatar(child: Icon(Icons.groups))
          : CircleAvatar(child: Text(conversa.iniciais)),
      title: Row(
        children: [
          Expanded(child: Text(conversa.nome)),
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
      trailing: Text(
        _rotuloData(ultima?.criadoEm ?? conversa.atualizadoEm),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
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
                color: theme.colorScheme.primary,
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
            color: theme.colorScheme.outline,
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
