/// Ponto de integração das notificações push.
///
/// A Fase 8 mantém o modo no-op: nenhuma dependência do Firebase é carregada
/// e nenhum token é registrado. Quando o Firebase for configurado, basta
/// trocar a factory em [criarNotificacaoService] por uma implementação FCM.
abstract class NotificacaoService {
  bool get disponivel;

  Future<void> inicializar();

  Future<String?> obterToken();

  Future<void> descartarToken();
}

class NoopNotificacaoService implements NotificacaoService {
  const NoopNotificacaoService();

  @override
  bool get disponivel => false;

  @override
  Future<void> inicializar() async {}

  @override
  Future<String?> obterToken() async => null;

  @override
  Future<void> descartarToken() async {}
}

NotificacaoService criarNotificacaoService() {
  // Fase 8: modo no-op. Para ativar o FCM, adicione firebase_core e
  // firebase_messaging, o google-services.json e uma implementação que
  // devolva o token do dispositivo.
  return const NoopNotificacaoService();
}
