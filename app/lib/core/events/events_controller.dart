import 'package:flutter/foundation.dart';

import '../../data/dao/evento_dao.dart';
import '../../data/models/evento.dart';
import '../auth/auth_controller.dart';
import '../network/api_exception.dart';
import 'events_repository.dart';

class EventsController extends ChangeNotifier {
  final AuthController auth;
  final EventsRepository _repositorio;
  final EventoDao _cache;

  bool _carregando = false;
  bool _detalhando = false;
  bool _acaoEmAndamento = false;
  bool _mostrandoCache = false;
  bool _autenticadoAnterior = false;

  String? _erro;
  List<Evento> _eventos = [];

  EventsController({
    required this.auth,
    EventsRepository? repositorio,
    EventoDao? cache,
  }) : _repositorio =
           repositorio ??
           EventsRepository(
             tokenProvider: () async => auth.sessao?.token,
             onUnauthorized: auth.tratarNaoAutorizado,
           ),
       _cache = cache ?? EventoDao() {
    _autenticadoAnterior = auth.autenticado;
    auth.addListener(_aoMudarAutenticacao);
    if (auth.autenticado) {
      carregar();
    }
  }

  bool get carregando => _carregando;
  bool get detalhando => _detalhando;
  bool get acaoEmAndamento => _acaoEmAndamento;
  bool get mostrandoCache => _mostrandoCache;
  String? get erro => _erro;
  List<Evento> get eventos => List.unmodifiable(_eventos);
  int? get meuUsuarioId => auth.usuario?.id;

  @override
  void dispose() {
    auth.removeListener(_aoMudarAutenticacao);
    super.dispose();
  }

  Evento? eventoPorId(int id) {
    for (final evento in _eventos) {
      if (evento.id == id) return evento;
    }
    return null;
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
      _eventos = await _repositorio.listar();
      _ordenar();
      _erro = null;
      _mostrandoCache = false;
      await _salvarListaNoCache();
    } on ApiException catch (erro) {
      if (!auth.autenticado) return;
      _erro = _mensagemDoErro(erro);
      await _carregarCache();
    } catch (erro) {
      _erro = 'Não foi possível carregar seus eventos: $erro';
      await _carregarCache();
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<Evento?> detalhar(int id, {bool silencioso = false}) async {
    if (!auth.autenticado) return null;

    if (!silencioso) {
      _detalhando = true;
      notifyListeners();
    }

    try {
      final evento = await _repositorio.detalhar(id);
      await _aplicarEvento(evento, notificar: false);
      _erro = null;
      _mostrandoCache = false;
      return evento;
    } on ApiException catch (erro) {
      if (!auth.autenticado) return null;
      _erro = _mensagemDoErro(erro);
      return _detalheDoCache(id);
    } catch (erro) {
      _erro = 'Não foi possível carregar o evento: $erro';
      return _detalheDoCache(id);
    } finally {
      _detalhando = false;
      notifyListeners();
    }
  }

  Future<String?> criar(
    EventoEntrada entrada, {
    List<int> convidadoIds = const [],
  }) {
    return _executar(() async {
      final evento = await _repositorio.criar(
        entrada,
        convidadoIds: convidadoIds,
      );
      await _aplicarEvento(evento);
    });
  }

  Future<String?> editar(int id, EventoEntrada entrada) {
    return _executar(() async {
      final evento = await _repositorio.atualizar(id, entrada);
      await _aplicarEvento(evento);
    });
  }

  Future<String?> cancelar(int id) {
    return _executar(() async {
      await _repositorio.cancelar(id);
      _eventos.removeWhere((evento) => evento.id == id);
      await _salvarListaNoCache();
    });
  }

  Future<String?> convidar(int id, List<int> usuarioIds) {
    return _executarComEvento(() => _repositorio.convidar(id, usuarioIds));
  }

  Future<String?> convidarTodos(int id) {
    return _executarComEvento(() => _repositorio.convidarTodos(id));
  }

  Future<String?> removerConvidado(int id, int usuarioId) {
    return _executar(() async {
      final evento = await _repositorio.removerConvidado(id, usuarioId);
      if (evento == null) {
        _eventos.removeWhere((item) => item.id == id);
        await _salvarListaNoCache();
      } else {
        await _aplicarEvento(evento);
      }
    });
  }

  Future<String?> responderRsvp(int id, RsvpStatus rsvp) {
    return _executarComEvento(() => _repositorio.responderRsvp(id, rsvp));
  }

  Future<String?> atualizarConfig(
    int id, {
    bool? privado,
    bool? permitirMembrosConvidar,
  }) {
    return _executarComEvento(
      () => _repositorio.atualizarConfig(
        id,
        privado: privado,
        permitirMembrosConvidar: permitirMembrosConvidar,
      ),
    );
  }

  Future<String?> _executarComEvento(Future<Evento> Function() acao) {
    return _executar(() async {
      final evento = await acao();
      await _aplicarEvento(evento);
    });
  }

  Future<String?> _executar(Future<void> Function() acao) async {
    if (_acaoEmAndamento) return null;

    _acaoEmAndamento = true;
    _erro = null;
    notifyListeners();

    try {
      await acao();
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

  Future<void> _aplicarEvento(Evento evento, {bool notificar = true}) async {
    _mesclar(evento);
    if (notificar) notifyListeners();
    try {
      await _cache.salvarEvento(evento, usuarioId: meuUsuarioId);
    } catch (_) {
      // O cache não pode impedir a atualização da tela.
    }
  }

  void _mesclar(Evento evento) {
    final indice = _eventos.indexWhere((item) => item.id == evento.id);
    if (indice >= 0) {
      _eventos[indice] = evento;
    } else {
      _eventos.add(evento);
    }
    _ordenar();
  }

  void _ordenar() {
    _eventos.sort((a, b) {
      final d1 = a.inicioEm;
      final d2 = b.inicioEm;
      if (d1 == null && d2 == null) {
        return (a.id ?? 0).compareTo(b.id ?? 0);
      }
      if (d1 == null) return 1;
      if (d2 == null) return -1;
      final comparacao = d1.compareTo(d2);
      if (comparacao != 0) return comparacao;
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });
  }

  Future<Evento?> _detalheDoCache(int id) async {
    final evento = await _cache.carregarEvento(id, usuarioId: meuUsuarioId);
    if (evento == null) return null;
    _mostrandoCache = true;
    _mesclar(evento);
    return evento;
  }

  Future<void> _salvarListaNoCache() async {
    try {
      await _cache.salvarEventos(_eventos, usuarioId: meuUsuarioId);
    } catch (_) {
      // Cache é apenas conveniência.
    }
  }

  Future<void> _carregarCache() async {
    try {
      final eventos = await _cache.carregarEventos(usuarioId: meuUsuarioId);
      if (eventos.isEmpty) return;
      _eventos = eventos;
      _mostrandoCache = true;
    } catch (_) {
      // Sem cache, a UI mostra somente o erro.
    }
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
      // Falha de limpeza não bloqueia o logout.
    });
  }

  void _limparDados() {
    _eventos = [];
    _erro = null;
    _carregando = false;
    _detalhando = false;
    _acaoEmAndamento = false;
    _mostrandoCache = false;
    notifyListeners();
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
