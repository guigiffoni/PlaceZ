import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/chat/chat_repository.dart';
import '../../core/friends/friends_repository.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/amizade.dart';
import '../../data/models/grupo.dart';
import '../widgets/avatar_usuario.dart';
import '../widgets/placez_componentes.dart';

class TelaGrupo extends StatefulWidget {
  final AuthController authController;
  final int grupoId;
  final String nomeInicial;

  const TelaGrupo({
    super.key,
    required this.authController,
    required this.grupoId,
    required this.nomeInicial,
  });

  @override
  State<TelaGrupo> createState() => _TelaGrupoState();
}

class _TelaGrupoState extends State<TelaGrupo> {
  late final ChatRepository _chatRepository;
  late final FriendsRepository _friendsRepository;

  Grupo? _grupo;
  bool _carregando = true;
  bool _ocupado = false;
  String? _erro;
  int? get _meuId => widget.authController.usuario?.id;

  @override
  void initState() {
    super.initState();
    final auth = widget.authController;
    _chatRepository = ChatRepository(
      tokenProvider: () async => auth.sessao?.token,
      onUnauthorized: auth.tratarNaoAutorizado,
    );
    _friendsRepository = FriendsRepository(
      tokenProvider: () async => auth.sessao?.token,
      onUnauthorized: auth.tratarNaoAutorizado,
    );
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final grupo = await _chatRepository.buscarGrupo(widget.grupoId);
      if (!mounted) return;
      setState(() => _grupo = grupo);
    } on ApiException catch (erro) {
      if (mounted) setState(() => _erro = erro.message);
    } catch (erro) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível carregar o grupo: $erro');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _abrirConvite() async {
    final grupo = _grupo;
    if (grupo == null || _ocupado) return;

    setState(() => _ocupado = true);
    List<Amigo> amigos;
    try {
      amigos = await _friendsRepository.listarAmigos();
    } on ApiException catch (erro) {
      _avisar(erro.message);
      return;
    } catch (erro) {
      _avisar('Não foi possível carregar amigos: $erro');
      return;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
    if (!mounted) return;

    final membros = grupo.membros.map((membro) => membro.usuario.id).toSet();
    final disponiveis = amigos
        .where((amigo) => !membros.contains(amigo.usuario.id))
        .toList();
    if (disponiveis.isEmpty) {
      _avisar('Todos os seus amigos já estão no grupo.');
      return;
    }

    final selecao = <int>{};
    final resultado = await showDialog<Set<int>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Adicionar membros'),
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
                  child: const Text('Adicionar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado == null || resultado.isEmpty || !mounted) return;

    setState(() => _ocupado = true);
    try {
      final atualizado = await _chatRepository.adicionarMembrosGrupo(
        widget.grupoId,
        resultado.toList(),
      );
      if (!mounted) return;
      setState(() => _grupo = atualizado);
      _avisar('Membro(s) adicionado(s).');
    } on ApiException catch (erro) {
      _avisar(erro.message);
    } catch (erro) {
      _avisar('Não foi possível adicionar membros: $erro');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _sair() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair do grupo?'),
        content: const Text(
          'Você deixará de receber as mensagens deste grupo. O histórico '
          'continua para os demais membros.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    setState(() => _ocupado = true);
    try {
      await _chatRepository.sairGrupo(widget.grupoId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (erro) {
      _avisar(erro.message);
    } catch (erro) {
      _avisar('Não foi possível sair do grupo: $erro');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _alternarPermissao(bool valor) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      final atualizado = await _chatRepository.atualizarConfiguracaoGrupo(
        widget.grupoId,
        membrosPodemAdicionar: valor,
      );
      if (!mounted) return;
      setState(() => _grupo = atualizado);
      _avisar(
        valor
            ? 'Agora os membros podem adicionar pessoas.'
            : 'Somente o administrador pode adicionar pessoas.',
      );
    } on ApiException catch (erro) {
      _avisar(erro.message);
    } catch (erro) {
      _avisar('Não foi possível atualizar o grupo: $erro');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _transferirAdministracao(GrupoMembro membro) async {
    if (_ocupado) return;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transferir administração?'),
        content: Text(
          '${membro.usuario.nome} passará a ser o administrador do grupo. '
          'Você continuará como membro comum.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Transferir'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    setState(() => _ocupado = true);
    try {
      final atualizado = await _chatRepository.transferirAdministracao(
        widget.grupoId,
        membro.usuario.id,
      );
      if (!mounted) return;
      setState(() => _grupo = atualizado);
      _avisar('${membro.usuario.nome} agora é administrador.');
    } on ApiException catch (erro) {
      _avisar(erro.message);
    } catch (erro) {
      _avisar('Não foi possível transferir a administração: $erro');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _removerMembro(GrupoMembro membro) async {
    if (_ocupado) return;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover membro?'),
        content: Text(
          '${membro.usuario.nome} deixará de participar do grupo e não verá '
          'mais as mensagens.',
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

    setState(() => _ocupado = true);
    try {
      final atualizado = await _chatRepository.removerMembroGrupo(
        widget.grupoId,
        membro.usuario.id,
      );
      if (!mounted) return;
      setState(() => _grupo = atualizado);
      _avisar('${membro.usuario.nome} foi removido do grupo.');
    } on ApiException catch (erro) {
      _avisar(erro.message);
    } catch (erro) {
      _avisar('Não foi possível remover o membro: $erro');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  String _dataAdicionado(DateTime? data) {
    if (data == null) return 'data desconhecida';
    final local = data.toLocal();
    final dia = local.day.toString().padLeft(2, '0');
    final mes = local.month.toString().padLeft(2, '0');
    return '$dia/$mes/${local.year}';
  }

  void _avisar(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    final grupo = _grupo;
    final ehAdmin = grupo?.souCriador(_meuId) ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(grupo?.nome ?? widget.nomeInicial)),
      body: _carregando && grupo == null
          ? const Center(child: CircularProgressIndicator())
          : _erro != null && grupo == null
          ? Center(
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
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (_ocupado) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                ],
                if (grupo != null && ehAdmin) ...[
                  const TituloSecao('Configurações do grupo'),
                  Card(
                    child: SwitchListTile(
                      value: grupo.membrosPodemAdicionar,
                      onChanged: _ocupado ? null : _alternarPermissao,
                      secondary: const Icon(Icons.person_add_alt_1_outlined),
                      title: const Text('Membros podem adicionar pessoas'),
                      subtitle: const Text(
                        'Qualquer membro pode convidar amigos confirmados.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                TituloSecao('Membros', sufixo: '${grupo?.membros.length ?? 0}'),
                Card(
                  child: Column(
                    children: [
                      for (final membro
                          in grupo?.membros ?? const <GrupoMembro>[])
                        _membroTile(membro, ehAdmin),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (grupo != null && (ehAdmin || grupo.membrosPodemAdicionar))
                  FilledButton.tonalIcon(
                    onPressed: _ocupado ? null : _abrirConvite,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Adicionar membros'),
                  )
                else if (grupo != null)
                  const AvisoPlacez(
                    'Somente o administrador pode adicionar pessoas neste '
                    'grupo.',
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _ocupado ? null : _sair,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair do grupo'),
                ),
              ],
            ),
    );
  }

  Widget _membroTile(GrupoMembro membro, bool ehAdmin) {
    final theme = Theme.of(context);
    final podeGerenciar = ehAdmin && !membro.isCriador;

    return ListTile(
      leading: AvatarUsuario(
        auth: widget.authController,
        usuarioId: membro.usuario.id,
        nome: membro.usuario.nome,
        raio: 20,
      ),
      title: Row(
        children: [
          Expanded(child: Text(membro.usuario.nome)),
          if (membro.isCriador)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Administrador',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        '${membro.usuario.identificador}\n'
        'Adicionado em ${_dataAdicionado(membro.criadoEm)}',
      ),
      isThreeLine: true,
      trailing: podeGerenciar
          ? PopupMenuButton<String>(
              enabled: !_ocupado,
              tooltip: 'Opções do membro',
              onSelected: (valor) {
                if (valor == 'admin') _transferirAdministracao(membro);
                if (valor == 'remover') _removerMembro(membro);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'admin',
                  child: ListTile(
                    leading: Icon(Icons.admin_panel_settings_outlined),
                    title: Text('Tornar administrador'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'remover',
                  child: ListTile(
                    leading: Icon(Icons.person_remove_outlined),
                    title: Text('Remover do grupo'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
