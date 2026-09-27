import 'package:app/calendario.dart';
import 'package:flutter/material.dart';

import 'pesquisa.dart';
// import 'calendario.dart';
import 'cadastro.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange)
      ),
      home: BottomNavigationBar(),
    );
  }
}

class BottomNavigationBar extends StatefulWidget {
  const BottomNavigationBar({super.key});

  @override
  State<BottomNavigationBar> createState() => _BottomNavigationBarState();
}

class _BottomNavigationBarState extends State<BottomNavigationBar> {
  int _currentPageIndex = 0;

  final List<Widget> _widgetOptions = [
    TelaCalendario(),
    Text("WIP Chat"),
    Text("Adicionar evento"),
    Pesquisa(),
    Cadastrador(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("PlaceZ"),
        backgroundColor: Colors.red.shade300,
        actions: [
          IconButton(
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: "PlaceZ (Plêi Cês)",
              applicationLegalese: "MIT License",
              children: const [
                SizedBox(height: 16,),
                Text(
                  "Criado no segundo semestre de 2026 para a disciplina de " + 
                  "desenvolvimento móvel, com o intuito de facilitar o " + 
                  "encontro entre amigos."
                ),
                SizedBox(height: 16),
                Text("Desenvolvido por:"),
                Text("Guilherme Amaral Giffoni"),
                Text("Pedro Henrique"),
                Text("Rodrigo Fernandes"),
              ]
            ), 
            icon: Icon(Icons.info)
          )
        ],
      ),
      body: Expanded(
        child: _widgetOptions.elementAt(_currentPageIndex)
      ),
      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        selectedIndex: _currentPageIndex,
        onDestinationSelected: (int value) {
          setState(() {
            _currentPageIndex = value;
          });
        },
        destinations: <Widget>[
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: "Calendário",
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: "Chat",
          ),
          NavigationDestination(
            icon: Icon(Icons.add,),
            label: "Adicionar evento",
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: "Pesquisar lugares",
          ),
          NavigationDestination(
            icon: Icon(Icons.circle_outlined),
            label: "Perfil",
          ),
        ],
      ),
    );
  }
}
