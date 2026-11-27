import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/chat/chat_repository.dart';
import '../../core/friends/friends_repository.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/amizade.dart';

class TelaCriarGrupo extends StatefulWidget {
  final AuthController authController;

  const TelaCriarGrupo({super.key, required this.authController});

  @override
  State<TelaCriarGrupo> createState() => _TelaCriarGrupoState();
}

class _TelaCriarGrupoState extends State<TelaCriarGrupo> {
  final TextEditingController _nomeController = TextEditingController();

  late final ChatRepository _chatRepository;
  late final FriendsRepository _friendsRepository;

  List<Amigo> _amigos = const [];
  final Set<int> _selecionados = <int>{};
  bool _carregandoAmigos = true;
  bool _criando = false;
  String? _erroAmigos;
  String? _erro;

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
    _carregarAmigos();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _carregarAmigos() async {
    setState(() {
      _carregandoAmigos = true;
      _erroAmigos = null;
    });
    try {
      final amigos = await _friendsRepository.listarAmigos();
      if (!mounted) return;
      setState(() {
        _amigos = amigos;
        _selecionados.removeWhere(
          (id) => !amigos.any((amigo) => amigo.usuario.id == id),
        );
      });
    } on ApiException catch (erro) {
      if (mounted) setState(() => _erroAmigos = erro.message);
    } catch (erro) {
      if (mounted) {
        setState(() => _erroAmigos = 'Não foi possível carregar amigos: $erro');
      }
    } finally {
      if (mounted) setState(() => _carregandoAmigos = false);
    }
  }

  Future<void> _criar() async {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = 'Informe o nome do grupo.');
      return;
    }
    if (_selecionados.isEmpty) {
      setState(() => _erro = 'Selecione ao menos um amigo.');
      return;
    }

    setState(() {
      _criando = true;
      _erro = null;
    });

    try {
      final criado = await _chatRepository.criarGrupo(
        nome,
        _selecionados.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(criado);
    } on ApiException catch (erro) {
      if (mounted) setState(() => _erro = erro.message);
    } catch (erro) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível criar o grupo: $erro');
      }
    } finally {
      if (mounted) setState(() => _criando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Novo grupo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nomeController,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Nome do grupo *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Membros',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (_carregandoAmigos)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_erroAmigos != null) ...[
            Text(
              _erroAmigos!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            TextButton(
              onPressed: _carregarAmigos,
              child: const Text('Tentar novamente'),
            ),
          ] else if (_amigos.isEmpty)
            Text(
              'Você ainda não tem amigos para adicionar. Adicione amigos na '
              'aba Amigos e volte aqui.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final amigo in _amigos)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _selecionados.contains(amigo.usuario.id),
                title: Text(amigo.usuario.nome),
                subtitle: Text(amigo.usuario.identificador),
                onChanged: (valor) {
                  setState(() {
                    if (valor == true) {
                      _selecionados.add(amigo.usuario.id);
                    } else {
                      _selecionados.remove(amigo.usuario.id);
                    }
                  });
                },
              ),
          if (_erro != null) ...[
            const SizedBox(height: 10),
            Text(
              _erro!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _criando ? null : _criar,
            icon: _criando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.group_add),
            label: const Text('Criar grupo'),
          ),
        ],
      ),
    );
  }
}
