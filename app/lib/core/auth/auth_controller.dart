import 'package:flutter/foundation.dart';

import 'auth_repository.dart';
import 'auth_session.dart';
import 'auth_storage.dart';

enum AuthStatus { carregando, autenticado, naoAutenticado }

class AuthController extends ChangeNotifier {
  final AuthStorage _storage;
  late final AuthRepository _repositorio;

  AuthStatus _status = AuthStatus.carregando;
  AuthSession? _sessao;
  String? _aviso;

  AuthController({AuthStorage? storage, AuthRepository? repositorio})
    : _storage = storage ?? AuthStorage() {
    _repositorio =
        repositorio ??
        AuthRepository(
          tokenProvider: () async => _sessao?.token,
          onUnauthorized: _tratar401,
        );
  }

  AuthStatus get status => _status;
  AuthSession? get sessao => _sessao;
  AuthUsuario? get usuario => _sessao?.usuario;
  bool get autenticado => _status == AuthStatus.autenticado;
  String? get aviso => _aviso;

  Future<void> inicializar() async {
    try {
      final salva = await _storage.carrega();
      if (salva == null || salva.expirada) {
        if (salva != null) await _storage.limpa();
        _sessao = null;
        _status = AuthStatus.naoAutenticado;
        if (salva != null) {
          _aviso = 'Sua sessão expirou. Entre novamente.';
        }
      } else {
        _sessao = salva;
        _status = AuthStatus.autenticado;
      }
    } catch (_) {
      // Falha ao ler o armazenamento local: começa deslogado.
      _sessao = null;
      _status = AuthStatus.naoAutenticado;
    }
    notifyListeners();
  }

  Future<void> entrar({required String username, required String senha}) async {
    final sessao = await _repositorio.login(
      username: username.trim(),
      senha: senha,
    );
    await _aplicarSessao(sessao);
  }

  Future<void> registrar({
    required String nome,
    required String username,
    required String senha,
  }) async {
    final sessao = await _repositorio.registro(
      nome: nome.trim(),
      username: username.trim(),
      senha: senha,
    );
    await _aplicarSessao(sessao);
  }

  Future<void> sair() async {
    try {
      await _repositorio.logout();
    } catch (_) {
      // Mesmo que a API falhe, a sessão local é encerrada.
    }
    await _limparSessao();
  }

  void limparAviso() {
    if (_aviso == null) return;
    _aviso = null;
    notifyListeners();
  }

  /// Chamado quando outra camada recebe 401. Encerra a sessão local e deixa
  /// o app voltar ao calendário para pedir login na próxima ação protegida.
  Future<void> tratarNaoAutorizado() => _tratar401();

  Future<void> _aplicarSessao(AuthSession sessao) async {
    await _storage.salva(sessao);
    _sessao = sessao;
    _status = AuthStatus.autenticado;
    _aviso = null;
    notifyListeners();
  }

  Future<void> _tratar401() async {
    if (_status == AuthStatus.naoAutenticado) return;
    await _limparSessao(aviso: 'Sua sessão expirou. Entre novamente.');
  }

  Future<void> _limparSessao({String? aviso}) async {
    try {
      await _storage.limpa();
    } catch (_) {
      // Sem armazenamento acessível, ainda assim volta para o login.
    }
    _sessao = null;
    _status = AuthStatus.naoAutenticado;
    _aviso = aviso;
    notifyListeners();
  }
}
