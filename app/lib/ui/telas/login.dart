import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_exception.dart';
import '../widgets/diagnostico_api.dart';
import 'politica_privacidade.dart';
import 'termos_uso.dart';

class TelaLogin extends StatefulWidget {
  final AuthController authController;
  final String? motivo;

  const TelaLogin({super.key, required this.authController, this.motivo});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmacaoController = TextEditingController();

  bool _criandoConta = false;
  bool _enviando = false;
  bool _senhaVisivel = false;
  String? _erro;

  @override
  void dispose() {
    _nomeController.dispose();
    _usernameController.dispose();
    _senhaController.dispose();
    _confirmacaoController.dispose();
    super.dispose();
  }

  void _alternarModo(bool criandoConta) {
    if (_criandoConta == criandoConta) return;
    setState(() {
      _criandoConta = criandoConta;
      _erro = null;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _enviando = true;
      _erro = null;
    });

    try {
      if (_criandoConta) {
        await widget.authController.registrar(
          nome: _nomeController.text,
          username: _usernameController.text,
          senha: _senhaController.text,
        );
      } else {
        await widget.authController.entrar(
          username: _usernameController.text,
          senha: _senhaController.text,
        );
      }

      // A tela de login é aberta apenas quando uma ação protegida exige
      // autenticação; ao concluir, devolve o controle para a ação original.
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop(true);
      }
    } on ApiException catch (erro) {
      if (mounted) setState(() => _erro = _mensagemDoErro(erro));
    } catch (erro) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível concluir: $erro');
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String _mensagemDoErro(ApiException erro) {
    final detalhes = erro.details;
    if (detalhes is List && detalhes.isNotEmpty) {
      final itens = detalhes
          .map((item) {
            if (item is Map) {
              final campo = item['campo']?.toString();
              final mensagem = item['mensagem']?.toString() ?? item.toString();
              return campo == null || campo.isEmpty
                  ? mensagem
                  : '$campo: $mensagem';
            }
            return item.toString();
          })
          .join('\n');
      return '${erro.message}\n$itens';
    }

    switch (erro.code) {
      case 'BANCO_INDISPONIVEL':
        return 'A API está no ar, mas o banco Oracle está indisponível. '
            'Tente novamente mais tarde.';
      case 'AUTENTICACAO_INDISPONIVEL':
        return 'O servidor não conseguiu validar a senha. '
            'Verifique a instalação do backend.';
      case 'REDE':
      case 'TIMEOUT':
        return '${erro.message} '
            'Se estiver testando sem servidor, use o modo Mock.';
    }
    return erro.message;
  }

  Future<void> _abrirConexao() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Conexão com a API'),
          content: const SingleChildScrollView(child: DiagnosticoApi()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  String? _validaUsername(String? valor) {
    final username = (valor ?? '').trim();
    if (username.isEmpty) return 'Informe o username.';
    if (_criandoConta &&
        !RegExp(r'^[a-zA-Z0-9._-]{3,40}$').hasMatch(username)) {
      return 'Use de 3 a 40 caracteres: letras, números, ponto, hífen ou sublinhado.';
    }
    return null;
  }

  String? _validaSenha(String? valor) {
    final senha = valor ?? '';
    if (senha.isEmpty) return 'Informe a senha.';
    if (_criandoConta && (senha.length < 6 || senha.length > 72)) {
      return 'A senha deve ter entre 6 e 72 caracteres.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aviso = widget.authController.aviso;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.place, size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  Text(
                    'PlaceZ',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    'Organize encontros sem complicação.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (widget.motivo != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.motivo!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (aviso != null) ...[
                    _Aviso(
                      mensagem: aviso,
                      onFechar: widget.authController.limparAviso,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Entrar'),
                                icon: Icon(Icons.login),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Criar conta'),
                                icon: Icon(Icons.person_add_alt),
                              ),
                            ],
                            selected: {_criandoConta},
                            onSelectionChanged: (selecao) =>
                                _alternarModo(selecao.first),
                          ),
                          const SizedBox(height: 20),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                if (_criandoConta) ...[
                                  TextFormField(
                                    controller: _nomeController,
                                    textInputAction: TextInputAction.next,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    enabled: !_enviando,
                                    decoration: const InputDecoration(
                                      labelText: 'Nome',
                                      prefixIcon: Icon(Icons.badge_outlined),
                                    ),
                                    validator: (valor) {
                                      final nome = (valor ?? '').trim();
                                      if (nome.length < 2 ||
                                          nome.length > 120) {
                                        return 'Informe um nome entre 2 e 120 caracteres.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                TextFormField(
                                  controller: _usernameController,
                                  textInputAction: TextInputAction.next,
                                  keyboardType: TextInputType.text,
                                  autocorrect: false,
                                  enabled: !_enviando,
                                  decoration: const InputDecoration(
                                    labelText: 'Username',
                                    prefixIcon: Icon(Icons.alternate_email),
                                  ),
                                  validator: _validaUsername,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _senhaController,
                                  obscureText: !_senhaVisivel,
                                  textInputAction: _criandoConta
                                      ? TextInputAction.next
                                      : TextInputAction.done,
                                  enabled: !_enviando,
                                  onFieldSubmitted: (_) {
                                    if (!_criandoConta) _enviar();
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Senha',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: _senhaVisivel
                                          ? 'Ocultar senha'
                                          : 'Mostrar senha',
                                      onPressed: () => setState(
                                        () => _senhaVisivel = !_senhaVisivel,
                                      ),
                                      icon: Icon(
                                        _senhaVisivel
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                    ),
                                  ),
                                  validator: _validaSenha,
                                ),
                                if (_criandoConta) ...[
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _confirmacaoController,
                                    obscureText: !_senhaVisivel,
                                    textInputAction: TextInputAction.done,
                                    enabled: !_enviando,
                                    onFieldSubmitted: (_) => _enviar(),
                                    decoration: const InputDecoration(
                                      labelText: 'Confirmar senha',
                                      prefixIcon: Icon(Icons.lock_reset),
                                    ),
                                    validator: (valor) {
                                      if ((valor ?? '') !=
                                          _senhaController.text) {
                                        return 'As senhas não coincidem.';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_erro != null) ...[
                            const SizedBox(height: 16),
                            _Aviso(
                              mensagem: _erro!,
                              erro: true,
                              onFechar: () => setState(() => _erro = null),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _enviando ? null : _enviar,
                            icon: _enviando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _criandoConta
                                        ? Icons.person_add
                                        : Icons.login,
                                  ),
                            label: Text(
                              _enviando
                                  ? 'Aguarde...'
                                  : _criandoConta
                                  ? 'Criar conta'
                                  : 'Entrar',
                            ),
                          ),
                          if (_criandoConta) ...[
                            const SizedBox(height: 14),
                            const _AceiteTermos(),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _enviando ? null : _abrirConexao,
                    icon: const Icon(Icons.wifi_tethering, size: 18),
                    label: const Text('Configurar conexão'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String mensagem;
  final VoidCallback onFechar;
  final bool erro;

  const _Aviso({
    required this.mensagem,
    required this.onFechar,
    this.erro = false,
  });

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
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
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

class _AceiteTermos extends StatelessWidget {
  const _AceiteTermos();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final link = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    Widget linkWidget(String texto, Widget pagina) {
      return GestureDetector(
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (context) => pagina)),
        child: Text(texto, style: link),
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Ao criar sua conta, você concorda com os '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: linkWidget('Termos de Uso', const TelaTermosUso()),
          ),
          const TextSpan(text: ' e a '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: linkWidget(
              'Política de Privacidade',
              const TelaPoliticaPrivacidade(),
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.45,
      ),
    );
  }
}
