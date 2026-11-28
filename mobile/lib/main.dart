import 'package:flutter/material.dart';
import 'tela_calendario.dart';

void main() {
  runApp(const PlaceZ());
}

class PlaceZ extends StatelessWidget {
  const PlaceZ({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '7-PlaceZ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const TelaCalendario(),
    );
  }
}