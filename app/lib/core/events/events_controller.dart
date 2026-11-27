import 'package:flutter/foundation.dart';

import '../../data/dao/evento_dao.dart';
import '../../data/dao/ranking_pessoas_dao.dart';
import '../../data/models/enquete.dart';
import '../../data/models/evento.dart';
import '../../data/models/ranking_pessoa.dart';
import '../auth/auth_controller.dart';
import '../network/api_exception.dart';
import 'events_repository.dart';

class EventsController extends ChangeNotifier {
  final AuthController auth;
  final EventsRepository _repositorio;
  final EventoDao _cache;
  final RankingPessoasDao _rankingCache;

  bool _carregando = false;
  bool _detalhando = false;
  bool _acaoEmAndamento = false;
  bool _mostrandoCache = false;
  bool _autenticadoAnterior = false;

  String? _erro;
  List<Evento> _eventos = [];
  List<Evento> _rascunhos = [];
  Evento? _ultimoCriado;
  List<PessoaRanking> _ranking = const [];
  final Set<int> _pessoasSelecionadas = <int>{};

  EventsController({
    required this.auth,
    EventsRepository? repositorio,
    EventoDao? cache,
    RankingPessoasDao? rankingCache,
  }) : _repositorio =
           repositorio ??
           EventsRepository(
             tokenProvider: () async => auth.sessao?.token,
             onUnauthorized: auth.tratarNaoAutorizado,
           ),
       _cache = cache ?? EventoDao(),
       _rankingCache = rankingCache ?? RankingPessoasDao() {
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
  List<Evento> get rascunhos => List.unmodifiable(_rascunhos);
  Evento? get ultimoEventoCriado => _ultimoCriado;
  List<PessoaRanking> get ranking => List.unmodifiable(_ranking);
  Set<int> get pessoasSelecionadas => Set.unmodifiable(_pessoasSelecionadas);
  bool get temFiltroPessoas => _pessoasSelecionadas.isNotEmpty;
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

  Future<void> carregar({
    bool silencioso = false,
    bool incluirRanking = true,
  }) async {
    if (!auth.autenticado) {
      _limparDados();
      return;
    }

    if (!silencioso) {
      _carregando = true;
      notifyListeners();
    }

    if (incluirRanking) {
      await _carregarRanking();
    }

    try {
      _eventos = await _repositorio.listar(
        pessoas: _pessoasSelecionadas.toList(),
      );
      _ordenar();
      _erro = null;
      _mostrandoCache = false;
      if (_pessoasSelecionadas.isEmpty) {
        await _salvarListaNoCache();
      }
      await _carregarRascunhos();
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

  /// Aplica ou remove uma pessoa do filtro do calendário.
  Future<void> alternarPessoa(int usuarioId) async {
    if (!auth.autenticado) return;

    if (!_pessoasSelecionadas.remove(usuarioId)) {
      _pessoasSelecionadas.add(usuarioId);
    }
    notifyListeners();
    await carregar(silencioso: true, incluirRanking: false);
  }

  Future<void> limparFiltroPessoas() async {
    if (_pessoasSelecionadas.isEmpty) return;
    _pessoasSelecionadas.clear();
    notifyListeners();
    await carregar(silencioso: true, incluirRanking: false);
  }

  /// Recarrega tudo ao voltar para a aba do calendário.
  Future<void> atualizarCalendario() {
    return carregar(silencioso: true);
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
    _ultimoCriado = null;
    return _executar(
      () async {
        final evento = await _repositorio.criar(
          entrada,
          convidadoIds: convidadoIds,
        );
        _ultimoCriado = evento;
        await _aplicarEvento(evento);
      },
      recarregar: true,
      atualizarRanking: true,
    );
  }

  Future<String?> editar(int id, EventoEntrada entrada) {
    return _executar(() async {
      final evento = await _repositorio.atualizar(id, entrada);
      await _aplicarEvento(evento);
    }, recarregar: true);
  }

  Future<String?> atualizarImagemEvento(
    int eventoId,
    List<int> bytes,
    String mime,
  ) async {
    try {
      await _repositorio.atualizarImagem(eventoId, bytes, mime);
      final evento = await _repositorio.detalhar(eventoId);
      await _aplicarEvento(evento);
      return null;
    } on ApiException catch (erro) {
      return _mensagemDoErro(erro);
    } catch (erro) {
      return 'Não foi possível salvar a imagem: $erro';
    }
  }

  Future<String?> removerImagemEvento(int eventoId) async {
    try {
      await _repositorio.removerImagem(eventoId);
      final evento = await _repositorio.detalhar(eventoId);
      await _aplicarEvento(evento);
      return null;
    } on ApiException catch (erro) {
      return _mensagemDoErro(erro);
    } catch (erro) {
      return 'Não foi possível remover a imagem: $erro';
    }
  }

  Future<String?> cancelar(int id) {
    return _executar(
      () async {
        await _repositorio.cancelar(id);
        _eventos.removeWhere((evento) => evento.id == id);
        if (_pessoasSelecionadas.isEmpty) {
          await _salvarListaNoCache();
        }
      },
      recarregar: true,
      atualizarRanking: true,
    );
  }

  Future<String?> convidar(int id, List<int> usuarioIds) {
    return _executarComEvento(
      () => _repositorio.convidar(id, usuarioIds),
      recarregar: true,
      atualizarRanking: true,
    );
  }

  Future<String?> convidarTodos(int id) {
    return _executarComEvento(
      () => _repositorio.convidarTodos(id),
      recarregar: true,
      atualizarRanking: true,
    );
  }

  Future<String?> removerConvidado(int id, int usuarioId) {
    return _executar(
      () async {
        final evento = await _repositorio.removerConvidado(id, usuarioId);
        if (evento == null) {
          _eventos.removeWhere((item) => item.id == id);
          if (_pessoasSelecionadas.isEmpty) {
            await _salvarListaNoCache();
          }
        } else {
          await _aplicarEvento(evento);
        }
      },
      recarregar: true,
      atualizarRanking: true,
    );
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

  Future<ConsultaEnquete> consultarEnquete(int eventoId) {
    return _repositorio.consultarEnquete(eventoId);
  }

  Future<ConsultaEnquete> criarEnquete(int eventoId, EnqueteEntrada entrada) {
    return _repositorio.criarEnquete(eventoId, entrada);
  }

  Future<ConsultaEnquete> votarEnquete(int eventoId, List<VotoEnquete> votos) {
    return _repositorio.votarEnquete(eventoId, votos);
  }

  Future<String?> aplicarMelhorDia(int eventoId) {
    return _executar(() async {
      final evento = await _repositorio.aplicarMelhorDia(eventoId);
      await _aplicarEvento(evento);
    }, recarregar: true);
  }

  Future<String?> _executarComEvento(
    Future<Evento> Function() acao, {
    bool recarregar = false,
    bool atualizarRanking = false,
  }) {
    return _executar(
      () async {
        final evento = await acao();
        await _aplicarEvento(evento);
      },
      recarregar: recarregar,
      atualizarRanking: atualizarRanking,
    );
  }

  Future<String?> _executar(
    Future<void> Function() acao, {
    bool recarregar = false,
    bool atualizarRanking = false,
  }) async {
    if (_acaoEmAndamento) return null;

    _acaoEmAndamento = true;
    _erro = null;
    notifyListeners();

    try {
      await acao();
      if (recarregar) {
        await carregar(silencioso: true, incluirRanking: atualizarRanking);
      } else if (atualizarRanking) {
        await _carregarRanking();
        notifyListeners();
      }
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

  Future<void> _carregarRascunhos() async {
    try {
      _rascunhos = await _repositorio.rascunhos();
    } catch (_) {
      // A lista de rascunhos é opcional; o calendário continua funcionando.
    }
  }

  Future<void> _carregarRanking() async {
    try {
      final ranking = await _repositorio.rankingPessoas();
      _ranking = ranking;
      _podarSelecao();
      await _rankingCache.salvar(ranking);
    } catch (_) {
      try {
        final ranking = await _rankingCache.carregar();
        if (ranking.isNotEmpty) {
          _ranking = ranking;
          _podarSelecao();
        }
      } catch (_) {
        // O ranking é opcional; sem ele o calendário continua funcionando.
      }
    }
  }

  void _podarSelecao() {
    final ids = _ranking.map((pessoa) => pessoa.usuarioId).toSet();
    _pessoasSelecionadas.removeWhere((id) => !ids.contains(id));
  }

  Future<void> _carregarCache() async {
    try {
      final eventos = await _cache.carregarEventos(usuarioId: meuUsuarioId);
      if (eventos.isEmpty) return;
      _eventos = _filtrarPorPessoas(eventos);
      _mostrandoCache = true;
    } catch (_) {
      // Sem cache, a UI mostra somente o erro.
    }
  }

  List<Evento> _filtrarPorPessoas(List<Evento> eventos) {
    if (_pessoasSelecionadas.isEmpty) return eventos;
    return eventos.where((evento) {
      return evento.convidados.any(
        (convidado) => _pessoasSelecionadas.contains(convidado.usuario.id),
      );
    }).toList();
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
    _rankingCache.limpar().catchError((_) {
      // Falha de limpeza não bloqueia o logout.
    });
  }

  void _limparDados() {
    _eventos = [];
    _rascunhos = [];
    _ultimoCriado = null;
    _ranking = const [];
    _pessoasSelecionadas.clear();
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
