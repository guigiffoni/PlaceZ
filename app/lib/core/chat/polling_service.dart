import 'dart:async';

/// Executa uma atualização periódica sem sobrepor chamadas.
class PollingService {
  final Duration intervalo;
  final Future<void> Function() acao;

  Timer? _timer;
  bool _ativo = false;
  bool _executando = false;

  PollingService({required this.intervalo, required this.acao});

  bool get ativo => _ativo;

  void iniciar() {
    if (_ativo) return;
    _ativo = true;
    _timer = Timer.periodic(intervalo, (_) => _executar());
  }

  void parar() {
    _ativo = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _executar() async {
    if (_executando || !_ativo) return;
    _executando = true;
    try {
      await acao();
    } catch (_) {
      // A tela dona do polling decide como exibir o erro.
    } finally {
      _executando = false;
    }
  }
}
