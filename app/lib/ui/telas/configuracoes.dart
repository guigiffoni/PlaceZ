import 'package:flutter/material.dart';
import '../../core/auth/auth_controller.dart';
import '../../tema_controller.dart'; // Ajuste o caminho conforme seu projeto
import '../widgets/diagnostico_api.dart';
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

  String _iniciais(String nome) {
    final partes =
        nome.trim().split(RegExp(r'\s+')).where((parte) => parte.isNotEmpty);
    if (partes.isEmpty) return '?';
    final primeira = partes.first.characters.first.toUpperCase();
    if (partes.length == 1) return primeira;
    return '$primeira${partes.last.characters.first.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final usuario = authController.usuario;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListenableBuilder(
        listenable: Listenable.merge([temaController, authController]),
        builder: (context, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- CONTA (Fase 1) ---
              const Text(
                'Conta',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: ListTile(
                  leading: CircleAvatar(
                    child: usuario == null
                        ? const Icon(Icons.person_outline)
                        : Text(_iniciais(usuario.nome)),
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
                      : TextButton.icon(
                          onPressed: () => _confirmarSaida(context),
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Sair'),
                        ),
                ),
              ),

              const SizedBox(height: 32),

              // --- TEMA (Claro/Escuro/Automático) ---
              const Text('Modo de Tema', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.light, label: Text('Claro'), icon: Icon(Icons.light_mode)),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Escuro'), icon: Icon(Icons.dark_mode)),
                  ButtonSegment(value: ThemeMode.system, label: Text('Auto'), icon: Icon(Icons.settings_brightness)),
                ],
                selected: {temaController.modoTema},
                onSelectionChanged: (Set<ThemeMode> newSelection) {
                  temaController.mudaModoTema(newSelection.first);
                },
              ),
              
              const SizedBox(height: 32),

              // --- COR SEMENTE ---
              const Text('Cor Principal', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _corOpcao(temaController, Colors.deepPurple),
                  _corOpcao(temaController, Colors.blue),
                  _corOpcao(temaController, Colors.green),
                  _corOpcao(temaController, Colors.orangeAccent),
                  _corOpcao(temaController, Colors.red.shade500),
                  _corOpcao(temaController, Colors.teal),
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

  Widget _corOpcao(TemaController controller, Color cor) {
    final isSelected = controller.seedCor == cor;
    return GestureDetector(
      onTap: () => controller.mudaSeedCor(cor),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: cor,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
      ),
    );
  }
}