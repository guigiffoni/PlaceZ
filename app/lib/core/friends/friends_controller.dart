import 'package:flutter/foundation.dart';

import '../../data/dao/amizade_dao.dart';
import '../../data/models/amizade.dart';
import '../auth/auth_controller.dart';
import '../network/api_exception.dart';
import 'friends_repository.dart';

class FriendsController extends ChangeNotifier {
  final AuthController auth;
  final FriendsRepository _repositorio;
  final AmizadeDao _cache;

  bool _carregando = false;
  bool _buscando = false;
  bool _buscandoMais = false;
  bool _temMaisBusca = false;
  int _paginaBusca = 1;
  bool _acaoEmAndamento = false;
  bool _mostrandoCache = false;
  bool _autenticadoAnterior = false;

  String? _erro;
  String? _erroBusca;
  String? _termoBusca;

  List<Amigo> _amigos = [];
  List<SolicitacaoAmizade> _recebidas = [];
  List<SolicitacaoAmizade> _enviadas = [];
  List<Bloqueio> _bloqueios = [];
  List<ResultadoBuscaUsuario> _resultados = [];

  FriendsController({
    required this.auth,
    FriendsRepository? repositorio,
    AmizadeDao? cache,
  }) : _repositorio =
           repositorio ??
           FriendsRepository(
             tokenProvider: () async => auth.sessao?.token,
             onUnauthorized: auth.tratarNaoAutorizado,
           ),
       _cache = cache ?? AmizadeDao() {
    _autenticadoAnterior = auth.autenticado;
    auth.addListener(_aoMudarAutenticacao);
    if (auth.autenticado) {
      carregar();
    }
  }

  bool get carregando => _carregando;
  bool get buscando => _buscando;
  bool get buscandoMais => _buscandoMais;
  bool get temMaisBusca => _temMaisBusca;
  bool get acaoEmAndamento => _acaoEmAndamento;
  bool get mostrandoCache => _mostrandoCache;
  String? get erro => _erro;
  String? get erroBusca => _erroBusca;
  String? get termoBusca => _termoBusca;

  List<Amigo> get amigos => _amigos;
  List<SolicitacaoAmizade> get recebidas => _recebidas;
  List<SolicitacaoAmizade> get enviadas => _enviadas;
  List<Bloqueio> get bloqueios => _bloqueios;
  List<ResultadoBuscaUsuario> get resultados => _resultados;

  @override
  void dispose() {
    auth.removeListener(_aoMudarAutenticacao);
    super.dispose();
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
      final respostas = await Future.wait<dynamic>([
        _repositorio.listarAmigos(),
        _repositorio.listarSolicitacoes(),
        _repositorio.listarBloqueios(),
      ]);

      _amigos = respostas[0] as List<Amigo>;
      final solicitacoes = respostas[1] as SolicitacoesAmizade;
      _recebidas = solicitacoes.recebidas;
      _enviadas = solicitacoes.enviadas;
      _bloqueios = respostas[2] as List<Bloqueio>;
      _erro = null;
      _mostrandoCache = false;

      await _salvarCache(solicitacoes);
    } on ApiException catch (erro) {
      if (!auth.autenticado) return;
      _erro = _mensagemDoErro(erro);
      await _carregarCache();
    } catch (erro) {
      _erro = 'Não foi possível carregar seus amigos: $erro';
      await _carregarCache();
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<void> buscar(String termo) async {
    final limpo = termo.trim();
    _termoBusca = limpo;

    if (limpo.length < 2) {
      _resultados = [];
      _paginaBusca = 1;
      _temMaisBusca = false;
      _erroBusca = 'Digite ao menos 2 caracteres para buscar.';
      notifyListeners();
      return;
    }

    _buscando = true;
    _erroBusca = null;
    _paginaBusca = 1;
    _temMaisBusca = false;
    notifyListeners();

    try {
      final resultado = await _repositorio.buscar(limpo);
      _resultados = resultado.usuarios;
      _paginaBusca = resultado.pagina;
      _temMaisBusca = resultado.temMais;
    } on ApiException catch (erro) {
      if (auth.autenticado) {
        _erroBusca = _mensagemDoErro(erro);
        _resultados = [];
      }
    } catch (erro) {
      _erroBusca = 'Não foi possível buscar usuários: $erro';
      _resultados = [];
    } finally {
      _buscando = false;
      notifyListeners();
    }
  }

  Future<void> carregarMaisBusca() async {
    final termo = _termoBusca;
    if (termo == null ||
        termo.length < 2 ||
        _buscando ||
        _buscandoMais ||
        !_temMaisBusca) {
      return;
    }

    _buscandoMais = true;
    _erroBusca = null;
    notifyListeners();

    try {
      final resultado = await _repositorio.buscar(
        termo,
        pagina: _paginaBusca + 1,
      );
      final ids = _resultados.map((item) => item.usuario.id).toSet();
      _resultados = [
        ..._resultados,
        ...resultado.usuarios.where((item) => !ids.contains(item.usuario.id)),
      ];
      _paginaBusca = resultado.pagina;
      _temMaisBusca = resultado.temMais;
    } on ApiException catch (erro) {
      if (auth.autenticado) {
        _erroBusca = _mensagemDoErro(erro);
      }
    } catch (erro) {
      _erroBusca = 'Não foi possível carregar mais usuários: $erro';
    } finally {
      _buscandoMais = false;
      notifyListeners();
    }
  }

  void limparBusca() {
    _termoBusca = null;
    _resultados = [];
    _erroBusca = null;
    _paginaBusca = 1;
    _temMaisBusca = false;
    _buscandoMais = false;
    notifyListeners();
  }

  Future<String?> enviarSolicitacao(String username) {
    return _executar(() => _repositorio.enviarSolicitacao(username));
  }

  Future<String?> aceitar(int solicitacaoId) {
    return _executar(() => _repositorio.aceitar(solicitacaoId));
  }

  Future<String?> recusar(int solicitacaoId) {
    return _executar(() => _repositorio.recusar(solicitacaoId));
  }

  Future<String?> cancelar(int solicitacaoId) {
    return _executar(() => _repositorio.cancelar(solicitacaoId));
  }

  Future<String?> remover(int usuarioId) {
    return _executar(() => _repositorio.remover(usuarioId));
  }

  Future<String?> alternarFavorito(Amigo amigo) async {
    if (_acaoEmAndamento) return null;

    final indice = _amigos.indexWhere(
      (item) => item.usuario.id == amigo.usuario.id,
    );
    if (indice < 0) return null;

    final anterior = _amigos[indice];
    final desejado = !anterior.favorito;

    _acaoEmAndamento = true;
    _amigos[indice] = anterior.copyWith(favorito: desejado);
    notifyListeners();

    try {
      final confirmado = desejado
          ? await _repositorio.favoritar(anterior.usuario.id)
          : await _repositorio.desfavoritar(anterior.usuario.id);
      _amigos[indice] = anterior.copyWith(favorito: confirmado);
      return null;
    } on ApiException catch (erro) {
      _amigos[indice] = anterior;
      return _mensagemDoErro(erro);
    } catch (erro) {
      _amigos[indice] = anterior;
      return 'Não foi possível atualizar o favorito: $erro';
    } finally {
      _acaoEmAndamento = false;
      notifyListeners();
    }
  }

  Future<String?> bloquear(int usuarioId) {
    return _executar(() => _repositorio.bloquear(usuarioId));
  }

  Future<String?> desbloquear(int usuarioId) {
    return _executar(() => _repositorio.desbloquear(usuarioId));
  }

  Future<String?> _executar(Future<void> Function() acao) async {
    if (_acaoEmAndamento) return null;

    _acaoEmAndamento = true;
    _erro = null;
    notifyListeners();

    try {
      await acao();
      await carregar(silencioso: true);
      await _atualizarBuscaAtiva();
      return null;
    } on ApiException catch (erro) {
      _erro = _mensagemDoErro(erro);
      return _erro;
    } catch (erro) {
      _erro = 'Não foi possível concluir a operação: $erro';
      return _erro;
    } finally {
      _acaoEmAndamento = false;
      notifyListeners();
    }
  }

  Future<void> _atualizarBuscaAtiva() async {
    final termo = _termoBusca;
    if (termo == null || termo.trim().length < 2) return;
    await buscar(termo);
  }

  void _aoMudarAutenticacao() {
    final autenticado = auth.autenticado;
    if (autenticado == _autenticadoAnterior) return;
    _autenticadoAnterior = autenticado;

    if (autenticado) {
      _erro = null;
      carregar();
      return;
    }

    _limparDados();
    _cache.limpar().catchError((_) {
      // Cache é apenas conveniência; falha de limpeza não bloqueia o logout.
    });
  }

  void _limparDados() {
    _amigos = [];
    _recebidas = [];
    _enviadas = [];
    _bloqueios = [];
    _resultados = [];
    _termoBusca = null;
    _erro = null;
    _erroBusca = null;
    _mostrandoCache = false;
    _carregando = false;
    _buscando = false;
    notifyListeners();
  }

  Future<void> _salvarCache(SolicitacoesAmizade solicitacoes) async {
    try {
      await _cache.salvarAmigos(_amigos);
      await _cache.salvarSolicitacoes(solicitacoes);
    } catch (_) {
      // O cache local não pode impedir a atualização da tela.
    }
  }

  Future<void> _carregarCache() async {
    try {
      final amigos = await _cache.carregarAmigos();
      final solicitacoes = await _cache.carregarSolicitacoes();
      if (amigos.isEmpty &&
          solicitacoes.recebidas.isEmpty &&
          solicitacoes.enviadas.isEmpty) {
        return;
      }

      _amigos = amigos;
      _recebidas = solicitacoes.recebidas;
      _enviadas = solicitacoes.enviadas;
      _mostrandoCache = true;
    } catch (_) {
      // Sem cache disponível, a UI mostra apenas o erro.
    }
  }

  String _mensagemDoErro(ApiException erro) {
    final detalhes = erro.details;
    if (detalhes is List && detalhes.isNotEmpty) {
      final itens = detalhes
          .map((item) {
            if (item is Map) {
              final campo = item['campo']?.toString();
              final mensagem = item['mensagem']?.toString() ?? item.toString();
              return campo == null || campo.isEmpty
                  ? mensagem
                  : '$campo: $mensagem';
            }
            return item.toString();
          })
          .join('\n');
      return '${erro.message}\n$itens';
    }
    return erro.message;
  }
}
