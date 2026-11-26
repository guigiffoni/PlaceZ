import 'package:flutter/foundation.dart';

import '../../data/dao/chat_dao.dart';
import '../../data/models/conversa.dart';
import '../auth/auth_controller.dart';
import '../network/api_exception.dart';
import 'chat_repository.dart';
import 'polling_service.dart';

class ConversasController extends ChangeNotifier {
  final AuthController auth;
  final ChatRepository _repositorio;
  final ChatDao _cache;
  late final PollingService _polling;

  bool _carregando = false;
  bool _mostrandoCache = false;
  bool _autenticadoAnterior = false;
  String? _erro;
  List<Conversa> _conversas = [];

  ConversasController({
    required this.auth,
    ChatRepository? repositorio,
    ChatDao? cache,
  }) : _repositorio =
           repositorio ??
           ChatRepository(
             tokenProvider: () async => auth.sessao?.token,
             onUnauthorized: auth.tratarNaoAutorizado,
           ),
       _cache = cache ?? ChatDao() {
    _polling = PollingService(
      intervalo: const Duration(seconds: 15),
      acao: () => carregar(silencioso: true),
    );
    _autenticadoAnterior = auth.autenticado;
    auth.addListener(_aoMudarAutenticacao);
    if (auth.autenticado) {
      carregar();
    }
  }

  bool get carregando => _carregando;
  bool get mostrandoCache => _mostrandoCache;
  String? get erro => _erro;
  List<Conversa> get conversas => List.unmodifiable(_conversas);

  @override
  void dispose() {
    _polling.parar();
    auth.removeListener(_aoMudarAutenticacao);
    super.dispose();
  }

  void iniciarPolling() {
    if (!auth.autenticado) return;
    _polling.iniciar();
  }

  void pararPolling() {
    _polling.parar();
  }

  void limparErro() {
    if (_erro == null) return;
    _erro = null;
    notifyListeners();
  }

  Future<void> carregar({bool silencioso = false}) async {
    if (!auth.autenticado) {
      _limparDados();
      return;
    }

    if (!silencioso) {
      _carregando = true;
      notifyListeners();
    }

    try {
      _conversas = await _repositorio.listarConversas();
      _erro = null;
      _mostrandoCache = false;
      await _cache.salvarConversas(_conversas);
    } on ApiException catch (erro) {
      if (!auth.autenticado) return;
      _erro = erro.message;
      await _carregarCache();
    } catch (erro) {
      _erro = 'Não foi possível carregar suas conversas: $erro';
      await _carregarCache();
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<void> _carregarCache() async {
    try {
      final conversas = await _cache.carregarConversas();
      if (conversas.isEmpty) return;
      _conversas = conversas;
      _mostrandoCache = true;
    } catch (_) {
      // Sem cache, a tela mostra apenas o erro.
    }
  }

  void _aoMudarAutenticacao() {
    final autenticado = auth.autenticado;
    if (autenticado == _autenticadoAnterior) return;
    _autenticadoAnterior = autenticado;

    if (autenticado) {
      _erro = null;
      _polling.iniciar();
      carregar();
      return;
    }

    _limparDados();
    _cache.limpar().catchError((_) {
      // Falha de limpeza não bloqueia o logout.
    });
  }

  void _limparDados() {
    _conversas = [];
    _erro = null;
    _carregando = false;
    _mostrandoCache = false;
    _polling.parar();
    notifyListeners();
  }
}
