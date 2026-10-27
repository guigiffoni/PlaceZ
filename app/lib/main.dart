import 'package:flutter/material.dart';

import 'ui/calendario.dart';
import 'ui/pesquisa.dart';
import 'ui/telas/cadastro.dart';
import 'ui/chat.dart';
import 'ui/evento.dart';
import 'ui/sobre.dart';
import 'ui/contatos.dart';

import 'tema_controller.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final TemaController _temaController = TemaController();

  @override
  void initState() {
    super.initState();

    _temaController.carregaPreferencias();
  }

  @override
  void dispose() {
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
          themeMode: _temaController.modoTema,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: _temaController.seedCor,
              brightness: Brightness.light,
            )
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: _temaController.seedCor,
              brightness: Brightness.dark,
            )
          ),
          home: BarraNavegacao(temaController: _temaController),
        );
      }
    );
  }
}

class BarraNavegacao extends StatefulWidget {
  final TemaController temaController;

  const BarraNavegacao({
    super.key,
    required this.temaController
  });

  @override
  State<BarraNavegacao> createState() => _BarraNavegacaoState();
}

class _BarraNavegacaoState
    extends State<BarraNavegacao> {
  int _currentPageIndex = 0;

  final List<Widget> _widgetOptions = [
    const TelaCalendario(),
    const TelaChat(),
    const TelaCadastroEvento(),
    const TelaPesquisa(),
    const TelaContatos(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PlaceZ"),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TelaSobre(),
                ),
              );
            },
            icon: const Icon(
              Icons.info_outline,
            ),
          ),
        ],
      ),

      body: _widgetOptions[_currentPageIndex],

      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        selectedIndex: _currentPageIndex,
        onDestinationSelected: (int value) {
          setState(() {
            _currentPageIndex = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: "Calendário"
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: "Chat"
          ),
          NavigationDestination(
            icon: Icon(Icons.add),
            label: "Adicionar evento"
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: "Pesquisar lugares"
          ), 
          NavigationDestination(
            icon: Icon(Icons.contacts),
            label: "Contatos"
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