import 'package:flutter/material.dart';

import 'core/auth/auth_controller.dart';
import 'core/events/events_controller.dart';
import 'core/notificacoes/notificacao_service.dart';
import 'ui/calendario.dart';
import 'ui/pesquisa.dart';
import 'ui/telas/cadastro.dart';
import 'ui/chat.dart';
import 'ui/sobre.dart';
import 'ui/contatos.dart';

import 'tema_controller.dart';
import 'ui/telas/configuracoes.dart';
import 'ui/telas/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carrega a sessão antes do primeiro frame para que o app já abra no
  // calendário sabendo se há usuário autenticado.
  final authController = AuthController();
  await authController.inicializar();

  // Fase 8 em modo no-op. A factory pode ser trocada por uma implementação
  // FCM sem alterar as telas.
  final notificacoes = criarNotificacaoService();
  await notificacoes.inicializar();

  runApp(MainApp(authController: authController, notificacoes: notificacoes));
}

class MainApp extends StatefulWidget {
  final AuthController authController;
  final NotificacaoService notificacoes;

  const MainApp({
    super.key,
    required this.authController,
    required this.notificacoes,
  });

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final TemaController _temaController = TemaController();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    _temaController.carregaPreferencias();
    widget.authController.addListener(_aoMudarAutenticacao);
  }

  void _aoMudarAutenticacao() {
    // Se a sessão cair (logout ou 401), fecha telas empilhadas e volta ao
    // calendário. O login só é pedido quando o usuário tenta uma ação
    // protegida.
    if (widget.authController.status == AuthStatus.naoAutenticado) {
      _navigatorKey.currentState?.popUntil((rota) => rota.isFirst);
    }
  }

  @override
  void dispose() {
    widget.authController.removeListener(_aoMudarAutenticacao);
    widget.authController.dispose();
    _temaController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _temaController,
      builder: (context, cuild) {
        return MaterialApp(
          title: "PlaceZ",
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          themeMode: _temaController.modoTema,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: _temaController.seedCor,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: _temaController.seedCor,
              brightness: Brightness.dark,
            ),
          ),
          home: BarraNavegacao(
            temaController: _temaController,
            authController: widget.authController,
          ),
        );
      },
    );
  }
}

class BarraNavegacao extends StatefulWidget {
  final TemaController temaController;
  final AuthController authController;

  const BarraNavegacao({
    super.key,
    required this.temaController,
    required this.authController,
  });

  @override
  State<BarraNavegacao> createState() => _BarraNavegacaoState();
}

class _BarraNavegacaoState extends State<BarraNavegacao> {
  int _currentPageIndex = 0;

  late final EventsController _eventsController;
  late final List<Widget> _widgetOptions;

  static const int _abaChat = 1;
  static const int _abaNovoEvento = 2;

  @override
  void initState() {
    super.initState();
    _eventsController = EventsController(auth: widget.authController);
    _widgetOptions = [
      TelaCalendario(eventsController: _eventsController),
      TelaChat(authController: widget.authController),
      TelaCadastroEvento(eventsController: _eventsController),
      const TelaPesquisa(),
      TelaAmigos(authController: widget.authController),
    ];
    widget.authController.addListener(_aoMudarAutenticacao);
  }

  void _aoMudarAutenticacao() {
    final protegida =
        _currentPageIndex == _abaChat || _currentPageIndex == _abaNovoEvento;
    if (!protegida || widget.authController.autenticado) return;
    if (!mounted) return;
    // Logout ou 401: não deixa a aba protegida aberta.
    setState(() => _currentPageIndex = 0);
  }

  @override
  void dispose() {
    widget.authController.removeListener(_aoMudarAutenticacao);
    _eventsController.dispose();
    super.dispose();
  }

  Future<bool> _pedirLogin(String motivo) async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            TelaLogin(authController: widget.authController, motivo: motivo),
      ),
    );
    return resultado == true && widget.authController.autenticado;
  }

  Future<void> _selecionarAba(int indice) async {
    final protegida = indice == _abaChat || indice == _abaNovoEvento;

    if (protegida && !widget.authController.autenticado) {
      final motivo = indice == _abaChat
          ? 'Entre para conversar no chat.'
          : 'Entre para criar um evento.';
      final autenticou = await _pedirLogin(motivo);
      if (!autenticou || !mounted) return;
    }

    if (!mounted) return;
    setState(() => _currentPageIndex = indice);

    // Ao voltar para o calendário, atualiza eventos e ranking sem exigir
    // reinício do app (inclusive após criar/editar um evento).
    if (indice == 0 && widget.authController.autenticado) {
      _eventsController.atualizarCalendario();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PlaceZ"),
        actions: [
          IconButton(
            onPressed: () {
              // 👈 NOVO BOTÃO
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TelaConfiguracoes(
                    temaController: widget.temaController,
                    authController: widget.authController,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TelaSobre()),
              );
            },
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),

      body: _widgetOptions[_currentPageIndex],

      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        selectedIndex: _currentPageIndex,
        onDestinationSelected: _selecionarAba,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: "Calendário",
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: "Chat",
          ),
          NavigationDestination(
            icon: Icon(Icons.add),
            label: "Adicionar evento",
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: "Pesquisar lugares",
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: "Amigos",
          ),
        ],
      ),
    );
  }
}

// adicionar o github das pessoas que participaram do projeto
// ajustar a logo na tela de cadastro e sobre
// MIT License tem que abrir a licença
// adicionar botões de termo de uso e política de privacidade
