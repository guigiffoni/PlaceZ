import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/auth/auth_controller.dart';
import 'core/events/events_controller.dart';
import 'core/notificacoes/notificacao_service.dart';
import 'data/models/evento.dart';
import 'data/models/local.dart';
import 'tema.dart';
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
  await initializeDateFormatting('pt_BR');

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
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: _temaController.modoTema,
          theme: construirTema(
            seed: _temaController.seedCor,
            brightness: Brightness.light,
          ),
          darkTheme: construirTema(
            seed: _temaController.seedCor,
            brightness: Brightness.dark,
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
  bool _selecionandoLocal = false;

  late final EventsController _eventsController;
  final GlobalKey<TelaCadastroEventoState> _cadastroKey =
      GlobalKey<TelaCadastroEventoState>();
  final GlobalKey<TelaCalendarioState> _calendarKey =
      GlobalKey<TelaCalendarioState>();

  static const MethodChannel _canalApp = MethodChannel(
    'br.pucminas.placez/app',
  );

  static const int _abaChat = 1;
  static const int _abaNovoEvento = 2;
  static const int _abaPesquisa = 3;

  static const List<String> _titulos = [
    'PlaceZ',
    'Conversas',
    'Novo evento',
    'Pesquisar lugares',
    'Amigos',
  ];

  @override
  void initState() {
    super.initState();
    _eventsController = EventsController(auth: widget.authController);
    widget.authController.addListener(_aoMudarAutenticacao);
  }

  void _aoMudarAutenticacao() {
    if (widget.authController.autenticado) return;
    if (!mounted) return;
    final eraSelecao = _selecionandoLocal;
    setState(() {
      _selecionandoLocal = false;
      final protegida =
          _currentPageIndex == _abaChat || _currentPageIndex == _abaNovoEvento;
      // Logout ou 401: não deixa a aba protegida ou a seleção abertas.
      if (protegida || eraSelecao) _currentPageIndex = 0;
    });
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

  void _abrirCatalogoParaEvento() {
    setState(() {
      _selecionandoLocal = true;
      _currentPageIndex = _abaPesquisa;
    });
  }

  void _selecionarLocalParaEvento(Local local) {
    _cadastroKey.currentState?.definirLocalSelecionado(local);
    setState(() {
      _selecionandoLocal = false;
      _currentPageIndex = _abaNovoEvento;
    });
  }

  void _cancelarSelecao() {
    setState(() {
      _selecionandoLocal = false;
      _currentPageIndex = _abaNovoEvento;
    });
  }

  void _eventoCriado(Evento evento) {
    final data = evento.inicioEm?.toLocal() ?? DateTime.now();
    setState(() {
      _selecionandoLocal = false;
      _currentPageIndex = 0;
    });
    _calendarKey.currentState?.selecionarDia(data);
    _eventsController.atualizarCalendario();
  }

  Future<void> _minimizarApp() async {
    try {
      await _canalApp.invokeMethod<void>('minimize');
    } on MissingPluginException {
      await SystemNavigator.pop();
    } catch (_) {
      await SystemNavigator.pop();
    }
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
    setState(() {
      if (indice != _abaPesquisa) _selecionandoLocal = false;
      _currentPageIndex = indice;
    });

    // Ao voltar para o calendário, atualiza eventos e ranking sem exigir
    // reinício do app (inclusive após criar/editar um evento).
    if (indice == 0 && widget.authController.autenticado) {
      _eventsController.atualizarCalendario();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentPageIndex != 0 || _selecionandoLocal) {
          setState(() {
            _selecionandoLocal = false;
            _currentPageIndex = 0;
          });
          return;
        }
        await _minimizarApp();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _selecionandoLocal ? 'Escolher local' : _titulos[_currentPageIndex],
          ),
          actions: _selecionandoLocal
              ? [
                  IconButton(
                    tooltip: 'Cancelar seleção',
                    onPressed: _cancelarSelecao,
                    icon: const Icon(Icons.close),
                  ),
                ]
              : [
                  IconButton(
                    tooltip: 'Configurações',
                    onPressed: () {
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
                    icon: const Icon(Icons.settings_outlined),
                  ),
                  IconButton(
                    tooltip: 'Sobre o PlaceZ',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TelaSobre(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.info_outline),
                  ),
                ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: Container(
              height: 3,
              decoration: BoxDecoration(gradient: scheme.gradienteMarca),
            ),
          ),
        ),

        body: IndexedStack(
          index: _currentPageIndex,
          children: [
            TelaCalendario(
              key: _calendarKey,
              eventsController: _eventsController,
            ),
            TelaChat(
              authController: widget.authController,
              ativo: _currentPageIndex == _abaChat,
            ),
            TelaCadastroEvento(
              key: _cadastroKey,
              eventsController: _eventsController,
              mostrarAppBar: false,
              onBuscarNoCatalogo: _abrirCatalogoParaEvento,
              onEventoCriado: _eventoCriado,
            ),
            TelaPesquisa(
              authController: widget.authController,
              modoSelecao: _selecionandoLocal,
              onSelecionar: _selecionarLocalParaEvento,
            ),
            TelaAmigos(authController: widget.authController),
          ],
        ),

        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentPageIndex,
          onDestinationSelected: _selecionarAba,
          destinations: [
            NavigationDestination(
              icon: Icon(
                Icons.calendar_month_outlined,
                color: scheme.acentoTeal.frente,
              ),
              selectedIcon: Icon(Icons.calendar_month, color: scheme.primary),
              label: 'Agenda',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.chat_bubble_outline,
                color: scheme.acentoAmbar.frente,
              ),
              selectedIcon: Icon(Icons.chat_bubble, color: scheme.primary),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.add_circle_outline,
                color: scheme.acentoRosa.frente,
              ),
              selectedIcon: Icon(Icons.add_circle, color: scheme.primary),
              label: 'Novo',
            ),
            NavigationDestination(
              icon: Icon(Icons.search, color: scheme.acentoRoxo.frente),
              selectedIcon: Icon(Icons.saved_search, color: scheme.primary),
              label: 'Buscar',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline, color: scheme.acentoAzul.frente),
              selectedIcon: Icon(Icons.people, color: scheme.primary),
              label: 'Amigos',
            ),
          ],
        ),
      ),
    );
  }
}

// adicionar o github das pessoas que participaram do projeto
// ajustar a logo na tela de cadastro e sobre
// MIT License tem que abrir a licença
// adicionar botões de termo de uso e política de privacidade
