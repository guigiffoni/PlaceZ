import 'package:flutter/material.dart';

import '../core/auth/auth_controller.dart';
import '../core/friends/friends_controller.dart';
import '../data/models/amizade.dart';
import 'telas/login.dart';

class TelaAmigos extends StatefulWidget {
  final AuthController authController;

  const TelaAmigos({super.key, required this.authController});

  @override
  State<TelaAmigos> createState() => _TelaAmigosState();
}

class _TelaAmigosState extends State<TelaAmigos> {
  late final FriendsController _controller;
  final TextEditingController _buscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = FriendsController(auth: widget.authController);
    widget.authController.addListener(_aoMudarConta);
  }

  @override
  void dispose() {
    widget.authController.removeListener(_aoMudarConta);
    _controller.dispose();
    _buscaController.dispose();
    super.dispose();
  }

  void _aoMudarConta() {
    // Evita levar a busca de uma conta para a próxima após login/logout.
    _buscaController.clear();
    _controller.limparBusca();
  }

  Future<void> _abrirLogin() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => TelaLogin(
          authController: widget.authController,
          motivo: 'Entre para ver e adicionar amigos.',
        ),
      ),
    );
  }

  Future<void> _buscar() async {
    FocusScope.of(context).unfocus();
    await _controller.buscar(_buscaController.text);
  }

  Future<void> _adicionar(String username) async {
    if (_controller.acaoEmAndamento) return;
    final erro = await _controller.enviarSolicitacao(username);
    if (!mounted) return;
    _avisar(erro ?? 'Solicitação enviada.');
  }

  Future<void> _aceitar(int id) async {
    if (_controller.acaoEmAndamento) return;
    final erro = await _controller.aceitar(id);
    if (!mounted) return;
    _avisar(erro ?? 'Solicitação aceita.');
  }

  Future<void> _recusar(int id) async {
    if (_controller.acaoEmAndamento) return;
    final erro = await _controller.recusar(id);
    if (!mounted) return;
    _avisar(erro ?? 'Solicitação recusada.');
  }

  Future<void> _cancelar(int id) async {
    if (_controller.acaoEmAndamento) return;
    final erro = await _controller.cancelar(id);
    if (!mounted) return;
    _avisar(erro ?? 'Solicitação cancelada.');
  }

  Future<void> _remover(UsuarioResumo usuario) async {
    final confirmou = await _confirmar(
      titulo: 'Remover amigo?',
      mensagem: 'Remover ${usuario.nome} da sua lista de amigos?',
      rotulo: 'Remover',
    );
    if (confirmou != true || !mounted) return;

    final erro = await _controller.remover(usuario.id);
    if (!mounted) return;
    _avisar(erro ?? 'Amizade removida.');
  }

  Future<void> _bloquear(UsuarioResumo usuario) async {
    final confirmou = await _confirmar(
      titulo: 'Bloquear usuário?',
      mensagem:
          'Bloquear ${usuario.nome}? A amizade e qualquer solicitação entre '
          'vocês serão removidas. A pessoa não poderá enviar novas '
          'solicitações nem conversar com você.',
      rotulo: 'Bloquear',
    );
    if (confirmou != true || !mounted) return;

    final erro = await _controller.bloquear(usuario.id);
    if (!mounted) return;
    _avisar(erro ?? 'Usuário bloqueado.');
  }

  Future<void> _desbloquear(UsuarioResumo usuario) async {
    if (_controller.acaoEmAndamento) return;
    final erro = await _controller.desbloquear(usuario.id);
    if (!mounted) return;
    _avisar(erro ?? 'Usuário desbloqueado.');
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
              child: const Text('Cancelar'),
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Amigos')),
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
    final carregandoInicial =
        _controller.carregando &&
        _controller.amigos.isEmpty &&
        _controller.recebidas.isEmpty &&
        _controller.enviadas.isEmpty;

    if (carregandoInicial) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _controller.carregar(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _campoBusca(),
          if (_controller.buscando) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (_controller.erroBusca != null) ...[
            const SizedBox(height: 10),
            _Aviso(mensagem: _controller.erroBusca!, erro: true),
          ],
          if (_controller.erro != null) ...[
            const SizedBox(height: 10),
            _Aviso(
              mensagem: _controller.erro!,
              erro: true,
              onFechar: _controller.limparErro,
            ),
          ],
          if (_controller.mostrandoCache) ...[
            const SizedBox(height: 10),
            const _Aviso(
              mensagem:
                  'Sem conexão com a API. Mostrando dados salvos no aparelho.',
            ),
          ],
          if (_controller.resultados.isNotEmpty) ...[
            const SizedBox(height: 18),
            _tituloSecao('Resultados da busca'),
            _cartao(_controller.resultados.map(_resultadoTile).toList()),
          ] else if (_controller.termoBusca != null &&
              _controller.termoBusca!.trim().length >= 2 &&
              !_controller.buscando &&
              _controller.erroBusca == null) ...[
            const SizedBox(height: 10),
            _Aviso(
              mensagem:
                  'Nenhum usuário encontrado para "${_controller.termoBusca}".',
            ),
          ],
          if (_controller.recebidas.isNotEmpty) ...[
            const SizedBox(height: 18),
            _tituloSecao('Solicitações recebidas'),
            _cartao(_controller.recebidas.map(_recebidaTile).toList()),
          ],
          if (_controller.enviadas.isNotEmpty) ...[
            const SizedBox(height: 18),
            _tituloSecao('Solicitações enviadas'),
            _cartao(_controller.enviadas.map(_enviadaTile).toList()),
          ],
          const SizedBox(height: 18),
          _tituloSecao(
            'Seus amigos',
            sufixo: _controller.amigos.isEmpty
                ? null
                : '${_controller.amigos.length}',
          ),
          if (_controller.amigos.isEmpty)
            const _EstadoVazio(
              icone: Icons.group_outlined,
              titulo: 'Você ainda não tem amigos.',
              descricao:
                  'Busque por um username acima e envie uma solicitação.',
            )
          else
            _cartao(_controller.amigos.map(_amigoTile).toList()),
          if (_controller.bloqueios.isNotEmpty) ...[
            const SizedBox(height: 18),
            _tituloSecao('Bloqueados'),
            _cartao(_controller.bloqueios.map(_bloqueadoTile).toList()),
          ],
        ],
      ),
    );
  }

  Widget _campoBusca() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _buscaController,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            onSubmitted: (_) => _buscar(),
            onChanged: (valor) {
              if (valor.trim().isEmpty) _controller.limparBusca();
            },
            decoration: InputDecoration(
              hintText: 'Buscar por @username',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _buscaController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      onPressed: () {
                        _buscaController.clear();
                        _controller.limparBusca();
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _controller.buscando ? null : _buscar,
          tooltip: 'Buscar',
          icon: const Icon(Icons.search),
        ),
      ],
    );
  }

  Widget _tituloSecao(String texto, {String? sufixo}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (sufixo != null)
            Text(
              sufixo,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _cartao(List<Widget> filhos) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(children: filhos),
    );
  }

  Widget _resultadoTile(ResultadoBuscaUsuario resultado) {
    return ListTile(
      leading: _avatar(resultado.usuario),
      title: Text(resultado.usuario.nome),
      subtitle: Text(resultado.usuario.identificador),
      trailing: _acaoResultado(resultado),
    );
  }

  Widget _acaoResultado(ResultadoBuscaUsuario resultado) {
    switch (resultado.relacao) {
      case RelacaoUsuario.nenhuma:
        return FilledButton.tonal(
          onPressed: _controller.acaoEmAndamento
              ? null
              : () => _adicionar(resultado.usuario.username),
          child: const Text('Adicionar'),
        );
      case RelacaoUsuario.solicitacaoEnviada:
        return TextButton(
          onPressed:
              resultado.solicitacaoId == null || _controller.acaoEmAndamento
              ? null
              : () => _cancelar(resultado.solicitacaoId!),
          child: const Text('Pendente'),
        );
      case RelacaoUsuario.solicitacaoRecebida:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Aceitar',
              onPressed:
                  resultado.solicitacaoId == null || _controller.acaoEmAndamento
                  ? null
                  : () => _aceitar(resultado.solicitacaoId!),
              icon: const Icon(Icons.check_circle_outline),
            ),
            IconButton(
              tooltip: 'Recusar',
              onPressed:
                  resultado.solicitacaoId == null || _controller.acaoEmAndamento
                  ? null
                  : () => _recusar(resultado.solicitacaoId!),
              icon: const Icon(Icons.cancel_outlined),
            ),
          ],
        );
      case RelacaoUsuario.amigos:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            const Text('Amigos'),
          ],
        );
    }
  }

  Widget _recebidaTile(SolicitacaoAmizade solicitacao) {
    return ListTile(
      leading: _avatar(solicitacao.usuario),
      title: Text(solicitacao.usuario.nome),
      subtitle: Text(
        '${solicitacao.usuario.identificador} quer adicionar você',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Aceitar',
            onPressed: _controller.acaoEmAndamento
                ? null
                : () => _aceitar(solicitacao.id),
            icon: const Icon(Icons.check_circle_outline),
          ),
          IconButton(
            tooltip: 'Recusar',
            onPressed: _controller.acaoEmAndamento
                ? null
                : () => _recusar(solicitacao.id),
            icon: const Icon(Icons.cancel_outlined),
          ),
        ],
      ),
    );
  }

  Widget _enviadaTile(SolicitacaoAmizade solicitacao) {
    return ListTile(
      leading: _avatar(solicitacao.usuario),
      title: Text(solicitacao.usuario.nome),
      subtitle: Text(
        '${solicitacao.usuario.identificador} · aguardando resposta',
      ),
      trailing: TextButton(
        onPressed: _controller.acaoEmAndamento
            ? null
            : () => _cancelar(solicitacao.id),
        child: const Text('Cancelar'),
      ),
    );
  }

  Widget _amigoTile(Amigo amigo) {
    return ListTile(
      leading: _avatar(amigo.usuario),
      title: Text(amigo.usuario.nome),
      subtitle: Text(amigo.usuario.identificador),
      trailing: PopupMenuButton<String>(
        enabled: !_controller.acaoEmAndamento,
        tooltip: 'Opções',
        onSelected: (valor) {
          if (valor == 'remover') _remover(amigo.usuario);
          if (valor == 'bloquear') _bloquear(amigo.usuario);
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'remover',
            child: ListTile(
              leading: Icon(Icons.person_remove_outlined),
              title: Text('Remover amigo'),
            ),
          ),
          PopupMenuItem(
            value: 'bloquear',
            child: ListTile(
              leading: Icon(Icons.block),
              title: Text('Bloquear'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bloqueadoTile(Bloqueio bloqueio) {
    return ListTile(
      leading: _avatar(bloqueio.usuario),
      title: Text(bloqueio.usuario.nome),
      subtitle: Text(bloqueio.usuario.identificador),
      trailing: TextButton(
        onPressed: _controller.acaoEmAndamento
            ? null
            : () => _desbloquear(bloqueio.usuario),
        child: const Text('Desbloquear'),
      ),
    );
  }

  Widget _avatar(UsuarioResumo usuario) {
    return CircleAvatar(child: Text(usuario.iniciais));
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.group_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Entre para ver seus amigos',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Busque pessoas pelo username, envie solicitações e organize '
                'seus encontros com quem você conhece.',
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
  final IconData icone;
  final String titulo;
  final String descricao;

  const _EstadoVazio({
    required this.icone,
    required this.titulo,
    required this.descricao,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Icon(icone, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            descricao,
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
