import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../data/models/local.dart';
import '../pesquisa.dart';

/// Tela cheia usada quando o formulário de evento foi aberto como rota
/// (por exemplo, pelo calendário) e precisa escolher um local no catálogo.
class TelaSelecaoLocal extends StatelessWidget {
  final AuthController authController;

  const TelaSelecaoLocal({super.key, required this.authController});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escolher local')),
      body: TelaPesquisa(
        authController: authController,
        modoSelecao: true,
        onSelecionar: (Local local) => Navigator.of(context).pop(local),
      ),
    );
  }
}
