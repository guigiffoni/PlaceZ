import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/locations/locations_repository.dart';
import '../../data/models/localizacao.dart';
import '../../tema.dart';
import '../../tema_controller.dart'; // Ajuste o caminho conforme seu projeto
import '../widgets/avatar_usuario.dart';
import '../widgets/placez_componentes.dart';
import '../widgets/diagnostico_api.dart';
import 'localizacao_aproximada.dart';
import 'login.dart';

class TelaConfiguracoes extends StatelessWidget {
  final TemaController temaController;
  final AuthController authController;

  const TelaConfiguracoes({
    super.key,
    required this.temaController,
    required this.authController,
  });

  Future<void> _abrirLogin(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => TelaLogin(
          authController: authController,
          motivo: 'Entre para criar eventos e conversar.',
        ),
      ),
    );
  }

  Future<void> _confirmarSaida(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sair da conta?'),
          content: const Text(
            'Sua sessão será encerrada neste aparelho. '
            'Os dados em cache continuam salvos.',
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
        );
      },
    );

    if (confirmar == true) {
      await authController.sair();
    }
  }

  Future<void> _editarPerfil(BuildContext context) async {
    final usuario = authController.usuario;
    if (usuario == null) return;

    final controller = TextEditingController(text: usuario.nome);
    final nome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar perfil'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Nome',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (nome == null || nome.isEmpty || nome == usuario.nome) return;
    final erro = await authController.atualizarPerfil(nome);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(erro ?? 'Perfil atualizado.')));
  }

  Future<void> _alterarFoto(BuildContext context) async {
    final usuario = authController.usuario;
    if (usuario == null) return;

    final opcao = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.of(context).pop('galeria'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.of(context).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remover foto'),
              onTap: () => Navigator.of(context).pop('remover'),
            ),
          ],
        ),
      ),
    );
    if (opcao == null || !context.mounted) return;

    if (opcao == 'remover') {
      final erro = await authController.removerFoto();
      if (!context.mounted) return;
      _avisar(context, erro ?? 'Foto removida.');
      return;
    }

    try {
      final arquivo = await ImagePicker().pickImage(
        source: opcao == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 78,
        requestFullMetadata: false,
      );
      if (arquivo == null || !context.mounted) return;

      final bytes = await arquivo.readAsBytes();
      if (!context.mounted) return;
      if (bytes.length > 512 * 1024) {
        _avisar(context, 'A imagem deve ter no máximo 512 KB.');
        return;
      }

      final nomeArquivo = arquivo.name.toLowerCase();
      final mime =
          arquivo.mimeType ??
          (nomeArquivo.endsWith('.png') ? 'image/png' : 'image/jpeg');
      final erro = await authController.atualizarFoto(
        base64Encode(bytes),
        mime,
      );
      if (!context.mounted) return;
      _avisar(context, erro ?? 'Foto atualizada.');
    } catch (erro) {
      if (context.mounted) {
        _avisar(context, 'Não foi possível selecionar a foto: $erro');
      }
    }
  }

  void _avisar(BuildContext context, String mensagem) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListenableBuilder(
        listenable: Listenable.merge([temaController, authController]),
        builder: (context, child) {
          final usuario = authController.usuario;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              // --- CONTA (Fase 1) ---
              const TituloSecao('Conta'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: usuario == null
                          ? const CircleAvatar(
                              child: Icon(Icons.person_outline),
                            )
                          : AvatarUsuario(
                              auth: authController,
                              usuarioId: usuario.id,
                              nome: usuario.nome,
                              raio: 20,
                              versao: authController.fotoVersao,
                            ),
                      title: Text(usuario?.nome ?? 'Visitante'),
                      subtitle: Text(
                        usuario?.identificador ??
                            'Entre para criar eventos e conversar.',
                      ),
                      trailing: usuario == null
                          ? TextButton.icon(
                              onPressed: () => _abrirLogin(context),
                              icon: const Icon(Icons.login, size: 18),
                              label: const Text('Entrar'),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Editar perfil',
                                  onPressed: () => _editarPerfil(context),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                TextButton.icon(
                                  onPressed: () => _confirmarSaida(context),
                                  icon: const Icon(Icons.logout, size: 18),
                                  label: const Text('Sair'),
                                ),
                              ],
                            ),
                    ),
                    if (usuario != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _alterarFoto(context),
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            size: 18,
                          ),
                          label: const Text('Alterar foto'),
                        ),
                      ),
                  ],
                ),
              ),

              if (usuario != null) ...[
                const SizedBox(height: 8),
                _LocalizacaoTile(authController: authController),
              ],

              const SizedBox(height: PlacezTokens.espXl),

              // --- TEMA (Claro/Escuro/Automático) ---
              const TituloSecao('Modo de tema'),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Claro'),
                    icon: Icon(Icons.light_mode),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Escuro'),
                    icon: Icon(Icons.dark_mode),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Auto'),
                    icon: Icon(Icons.settings_brightness),
                  ),
                ],
                selected: {temaController.modoTema},
                onSelectionChanged: (Set<ThemeMode> newSelection) {
                  temaController.mudaModoTema(newSelection.first);
                },
              ),

              const SizedBox(height: PlacezTokens.espXl),

              // --- COR SEMENTE ---
              const TituloSecao('Cor principal'),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _corOpcao(context, temaController, Colors.deepPurple),
                  _corOpcao(context, temaController, Colors.blue),
                  _corOpcao(context, temaController, Colors.green),
                  _corOpcao(context, temaController, Colors.orangeAccent),
                  _corOpcao(context, temaController, Colors.red.shade500),
                  _corOpcao(context, temaController, Colors.teal),
                ],
              ),

              const SizedBox(height: 32),

              // --- API (Fase 0) ---
              const DiagnosticoApi(),
            ],
          );
        },
      ),
    );
  }

  Widget _corOpcao(BuildContext context, TemaController controller, Color cor) {
    final isSelected = controller.seedCor == cor;
    return GestureDetector(
      onTap: () => controller.mudaSeedCor(cor),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: cor,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 3,
                )
              : null,
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: cor.computeLuminance() > 0.55
                    ? Colors.black
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}

class _LocalizacaoTile extends StatefulWidget {
  final AuthController authController;

  const _LocalizacaoTile({required this.authController});

  @override
  State<_LocalizacaoTile> createState() => _LocalizacaoTileState();
}

class _LocalizacaoTileState extends State<_LocalizacaoTile> {
  late final LocationsRepository _repositorio;
  LocalizacaoUsuario? _localizacao;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    final auth = widget.authController;
    _repositorio = LocationsRepository(
      tokenProvider: () async => auth.sessao?.token,
      onUnauthorized: auth.tratarNaoAutorizado,
    );
    _carregar();
  }

  Future<void> _carregar() async {
    if (mounted) setState(() => _carregando = true);
    try {
      final localizacao = await _repositorio.obterMinhaLocalizacao();
      if (!mounted) return;
      setState(() => _localizacao = localizacao);
    } catch (_) {
      // A localização é opcional; o usuário ainda pode abrir a tela.
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _abrir() async {
    final alterou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            TelaLocalizacaoAproximada(authController: widget.authController),
      ),
    );
    if (alterou == true && mounted) {
      await _carregar();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Localização atualizada.')),
          );
      }
    }
  }

  String get _subtitulo {
    if (_carregando) return 'Carregando...';
    final localizacao = _localizacao;
    if (localizacao == null) return 'Não divulgada';
    return [
      localizacao.origemRotulo,
      localizacao.bairro,
      if (localizacao.cidade != null) localizacao.cidade!,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: const Icon(Icons.location_on_outlined),
        title: const Text('Localização aproximada'),
        subtitle: Text(_subtitulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: _carregando ? null : _abrir,
      ),
    );
  }
}
