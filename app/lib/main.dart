import 'package:flutter/material.dart';

import 'calendario.dart';
import 'pesquisa.dart';
import 'cadastro.dart';
import 'chat.dart';
import 'evento.dart';
import 'sobre.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "PlaceZ",
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
        ),
      ),
      home: const BarraNavegacao(),
    );
  }
}

class BarraNavegacao extends StatefulWidget {
  const BarraNavegacao({super.key});

  @override
  State<BarraNavegacao> createState() =>
      _BarraNavegacaoState();
}

class _BarraNavegacaoState
    extends State<BarraNavegacao> {
  int _currentPageIndex = 0;

  final List<Widget> _widgetOptions = [
    const TelaCalendario(),
    const TelaChat(),
    const TelaEvento(),
    const Pesquisa(),
    const Cadastrador(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PlaceZ"),
        backgroundColor: Colors.red.shade300,

        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const TelaSobre(),
                ),
              );
            },
            icon: const Icon(
              Icons.info_outline,
            ),
          ),
        ],
      ),

      body: _widgetOptions.elementAt(
        _currentPageIndex,
      ),

      bottomNavigationBar: NavigationBar(
        labelBehavior:
            NavigationDestinationLabelBehavior
                .alwaysHide,

        selectedIndex: _currentPageIndex,

        onDestinationSelected: (int value) {
          setState(() {
            _currentPageIndex = value;
          });
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.calendar_month,
            ),
            label: "Calendário",
          ),

          NavigationDestination(
            icon: Icon(
              Icons.chat_bubble_outline,
            ),
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
            icon: Icon(
              Icons.circle_outlined,
            ),
            label: "Perfil",
          ),
        ],
      ),
    );
  }
}