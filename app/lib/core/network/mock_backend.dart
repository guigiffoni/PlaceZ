import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Resposta produzida pelo backend mock stateful.
class MockResponse {
  final int status;
  final dynamic body;

  const MockResponse(this.status, this.body);
}

/// Simula a API das Fases 1 e 2 (autenticação e amigos) sem Oracle.
///
/// O estado é persistido em SharedPreferences para que o ciclo completo possa
/// ser validado com duas contas: criar conta, sair, entrar com a outra conta,
/// solicitar, aceitar, bloquear e desbloquear.
class MockBackend {
  static const String _chaveEstado = 'mock_backend_v1';
  static const String senhaPadrao = '123456';

  final Map<String, dynamic> _dados;

  MockBackend._(this._dados);

  static Future<MockBackend> carrega() async {
    final prefs = await SharedPreferences.getInstance();
    final bruto = prefs.getString(_chaveEstado);

    Map<String, dynamic>? dados;
    if (bruto != null && bruto.isNotEmpty) {
      try {
        final decodificado = jsonDecode(bruto);
        if (decodificado is Map && decodificado['usuarios'] is List) {
          dados = Map<String, dynamic>.from(decodificado);
        }
      } catch (_) {
        // Estado corrompido: recomeça com as contas semeadas.
      }
    }

    final backend = MockBackend._(dados ?? _estadoInicial());
    if (dados == null) {
      await backend._salva();
    } else if (backend._garanteEstadoNovo()) {
      await backend._salva();
    }
    return backend;
  }

  /// Compatibilidade com o estado persistido das Fases 1 e 2: acrescenta as
  /// coleções de eventos sem descartar contas, amizades ou bloqueios.
  bool _garanteEstadoNovo() {
    var alterou = false;

    void garante(String chave, dynamic valor) {
      if (_dados.containsKey(chave)) return;
      _dados[chave] = valor;
      alterou = true;
    }

    garante('proximo_evento_id', 1);
    garante('proximo_local_id', 1);
    garante('eventos', <dynamic>[]);
    garante('convidados_evento', <dynamic>[]);
    return alterou;
  }

  static Map<String, dynamic> _estadoInicial() {
    return {
      'proximo_usuario_id': 4,
      'proxima_amizade_id': 1,
      'proximo_evento_id': 1,
      'proximo_local_id': 1,
      'usuarios': [
        {
          'id': 1,
          'nome': 'Usuário Mock',
          'username': 'mock',
          'senha': senhaPadrao,
        },
        {'id': 2, 'nome': 'Ana Souza', 'username': 'ana', 'senha': senhaPadrao},
        {
          'id': 3,
          'nome': 'Bruno Lima',
          'username': 'bruno',
          'senha': senhaPadrao,
        },
      ],
      'sessoes': <String, dynamic>{},
      'amizades': <dynamic>[],
      'bloqueios': <dynamic>[],
      'eventos': <dynamic>[],
      'convidados_evento': <dynamic>[],
    };
  }

  Future<MockResponse?> handle({
    required String method,
    required String path,
    Map<String, String>? query,
    Object? body,
    String? token,
  }) async {
    final caminho = _normalizaCaminho(path);
    final corpo = body is Map
        ? Map<String, dynamic>.from(body)
        : <String, dynamic>{};

    switch ('$method $caminho') {
      case 'POST /auth/registro':
        return _registrar(corpo);
      case 'POST /auth/login':
        return _login(corpo);
      case 'POST /auth/logout':
        return _logout(token);
      case 'GET /me':
        return _me(token);
      case 'GET /usuarios/busca':
        return _buscar(token, query);
      case 'GET /amigos':
        return _listarAmigos(token);
      case 'GET /amigos/solicitacoes':
        return _listarSolicitacoes(token);
      case 'POST /amigos/solicitacoes':
        return _enviarSolicitacao(token, corpo);
      case 'GET /bloqueios':
        return _listarBloqueios(token);
      case 'POST /bloqueios':
        return _bloquear(token, corpo);
      case 'GET /eventos':
        return _listarEventos(token, query);
      case 'POST /eventos':
        return _criarEvento(token, corpo);
      case 'GET /calendario/pessoas-frequentes':
        return _rankingPessoas(token);
    }

    final convidaTodos = RegExp(r'^/eventos/(\d+)/convidados/todos$')
        .firstMatch(caminho);
    if (method == 'POST' && convidaTodos != null) {
      return _convidarTodos(token, int.parse(convidaTodos.group(1)!));
    }

    final convidaEvento = RegExp(r'^/eventos/(\d+)/convidados$')
        .firstMatch(caminho);
    if (method == 'POST' && convidaEvento != null) {
      return _convidarEvento(token, int.parse(convidaEvento.group(1)!), corpo);
    }

    final removeConvidado = RegExp(r'^/eventos/(\d+)/convidados/(\d+)$')
        .firstMatch(caminho);
    if (method == 'DELETE' && removeConvidado != null) {
      return _removerConvidado(
        token,
        int.parse(removeConvidado.group(1)!),
        int.parse(removeConvidado.group(2)!),
      );
    }

    final rsvpEvento = RegExp(r'^/eventos/(\d+)/rsvp$').firstMatch(caminho);
    if (method == 'PATCH' && rsvpEvento != null) {
      return _responderRsvp(token, int.parse(rsvpEvento.group(1)!), corpo);
    }

    final configEvento = RegExp(r'^/eventos/(\d+)/config$').firstMatch(caminho);
    if (method == 'PATCH' && configEvento != null) {
      return _configurarEvento(token, int.parse(configEvento.group(1)!), corpo);
    }

    final eventoId = RegExp(r'^/eventos/(\d+)$').firstMatch(caminho);
    if (eventoId != null) {
      final id = int.parse(eventoId.group(1)!);
      if (method == 'GET') return _detalharEvento(token, id);
      if (method == 'PATCH') return _atualizarEvento(token, id, corpo);
      if (method == 'DELETE') return _cancelarEvento(token, id);
    }

    final respostaSolicitacao = RegExp(
      r'^/amigos/solicitacoes/(\d+)/(aceitar|recusar)$',
    ).firstMatch(caminho);
    if (method == 'POST' && respostaSolicitacao != null) {
      return _responderSolicitacao(
        token,
        int.parse(respostaSolicitacao.group(1)!),
        respostaSolicitacao.group(2)!,
      );
    }

    final cancelaSolicitacao = RegExp(r'^/amigos/solicitacoes/(\d+)$')
        .firstMatch(caminho);
    if (method == 'DELETE' && cancelaSolicitacao != null) {
      return _cancelarSolicitacao(
        token,
        int.parse(cancelaSolicitacao.group(1)!),
      );
    }

    final removeAmigo = RegExp(r'^/amigos/(\d+)$').firstMatch(caminho);
    if (method == 'DELETE' && removeAmigo != null) {
      return _removerAmigo(token, int.parse(removeAmigo.group(1)!));
    }

    final removeBloqueio = RegExp(r'^/bloqueios/(\d+)$').firstMatch(caminho);
    if (method == 'DELETE' && removeBloqueio != null) {
      return _desbloquear(token, int.parse(removeBloqueio.group(1)!));
    }

    return null;
  }

  Future<MockResponse> _registrar(Map<String, dynamic> corpo) async {
    final nome = (corpo['nome'] ?? '').toString().trim();
    final username = (corpo['username'] ?? '').toString().trim().toLowerCase();
    final senha = (corpo['senha'] ?? '').toString();
    final detalhes = <Map<String, String>>[];

    if (nome.length < 2 || nome.length > 120) {
      detalhes.add({
        'campo': 'nome',
        'mensagem': 'Informe um nome entre 2 e 120 caracteres.',
      });
    }
    if (!RegExp(r'^[a-z0-9._-]{3,40}$').hasMatch(username)) {
      detalhes.add({
        'campo': 'username',
        'mensagem': 'Use de 3 a 40 caracteres: letras, números, ponto, hífen ou sublinhado.',
      });
    }
    if (senha.length < 6 || senha.length > 72) {
      detalhes.add({
        'campo': 'senha',
        'mensagem': 'A senha deve ter entre 6 e 72 caracteres.',
      });
    }
    if (detalhes.isNotEmpty) {
      return _erro(400, 'VALIDACAO', 'Dados inválidos.', detalhes);
    }

    if (_usuarioPorUsername(username) != null) {
      return _erro(409, 'USERNAME_EM_USO', 'Este username já está em uso.');
    }

    final usuario = <String, dynamic>{
      'id': _dados['proximo_usuario_id'] as int,
      'nome': nome,
      'username': username,
      'senha': senha,
    };
    _dados['proximo_usuario_id'] = (usuario['id'] as int) + 1;
    _usuarios.add(usuario);

    final token = _criarSessao(usuario);
    await _salva();
    return MockResponse(201, _sessaoResposta(usuario, token));
  }

  Future<MockResponse> _login(Map<String, dynamic> corpo) async {
    final username = (corpo['username'] ?? '').toString().trim().toLowerCase();
    final senha = (corpo['senha'] ?? '').toString();

    if (username.isEmpty || senha.isEmpty) {
      return _erro(400, 'VALIDACAO', 'Dados inválidos.', [
        if (username.isEmpty)
          {'campo': 'username', 'mensagem': 'Informe o username.'},
        if (senha.isEmpty) {'campo': 'senha', 'mensagem': 'Informe a senha.'},
      ]);
    }

    final usuario = _usuarioPorUsername(username);
    if (usuario == null || usuario['senha'] != senha) {
      return _erro(
        401,
        'CREDENCIAIS_INVALIDAS',
        'Username ou senha inválidos.',
      );
    }

    final token = _criarSessao(usuario);
    await _salva();
    return MockResponse(200, _sessaoResposta(usuario, token));
  }

  Future<MockResponse> _logout(String? token) async {
    if (token != null) {
      (_dados['sessoes'] as Map<String, dynamic>).remove(token);
      await _salva();
    }
    return const MockResponse(204, null);
  }

  MockResponse _me(String? token) {
    final usuario = _usuarioDaSessao(token);
    if (usuario == null) return _sessaoInvalida();
    return MockResponse(200, _publico(usuario));
  }

  MockResponse _buscar(String? token, Map<String, String>? query) {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final termo = (query?['q'] ?? '').toString().trim().toLowerCase();
    if (termo.length < 2) {
      return _erro(400, 'VALIDACAO', 'Dados inválidos.', [
        {
          'campo': 'q',
          'mensagem': 'Informe ao menos 2 caracteres para buscar.',
        },
      ]);
    }

    final meuId = eu['id'] as int;
    final encontrados = <Map<String, dynamic>>[];

    for (final usuario in _usuarios) {
      final id = usuario['id'] as int;
      final username = (usuario['username'] ?? '').toString();
      if (id == meuId || !username.contains(termo)) continue;
      if (_existeBloqueio(meuId, id)) continue;

      final amizade = _amizadeDoPar(meuId, id);
      final relacao = _relacao(amizade, meuId);
      encontrados.add({
        'usuario': _publico(usuario),
        'relacao': relacao,
        'solicitacaoId':
            relacao == 'solicitacao_enviada' ||
                relacao == 'solicitacao_recebida'
            ? amizade == null
                  ? null
                  : amizade['id']
            : null,
      });
    }

    encontrados.sort(
      (a, b) => (a['usuario'] as Map)['username'].toString().compareTo(
        (b['usuario'] as Map)['username'].toString(),
      ),
    );

    return MockResponse(200, {'usuarios': encontrados.take(20).toList()});
  }

  MockResponse _listarAmigos(String? token) {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final amigos = <Map<String, dynamic>>[];

    for (final amizade in _amizades) {
      if (amizade['status'] != 'A') continue;
      final solicitante = amizade['solicitanteId'] as int;
      final destinatario = amizade['destinatarioId'] as int;
      if (solicitante != meuId && destinatario != meuId) continue;

      final outroId = solicitante == meuId ? destinatario : solicitante;
      final outro = _usuarioPorId(outroId);
      if (outro == null) continue;

      amigos.add({'amizadeId': amizade['id'], 'usuario': _publico(outro)});
    }

    amigos.sort(
      (a, b) => (a['usuario'] as Map)['nome'].toString().compareTo(
        (b['usuario'] as Map)['nome'].toString(),
      ),
    );
    return MockResponse(200, {'amigos': amigos});
  }

  MockResponse _listarSolicitacoes(String? token) {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final recebidas = <Map<String, dynamic>>[];
    final enviadas = <Map<String, dynamic>>[];

    for (final amizade in _amizades) {
      if (amizade['status'] != 'P') continue;

      if (amizade['destinatarioId'] == meuId) {
        final solicitante = _usuarioPorId(amizade['solicitanteId'] as int);
        if (solicitante == null) continue;
        recebidas.add({
          'id': amizade['id'],
          'usuario': _publico(solicitante),
          'criadoEm': amizade['criadoEm'],
        });
      } else if (amizade['solicitanteId'] == meuId) {
        final destinatario = _usuarioPorId(amizade['destinatarioId'] as int);
        if (destinatario == null) continue;
        enviadas.add({
          'id': amizade['id'],
          'usuario': _publico(destinatario),
          'criadoEm': amizade['criadoEm'],
        });
      }
    }

    return MockResponse(200, {
      'recebidas': _maisRecentesPrimeiro(recebidas),
      'enviadas': _maisRecentesPrimeiro(enviadas),
    });
  }

  Future<MockResponse> _enviarSolicitacao(
    String? token,
    Map<String, dynamic> corpo,
  ) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final username = (corpo['username'] ?? '').toString().trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9._-]{3,40}$').hasMatch(username)) {
      return _erro(400, 'VALIDACAO', 'Dados inválidos.', [
        {
          'campo': 'username',
          'mensagem': 'Use de 3 a 40 caracteres: letras, números, ponto, hífen ou sublinhado.',
        },
      ]);
    }

    final alvo = _usuarioPorUsername(username);
    if (alvo == null) {
      return _erro(404, 'USUARIO_NAO_ENCONTRADO', 'Usuário não encontrado.');
    }
    final alvoId = alvo['id'] as int;
    if (alvoId == meuId) {
      return _erro(
        400,
        'NAO_PODE_SI_MESMO',
        'Você não pode enviar solicitação para si mesmo.',
      );
    }
    if (_existeBloqueio(meuId, alvoId)) {
      return _erro(
        409,
        'BLOQUEADO',
        'Não é possível interagir com este usuário por causa de um bloqueio.',
      );
    }

    final existente = _amizadeDoPar(meuId, alvoId);
    int id;
    if (existente != null) {
      if (existente['status'] == 'P') {
        return _erro(
          409,
          'SOLICITACAO_DUPLICADA',
          'Já existe uma solicitação entre vocês.',
        );
      }
      if (existente['status'] == 'A') {
        return _erro(409, 'JA_SAO_AMIGOS', 'Vocês já são amigos.');
      }

      existente['solicitanteId'] = meuId;
      existente['destinatarioId'] = alvoId;
      existente['status'] = 'P';
      existente['criadoEm'] = _agoraIso();
      existente['respondidoEm'] = null;
      id = existente['id'] as int;
    } else {
      id = _dados['proxima_amizade_id'] as int;
      _dados['proxima_amizade_id'] = id + 1;
      _amizades.add({
        'id': id,
        'solicitanteId': meuId,
        'destinatarioId': alvoId,
        'status': 'P',
        'criadoEm': _agoraIso(),
        'respondidoEm': null,
      });
    }

    await _salva();
    return MockResponse(201, {
      'id': id,
      'status': 'P',
      'usuario': _publico(alvo),
    });
  }

  Future<MockResponse> _responderSolicitacao(
    String? token,
    int id,
    String acao,
  ) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final amizade = _amizadePorId(id);
    if (amizade == null || amizade['destinatarioId'] != meuId) {
      return _erro(
        404,
        'SOLICITACAO_NAO_ENCONTRADA',
        'Solicitação não encontrada.',
      );
    }
    if (amizade['status'] != 'P') {
      return _erro(
        409,
        'SOLICITACAO_NAO_PENDENTE',
        'Esta solicitação já foi respondida.',
      );
    }

    final solicitanteId = amizade['solicitanteId'] as int;
    if (_existeBloqueio(meuId, solicitanteId)) {
      return _erro(
        409,
        'BLOQUEADO',
        'Não é possível interagir com este usuário por causa de um bloqueio.',
      );
    }

    final novoStatus = acao == 'aceitar' ? 'A' : 'R';
    amizade['status'] = novoStatus;
    amizade['respondidoEm'] = _agoraIso();
    await _salva();

    final solicitante = _usuarioPorId(solicitanteId);
    return MockResponse(200, {
      'id': id,
      'status': novoStatus,
      'usuario': solicitante == null ? null : _publico(solicitante),
    });
  }

  Future<MockResponse> _cancelarSolicitacao(String? token, int id) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final amizade = _amizadePorId(id);
    if (amizade == null ||
        amizade['solicitanteId'] != meuId ||
        amizade['status'] != 'P') {
      return _erro(
        404,
        'SOLICITACAO_NAO_ENCONTRADA',
        'Solicitação não encontrada ou já respondida.',
      );
    }

    _amizades.remove(amizade);
    await _salva();
    return const MockResponse(204, null);
  }

  Future<MockResponse> _removerAmigo(String? token, int usuarioId) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final amizade = _amizadeDoPar(meuId, usuarioId);
    if (amizade == null || amizade['status'] != 'A') {
      return _erro(404, 'AMIZADE_NAO_ENCONTRADA', 'Vocês não são amigos.');
    }

    _amizades.remove(amizade);
    await _salva();
    return const MockResponse(204, null);
  }

  MockResponse _listarBloqueios(String? token) {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final bloqueios = <Map<String, dynamic>>[];

    for (final bloqueio in _bloqueios) {
      if (bloqueio['bloqueadorId'] != meuId) continue;
      final bloqueado = _usuarioPorId(bloqueio['bloqueadoId'] as int);
      if (bloqueado == null) continue;
      bloqueios.add({
        'usuario': _publico(bloqueado),
        'criadoEm': bloqueio['criadoEm'],
      });
    }

    bloqueios.sort(
      (a, b) => (a['usuario'] as Map)['nome'].toString().compareTo(
        (b['usuario'] as Map)['nome'].toString(),
      ),
    );
    return MockResponse(200, {'bloqueios': bloqueios});
  }

  Future<MockResponse> _bloquear(
    String? token,
    Map<String, dynamic> corpo,
  ) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final usuarioId = _comoInt(corpo['usuarioId']);
    if (usuarioId == null || usuarioId <= 0) {
      return _erro(400, 'VALIDACAO', 'Dados inválidos.', [
        {'campo': 'usuarioId', 'mensagem': 'Informe um usuário válido.'},
      ]);
    }
    if (usuarioId == meuId) {
      return _erro(
        400,
        'NAO_PODE_SI_MESMO',
        'Você não pode bloquear a si mesmo.',
      );
    }

    final alvo = _usuarioPorId(usuarioId);
    if (alvo == null) {
      return _erro(404, 'USUARIO_NAO_ENCONTRADO', 'Usuário não encontrado.');
    }

    final amizade = _amizadeDoPar(meuId, usuarioId);
    if (amizade != null) _amizades.remove(amizade);

    if (!_bloqueioDoPar(meuId, usuarioId)) {
      _bloqueios.add({
        'bloqueadorId': meuId,
        'bloqueadoId': usuarioId,
        'criadoEm': _agoraIso(),
      });
    }

    await _salva();
    return MockResponse(201, {'usuario': _publico(alvo)});
  }

  Future<MockResponse> _desbloquear(String? token, int usuarioId) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    _bloqueios.removeWhere(
      (item) =>
          item['bloqueadorId'] == meuId && item['bloqueadoId'] == usuarioId,
    );
    await _salva();
    return const MockResponse(204, null);
  }

  // ---------------------------------------------------------------------
  // Eventos (Fase 3)
  // ---------------------------------------------------------------------

  MockResponse _listarEventos(String? token, Map<String, String>? query) {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final erros = <Map<String, String>>[];
    final de = _lerDataMock(query?['de'], 'de', erros);
    final ate = _lerDataMock(query?['ate'], 'ate', erros);
    final pessoas = _lerPessoasMock(query?['pessoas'], erros);
    if (de != null && ate != null && ate.isBefore(de)) {
      erros.add({
        'campo': 'ate',
        'mensagem': 'A data final deve ser após a inicial.',
      });
    }
    if (erros.isNotEmpty) {
      return _erro(400, 'VALIDACAO', 'Dados inválidos.', erros);
    }

    final meuId = eu['id'] as int;
    final encontrados = <Map<String, dynamic>>[];

    for (final item in _eventos) {
      final evento = Map<String, dynamic>.from(item as Map);
      if (evento['status'] == 'CANCELADO') continue;
      if (!_eventoVisivel(evento, meuId)) continue;

      final inicio = _dataDoEvento(evento['inicioEm']);
      if (de != null && (inicio == null || inicio.isBefore(de))) continue;
      if (ate != null && (inicio == null || inicio.isAfter(ate))) continue;
      if (pessoas.isNotEmpty) {
        final atende = _convidadosDoEvento(evento['id'] as int)
            .any((convidado) => pessoas.contains(convidado['usuarioId']));
        if (!atende) continue;
      }
      encontrados.add(evento);
    }

    encontrados.sort((a, b) {
      final d1 = _dataDoEvento(a['inicioEm']);
      final d2 = _dataDoEvento(b['inicioEm']);
      if (d1 == null && d2 == null) {
        return (a['id'] as int).compareTo(b['id'] as int);
      }
      if (d1 == null) return 1;
      if (d2 == null) return -1;
      final comparacao = d1.compareTo(d2);
      if (comparacao != 0) return comparacao;
      return (a['id'] as int).compareTo(b['id'] as int);
    });

    return MockResponse(200, {
      'eventos': encontrados.map((e) => _eventoJson(e, meuId)).toList(),
    });
  }

  MockResponse _rankingPessoas(String? token) {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final limite = DateTime.now().toUtc().subtract(const Duration(days: 30));
    final contagem = <int, int>{};

    for (final item in _eventos) {
      final evento = Map<String, dynamic>.from(item as Map);
      if (evento['status'] == 'CANCELADO') continue;

      for (final convidado in _convidadosDoEvento(evento['id'] as int)) {
        if (convidado['convidadoPor'] != meuId) continue;
        if (convidado['papel'] != 'CONVIDADO') continue;

        final alvoId = convidado['usuarioId'] as int;
        if (alvoId == meuId) continue;

        final amizade = _amizadeDoPar(meuId, alvoId);
        if (amizade == null || amizade['status'] != 'A') continue;

        final criadoEm = DateTime.tryParse(
          (convidado['criadoEm'] ?? '').toString(),
        );
        if (criadoEm == null || criadoEm.toUtc().isBefore(limite)) continue;

        contagem.update(alvoId, (valor) => valor + 1, ifAbsent: () => 1);
      }
    }

    final pessoas = contagem.entries.map((entrada) {
      final usuario = _usuarioPorId(entrada.key);
      return {
        'usuarioId': entrada.key,
        'nome': usuario == null ? 'Usuário' : usuario['nome'],
        'contagem': entrada.value,
      };
    }).toList();

    pessoas.sort((a, b) {
      final porContagem = (b['contagem'] as int).compareTo(
        a['contagem'] as int,
      );
      if (porContagem != 0) return porContagem;
      return (a['nome'] as String).toLowerCase().compareTo(
        (b['nome'] as String).toLowerCase(),
      );
    });

    return MockResponse(200, {'pessoas': pessoas});
  }

  Future<MockResponse> _criarEvento(
    String? token,
    Map<String, dynamic> corpo,
  ) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final erros = <Map<String, String>>[];
    final titulo = (corpo['titulo'] ?? '').toString().trim();
    if (titulo.isEmpty || titulo.length > 160) {
      erros.add({
        'campo': 'titulo',
        'mensagem': 'Informe um título de até 160 caracteres.',
      });
    }
    final descricao = _textoOpcionalMock(
      corpo['descricao'],
      'descricao',
      2000,
      erros,
    );
    final inicio = _lerDataMock(corpo['inicioEm'], 'inicioEm', erros);
    final fim = _lerDataMock(corpo['fimEm'], 'fimEm', erros);
    final local = _lerLocalMock(corpo['local'], erros);
    final privado = _lerBoolMock(corpo['privado'], 'privado', true, erros);
    final permitir = _lerBoolMock(
      corpo['permitirMembrosConvidar'],
      'permitirMembrosConvidar',
      false,
      erros,
    );
    final convidadoIds = _lerConvidadoIdsMock(corpo['convidadoIds'], erros);

    if (inicio != null && fim != null && fim.isBefore(inicio)) {
      erros.add({
        'campo': 'fimEm',
        'mensagem': 'O fim deve ser posterior ao início.',
      });
    }
    if (erros.isNotEmpty) {
      return _erro(400, 'VALIDACAO', 'Dados inválidos.', erros);
    }

    final meuId = eu['id'] as int;
    final id = _dados['proximo_evento_id'] as int;
    _dados['proximo_evento_id'] = id + 1;
    final agora = _agoraIso();

    final evento = <String, dynamic>{
      'id': id,
      'titulo': titulo,
      'descricao': descricao,
      'inicioEm': _isoMock(inicio),
      'fimEm': _isoMock(fim),
      'local': local,
      'criadorId': meuId,
      'privado': privado,
      'permitirMembrosConvidar': permitir,
      'status': 'CONFIRMADO',
      'criadoEm': agora,
      'atualizadoEm': agora,
    };
    _eventos.add(evento);
    _convidadosEvento.add({
      'eventoId': id,
      'usuarioId': meuId,
      'convidadoPor': meuId,
      'papel': 'CRIADOR',
      'rsvp': 'VOU',
      'criadoEm': agora,
      'respondidoEm': agora,
    });

    final convite = _adicionarConvidados(evento, meuId, convidadoIds);
    await _salva();

    return MockResponse(201, {
      'evento': _eventoJson(evento, meuId),
      'convidadosAdicionados': convite['adicionados'],
      'convidadosIgnorados': convite['ignorados'],
    });
  }

  MockResponse _detalharEvento(String? token, int id) {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final evento = _eventoPorId(id);
    if (evento == null || !_eventoVisivel(evento, meuId)) {
      return _erro(404, 'EVENTO_NAO_ENCONTRADO', 'Evento não encontrado.');
    }

    return MockResponse(200, {'evento': _eventoJson(evento, meuId)});
  }

  Future<MockResponse> _atualizarEvento(
    String? token,
    int id,
    Map<String, dynamic> corpo,
  ) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final evento = _eventoPorId(id);
    if (evento == null || !_eventoVisivel(evento, meuId)) {
      return _erro(404, 'EVENTO_NAO_ENCONTRADO', 'Evento não encontrado.');
    }
    if (evento['criadorId'] != meuId) {
      return _erro(
        403,
        'SEM_PERMISSAO',
        'Você não tem permissão para esta ação.',
      );
    }

    final erros = <Map<String, String>>[];
    var titulo = (evento['titulo'] ?? '').toString();
    if (corpo.containsKey('titulo')) {
      titulo = (corpo['titulo'] ?? '').toString().trim();
      if (titulo.isEmpty || titulo.length > 160) {
        erros.add({
          'campo': 'titulo',
          'mensagem': 'Informe um título de até 160 caracteres.',
        });
      }
    }

    var descricao = evento['descricao'];
    if (corpo.containsKey('descricao')) {
      descricao = _textoOpcionalMock(
        corpo['descricao'],
        'descricao',
        2000,
        erros,
      );
    }

    var inicio = _dataDoEvento(evento['inicioEm']);
    if (corpo.containsKey('inicioEm')) {
      inicio = _lerDataMock(corpo['inicioEm'], 'inicioEm', erros);
    }

    var fim = _dataDoEvento(evento['fimEm']);
    if (corpo.containsKey('fimEm')) {
      fim = _lerDataMock(corpo['fimEm'], 'fimEm', erros);
    }

    var local = evento['local'];
    if (corpo.containsKey('local')) {
      local = _lerLocalMock(corpo['local'], erros);
    }

    if (inicio != null && fim != null && fim.isBefore(inicio)) {
      erros.add({
        'campo': 'fimEm',
        'mensagem': 'O fim deve ser posterior ao início.',
      });
    }
    if (erros.isNotEmpty) {
      return _erro(400, 'VALIDACAO', 'Dados inválidos.', erros);
    }

    evento['titulo'] = titulo;
    evento['descricao'] = descricao;
    evento['inicioEm'] = _isoMock(inicio);
    evento['fimEm'] = _isoMock(fim);
    evento['local'] = local;
    evento['atualizadoEm'] = _agoraIso();
    await _salva();

    return MockResponse(200, {'evento': _eventoJson(evento, meuId)});
  }

  Future<MockResponse> _cancelarEvento(String? token, int id) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final evento = _eventoPorId(id);
    if (evento == null || !_eventoVisivel(evento, meuId)) {
      return _erro(404, 'EVENTO_NAO_ENCONTRADO', 'Evento não encontrado.');
    }
    if (evento['criadorId'] != meuId) {
      return _erro(
        403,
        'SEM_PERMISSAO',
        'Você não tem permissão para esta ação.',
      );
    }

    if (evento['status'] != 'CANCELADO') {
      evento['status'] = 'CANCELADO';
      evento['atualizadoEm'] = _agoraIso();
      await _salva();
    }
    return const MockResponse(204, null);
  }

  Future<MockResponse> _configurarEvento(
    String? token,
    int id,
    Map<String, dynamic> corpo,
  ) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final evento = _eventoPorId(id);
    if (evento == null || !_eventoVisivel(evento, meuId)) {
      return _erro(404, 'EVENTO_NAO_ENCONTRADO', 'Evento não encontrado.');
    }
    if (evento['criadorId'] != meuId) {
      return _erro(
        403,
        'SEM_PERMISSAO',
        'Você não tem permissão para esta ação.',
      );
    }

    final erros = <Map<String, String>>[];
    final temPrivado = corpo.containsKey('privado');
    final temPermissao = corpo.containsKey('permitirMembrosConvidar');
    if (!temPrivado && !temPermissao) {
      erros.add({
        'campo': 'config',
        'mensagem': 'Informe privacidade ou permissão de convite.',
      });
    }
    final privado = temPrivado
        ? _lerBoolMock(corpo['privado'], 'privado', true, erros)
        : null;
    final permitir = temPermissao
        ? _lerBoolMock(
            corpo['permitirMembrosConvidar'],
            'permitirMembrosConvidar',
            false,
            erros,
          )
        : null;
    if (erros.isNotEmpty) {
      return _erro(400, 'VALIDACAO', 'Dados inválidos.', erros);
    }

    if (privado != null) evento['privado'] = privado;
    if (permitir != null) evento['permitirMembrosConvidar'] = permitir;
    evento['atualizadoEm'] = _agoraIso();
    await _salva();

    return MockResponse(200, {'evento': _eventoJson(evento, meuId)});
  }

  Future<MockResponse> _convidarEvento(
    String? token,
    int id,
    Map<String, dynamic> corpo,
  ) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final evento = _eventoPorId(id);
    if (evento == null || !_eventoVisivel(evento, meuId)) {
      return _erro(404, 'EVENTO_NAO_ENCONTRADO', 'Evento não encontrado.');
    }
    if (evento['status'] == 'CANCELADO') {
      return _erro(409, 'EVENTO_CANCELADO', 'Este evento foi cancelado.');
    }
    if (!_podeConvidarEvento(evento, meuId)) {
      return _erro(
        403,
        'SEM_PERMISSAO',
        'Você não tem permissão para esta ação.',
      );
    }

    final erros = <Map<String, String>>[];
    final ids = _lerConvidadoIdsMock(
      corpo['usuarioIds'] ?? corpo['convidadoIds'],
      erros,
    );
    if (ids.isEmpty && erros.isEmpty) {
      erros.add({
        'campo': 'usuarioIds',
        'mensagem': 'Selecione ao menos um amigo para convidar.',
      });
    }
    if (erros.isNotEmpty) {
      return _erro(400, 'VALIDACAO', 'Dados inválidos.', erros);
    }

    final convite = _adicionarConvidados(evento, meuId, ids);
    await _salva();
    return MockResponse(200, {
      'evento': _eventoJson(evento, meuId),
      'adicionados': convite['adicionados'],
      'ignorados': convite['ignorados'],
    });
  }

  Future<MockResponse> _convidarTodos(String? token, int id) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final evento = _eventoPorId(id);
    if (evento == null || !_eventoVisivel(evento, meuId)) {
      return _erro(404, 'EVENTO_NAO_ENCONTRADO', 'Evento não encontrado.');
    }
    if (evento['status'] == 'CANCELADO') {
      return _erro(409, 'EVENTO_CANCELADO', 'Este evento foi cancelado.');
    }
    if (!_podeConvidarEvento(evento, meuId)) {
      return _erro(
        403,
        'SEM_PERMISSAO',
        'Você não tem permissão para esta ação.',
      );
    }

    final convite = _adicionarConvidados(evento, meuId, _idsDosAmigos(meuId));
    await _salva();
    return MockResponse(200, {
      'evento': _eventoJson(evento, meuId),
      'adicionados': convite['adicionados'],
      'ignorados': convite['ignorados'],
    });
  }

  Future<MockResponse> _removerConvidado(
    String? token,
    int eventoId,
    int usuarioId,
  ) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final evento = _eventoPorId(eventoId);
    if (evento == null || !_eventoVisivel(evento, meuId)) {
      return _erro(404, 'EVENTO_NAO_ENCONTRADO', 'Evento não encontrado.');
    }
    if (evento['status'] == 'CANCELADO') {
      return _erro(409, 'EVENTO_CANCELADO', 'Este evento foi cancelado.');
    }
    if (evento['criadorId'] == usuarioId) {
      return _erro(
        400,
        'NAO_REMOVER_CRIADOR',
        'O criador não pode ser removido do próprio evento.',
      );
    }
    if (evento['criadorId'] != meuId && usuarioId != meuId) {
      return _erro(
        403,
        'SEM_PERMISSAO',
        'Você não tem permissão para esta ação.',
      );
    }

    final convidado = _convidadoDoEvento(eventoId, usuarioId);
    if (convidado == null) {
      return _erro(
        404,
        'CONVIDADO_NAO_ENCONTRADO',
        'Convidado não encontrado.',
      );
    }
    _convidadosEvento.remove(convidado);
    evento['atualizadoEm'] = _agoraIso();
    await _salva();

    if (evento['criadorId'] == meuId) {
      return MockResponse(200, {'evento': _eventoJson(evento, meuId)});
    }
    return const MockResponse(204, null);
  }

  Future<MockResponse> _responderRsvp(
    String? token,
    int id,
    Map<String, dynamic> corpo,
  ) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final rsvp = (corpo['rsvp'] ?? '').toString().trim().toUpperCase();
    if (rsvp != 'VOU' && rsvp != 'TALVEZ') {
      return _erro(400, 'VALIDACAO', 'Dados inválidos.', [
        {'campo': 'rsvp', 'mensagem': 'Informe VOU ou TALVEZ.'},
      ]);
    }

    final meuId = eu['id'] as int;
    final evento = _eventoPorId(id);
    if (evento == null || !_eventoVisivel(evento, meuId)) {
      return _erro(404, 'EVENTO_NAO_ENCONTRADO', 'Evento não encontrado.');
    }
    if (evento['status'] != 'CONFIRMADO') {
      return _erro(409, 'EVENTO_CANCELADO', 'Este evento foi cancelado.');
    }
    if (evento['criadorId'] == meuId && rsvp != 'VOU') {
      return _erro(
        400,
        'CRIADOR_RSVP_FIXO',
        'O criador do evento é sempre considerado confirmado.',
      );
    }

    final convidado = _convidadoDoEvento(id, meuId);
    if (convidado == null) {
      return _erro(404, 'EVENTO_NAO_ENCONTRADO', 'Evento não encontrado.');
    }

    convidado['rsvp'] = rsvp;
    convidado['respondidoEm'] = _agoraIso();
    evento['atualizadoEm'] = _agoraIso();
    await _salva();

    return MockResponse(200, {'evento': _eventoJson(evento, meuId)});
  }

  Map<String, dynamic> _eventoJson(Map<String, dynamic> evento, int eu) {
    final id = evento['id'] as int;
    final convidados = _convidadosDoEvento(id);
    var vou = 0;
    var talvez = 0;
    var semResposta = 0;
    for (final convidado in convidados) {
      switch (convidado['rsvp']) {
        case 'VOU':
          vou++;
          break;
        case 'TALVEZ':
          talvez++;
          break;
        default:
          semResposta++;
      }
    }

    final meu = _convidadoDoEvento(id, eu);
    final criador = _usuarioPorId(evento['criadorId'] as int);
    final local = evento['local'];

    return {
      'id': id,
      'titulo': evento['titulo'],
      'descricao': evento['descricao'],
      'inicioEm': evento['inicioEm'],
      'fimEm': evento['fimEm'],
      'local': local is Map ? Map<String, dynamic>.from(local) : null,
      'criador': criador == null ? null : _publico(criador),
      'privado': evento['privado'] == true,
      'permitirMembrosConvidar': evento['permitirMembrosConvidar'] == true,
      'status': evento['status'],
      'criadoEm': evento['criadoEm'],
      'atualizadoEm': evento['atualizadoEm'],
      'meuRsvp': meu?['rsvp'],
      'souCriador': evento['criadorId'] == eu,
      'podeConvidar': _podeConvidarEvento(evento, eu),
      'contagem': {'vou': vou, 'talvez': talvez, 'semResposta': semResposta},
      'convidados': convidados.map((convidado) {
        final usuario = _usuarioPorId(convidado['usuarioId'] as int);
        final por = _usuarioPorId(_comoInt(convidado['convidadoPor']) ?? 0);
        return {
          'usuario': usuario == null ? null : _publico(usuario),
          'papel': convidado['papel'],
          'rsvp': convidado['rsvp'],
          'convidadoPor': por == null ? null : _publico(por),
          'criadoEm': convidado['criadoEm'],
          'respondidoEm': convidado['respondidoEm'],
        };
      }).toList(),
    };
  }

  Map<String, dynamic> _adicionarConvidados(
    Map<String, dynamic> evento,
    int eu,
    List<int> ids,
  ) {
    final adicionados = <int>[];
    final ignorados = <Map<String, dynamic>>[];
    final eventoId = evento['id'] as int;
    final criadorId = evento['criadorId'] as int;

    for (final usuarioId in ids) {
      if (usuarioId == criadorId) {
        ignorados.add({'usuarioId': usuarioId, 'motivo': 'CRIADOR'});
        continue;
      }
      if (_usuarioPorId(usuarioId) == null) {
        ignorados.add({
          'usuarioId': usuarioId,
          'motivo': 'USUARIO_NAO_ENCONTRADO',
        });
        continue;
      }
      if (_convidadoDoEvento(eventoId, usuarioId) != null) {
        ignorados.add({'usuarioId': usuarioId, 'motivo': 'JA_CONVIDADO'});
        continue;
      }
      if (_existeBloqueio(eu, usuarioId) ||
          _existeBloqueio(criadorId, usuarioId)) {
        ignorados.add({'usuarioId': usuarioId, 'motivo': 'BLOQUEADO'});
        continue;
      }
      final amizade = _amizadeDoPar(eu, usuarioId);
      if (amizade == null || amizade['status'] != 'A') {
        ignorados.add({'usuarioId': usuarioId, 'motivo': 'NAO_E_AMIGO'});
        continue;
      }

      _convidadosEvento.add({
        'eventoId': eventoId,
        'usuarioId': usuarioId,
        'convidadoPor': eu,
        'papel': 'CONVIDADO',
        'rsvp': null,
        'criadoEm': _agoraIso(),
        'respondidoEm': null,
      });
      adicionados.add(usuarioId);
    }

    return {'adicionados': adicionados, 'ignorados': ignorados};
  }

  List<int> _idsDosAmigos(int eu) {
    final ids = <int>[];
    for (final amizade in _amizades) {
      if (amizade['status'] != 'A') continue;
      final solicitante = amizade['solicitanteId'] as int;
      final destinatario = amizade['destinatarioId'] as int;
      if (solicitante == eu) {
        ids.add(destinatario);
      } else if (destinatario == eu) {
        ids.add(solicitante);
      }
    }
    return ids;
  }

  bool _eventoVisivel(Map<String, dynamic> evento, int eu) {
    if (evento['criadorId'] == eu) return true;
    return _convidadoDoEvento(evento['id'] as int, eu) != null;
  }

  bool _podeConvidarEvento(Map<String, dynamic> evento, int eu) {
    return evento['criadorId'] == eu ||
        evento['permitirMembrosConvidar'] == true;
  }

  Map<String, dynamic>? _eventoPorId(int id) {
    for (final item in _eventos) {
      if (item['id'] == id) return item as Map<String, dynamic>;
    }
    return null;
  }

  List<Map<String, dynamic>> _convidadosDoEvento(int eventoId) {
    return _convidadosEvento
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['eventoId'] == eventoId)
        .toList();
  }

  Map<String, dynamic>? _convidadoDoEvento(int eventoId, int usuarioId) {
    for (final item in _convidadosEvento) {
      if (item['eventoId'] == eventoId && item['usuarioId'] == usuarioId) {
        return item as Map<String, dynamic>;
      }
    }
    return null;
  }

  String? _textoOpcionalMock(
    dynamic valor,
    String campo,
    int max,
    List<Map<String, String>> erros,
  ) {
    if (valor == null) return null;
    final texto = valor.toString().trim();
    if (texto.isEmpty) return null;
    if (texto.length > max) {
      erros.add({'campo': campo, 'mensagem': 'Use no máximo $max caracteres.'});
      return null;
    }
    return texto;
  }

  DateTime? _lerDataMock(
    dynamic valor,
    String campo,
    List<Map<String, String>> erros,
  ) {
    if (valor == null || valor.toString().trim().isEmpty) return null;
    final data = DateTime.tryParse(valor.toString());
    if (data == null) {
      erros.add({
        'campo': campo,
        'mensagem': 'Informe uma data válida em ISO-8601.',
      });
      return null;
    }
    return data.toUtc();
  }

  bool _lerBoolMock(
    dynamic valor,
    String campo,
    bool padrao,
    List<Map<String, String>> erros,
  ) {
    if (valor == null) return padrao;
    if (valor is bool) return valor;
    erros.add({'campo': campo, 'mensagem': 'Informe verdadeiro ou falso.'});
    return padrao;
  }

  List<int> _lerPessoasMock(dynamic valor, List<Map<String, String>> erros) {
    if (valor == null || valor.toString().trim().isEmpty) return <int>[];

    final ids = <int>[];
    for (final parte in valor.toString().split(',')) {
      final texto = parte.trim();
      if (texto.isEmpty) continue;
      final id = _comoInt(texto);
      if (id == null || id <= 0) {
        erros.add({
          'campo': 'pessoas',
          'mensagem': 'Informe uma lista de usuários válidos.',
        });
        continue;
      }
      if (!ids.contains(id)) ids.add(id);
    }
    if (ids.length > 50) {
      erros.add({
        'campo': 'pessoas',
        'mensagem': 'Selecione no máximo 50 pessoas por vez.',
      });
    }
    return ids;
  }

  List<int> _lerConvidadoIdsMock(
    dynamic valor,
    List<Map<String, String>> erros,
  ) {
    if (valor == null) return <int>[];
    if (valor is! List) {
      erros.add({
        'campo': 'convidadoIds',
        'mensagem': 'Envie uma lista de usuários.',
      });
      return <int>[];
    }

    final ids = <int>[];
    for (final item in valor) {
      final id = _comoInt(item);
      if (id == null || id <= 0) {
        erros.add({
          'campo': 'convidadoIds',
          'mensagem': 'A lista de convidados contém um usuário inválido.',
        });
        continue;
      }
      if (!ids.contains(id)) ids.add(id);
    }
    if (ids.length > 200) {
      erros.add({
        'campo': 'convidadoIds',
        'mensagem': 'Convide no máximo 200 pessoas por vez.',
      });
    }
    return ids;
  }

  Map<String, dynamic>? _lerLocalMock(
    dynamic valor,
    List<Map<String, String>> erros,
  ) {
    if (valor == null) return null;
    if (valor is! Map) {
      erros.add({'campo': 'local', 'mensagem': 'Informe um local válido.'});
      return null;
    }

    final nome = (valor['nome'] ?? '').toString().trim();
    if (nome.isEmpty || nome.length > 160) {
      erros.add({
        'campo': 'local.nome',
        'mensagem': 'Informe o nome do local com até 160 caracteres.',
      });
    }
    final endereco = _textoOpcionalMock(
      valor['endereco'],
      'local.endereco',
      300,
      erros,
    );
    final categoria = _textoOpcionalMock(
      valor['categoria'],
      'local.categoria',
      60,
      erros,
    );

    final distanciaBruta =
        valor['distanciaMetros'] ?? valor['distancia_metros'];
    double? distancia;
    if (distanciaBruta != null) {
      distancia = _comoDouble(distanciaBruta);
      if (distancia == null || distancia < 0) {
        erros.add({
          'campo': 'local.distanciaMetros',
          'mensagem': 'Informe uma distância válida em metros.',
        });
      }
    }

    final latitude = _comoDouble(valor['latitude']);
    final longitude = _comoDouble(valor['longitude']);
    if (latitude != null && (latitude < -90 || latitude > 90)) {
      erros.add({
        'campo': 'local.latitude',
        'mensagem': 'Informe uma latitude válida.',
      });
    }
    if (longitude != null && (longitude < -180 || longitude > 180)) {
      erros.add({
        'campo': 'local.longitude',
        'mensagem': 'Informe uma longitude válida.',
      });
    }

    final id = _dados['proximo_local_id'] as int;
    _dados['proximo_local_id'] = id + 1;

    return {
      'id': id,
      'nome': nome,
      'endereco': endereco,
      'categoria': categoria,
      'distanciaMetros': distancia,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  DateTime? _dataDoEvento(dynamic valor) {
    if (valor == null) return null;
    return DateTime.tryParse(valor.toString())?.toUtc();
  }

  String? _isoMock(DateTime? data) => data?.toUtc().toIso8601String();

  double? _comoDouble(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString());
  }

  // ---------------------------------------------------------------------
  // Estado auxiliar
  // ---------------------------------------------------------------------

  List<dynamic> get _usuarios => _dados['usuarios'] as List<dynamic>;
  List<dynamic> get _amizades => _dados['amizades'] as List<dynamic>;
  List<dynamic> get _bloqueios => _dados['bloqueios'] as List<dynamic>;
  List<dynamic> get _eventos => _dados['eventos'] as List<dynamic>;
  List<dynamic> get _convidadosEvento =>
      _dados['convidados_evento'] as List<dynamic>;

  Map<String, dynamic>? _usuarioPorId(int id) {
    for (final usuario in _usuarios) {
      if (usuario['id'] == id) return usuario as Map<String, dynamic>;
    }
    return null;
  }

  Map<String, dynamic>? _usuarioPorUsername(String username) {
    for (final usuario in _usuarios) {
      if (usuario['username'] == username) {
        return usuario as Map<String, dynamic>;
      }
    }
    return null;
  }

  Map<String, dynamic>? _usuarioDaSessao(String? token) {
    if (token == null || token.isEmpty) return null;
    final sessoes = _dados['sessoes'] as Map<String, dynamic>;
    final usuarioId = _comoInt(sessoes[token]);
    if (usuarioId == null) return null;
    return _usuarioPorId(usuarioId);
  }

  Map<String, dynamic>? _amizadeDoPar(int a, int b) {
    for (final amizade in _amizades) {
      final solicitante = amizade['solicitanteId'] as int;
      final destinatario = amizade['destinatarioId'] as int;
      if ((solicitante == a && destinatario == b) ||
          (solicitante == b && destinatario == a)) {
        return amizade as Map<String, dynamic>;
      }
    }
    return null;
  }

  Map<String, dynamic>? _amizadePorId(int id) {
    for (final amizade in _amizades) {
      if (amizade['id'] == id) return amizade as Map<String, dynamic>;
    }
    return null;
  }

  bool _existeBloqueio(int a, int b) {
    return _bloqueios.any((item) {
      final bloqueador = item['bloqueadorId'] as int;
      final bloqueado = item['bloqueadoId'] as int;
      return (bloqueador == a && bloqueado == b) ||
          (bloqueador == b && bloqueado == a);
    });
  }

  bool _bloqueioDoPar(int bloqueador, int bloqueado) {
    return _bloqueios.any(
      (item) =>
          item['bloqueadorId'] == bloqueador &&
          item['bloqueadoId'] == bloqueado,
    );
  }

  String _relacao(Map<String, dynamic>? amizade, int eu) {
    if (amizade == null) return 'nenhuma';
    switch (amizade['status']) {
      case 'A':
        return 'amigos';
      case 'P':
        return amizade['solicitanteId'] == eu
            ? 'solicitacao_enviada'
            : 'solicitacao_recebida';
      default:
        return 'nenhuma';
    }
  }

  String _criarSessao(Map<String, dynamic> usuario) {
    final aleatorio = Random().nextInt(1 << 31).toRadixString(16);
    final token =
        'mock-${usuario['id']}-${DateTime.now().microsecondsSinceEpoch}-$aleatorio';
    (_dados['sessoes'] as Map<String, dynamic>)[token] = usuario['id'];
    return token;
  }

  Map<String, dynamic> _sessaoResposta(
    Map<String, dynamic> usuario,
    String token,
  ) {
    final expiraEm = DateTime.now()
        .toUtc()
        .add(const Duration(days: 30))
        .toIso8601String();
    return {'token': token, 'expiraEm': expiraEm, 'usuario': _publico(usuario)};
  }

  Map<String, dynamic> _publico(Map<String, dynamic> usuario) {
    return {
      'id': usuario['id'],
      'nome': usuario['nome'],
      'username': usuario['username'],
    };
  }

  List<dynamic> _maisRecentesPrimeiro(List<Map<String, dynamic>> itens) {
    itens.sort(
      (a, b) => (b['criadoEm'] ?? '').toString().compareTo(
        (a['criadoEm'] ?? '').toString(),
      ),
    );
    return itens;
  }

  MockResponse _sessaoInvalida() {
    return _erro(401, 'SESSAO_EXPIRADA', 'Sessão expirada ou inválida.');
  }

  MockResponse _erro(
    int status,
    String code,
    String message, [
    dynamic details,
  ]) {
    final erro = <String, dynamic>{'code': code, 'message': message};
    if (details != null) erro['details'] = details;
    return MockResponse(status, {'error': erro});
  }

  Future<void> _salva() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveEstado, jsonEncode(_dados));
  }

  String _normalizaCaminho(String path) {
    final semQuery = path.split('?').first;
    if (semQuery.length > 1 && semQuery.endsWith('/')) {
      return semQuery.substring(0, semQuery.length - 1);
    }
    return semQuery;
  }

  String _agoraIso() => DateTime.now().toUtc().toIso8601String();

  int? _comoInt(dynamic valor) {
    if (valor == null) return null;
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor.toString());
  }
}
