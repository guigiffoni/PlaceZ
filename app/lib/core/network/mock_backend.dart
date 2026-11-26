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
    garante('proximo_enquete_id', 1);
    garante('proximo_opcao_enquete_id', 1);
    garante('proximo_conversa_id', 1);
    garante('proxima_mensagem_id', 1);
    garante('eventos', <dynamic>[]);
    garante('convidados_evento', <dynamic>[]);
    garante('enquetes', <dynamic>[]);
    garante('opcoes_enquete', <dynamic>[]);
    garante('votos_enquete', <dynamic>[]);
    garante('conversas', <dynamic>[]);
    garante('mensagens', <dynamic>[]);
    return alterou;
  }

  static Map<String, dynamic> _estadoInicial() {
    return {
      'proximo_usuario_id': 4,
      'proxima_amizade_id': 1,
      'proximo_evento_id': 1,
      'proximo_local_id': 1,
      'proximo_enquete_id': 1,
      'proximo_opcao_enquete_id': 1,
      'proximo_conversa_id': 1,
      'proxima_mensagem_id': 1,
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
      'enquetes': <dynamic>[],
      'opcoes_enquete': <dynamic>[],
      'votos_enquete': <dynamic>[],
      'conversas': <dynamic>[],
      'mensagens': <dynamic>[],
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
      case 'GET /eventos/rascunhos':
        return _listarRascunhos(token);
      case 'POST /eventos':
        return _criarEvento(token, corpo);
      case 'GET /calendario/pessoas-frequentes':
        return _rankingPessoas(token);
      case 'GET /conversas':
        return _listarConversas(token);
      case 'POST /conversas/diretas':
        return _criarConversaDireta(token, corpo);
    }

    final mensagensConversa = RegExp(r'^/conversas/(\d+)/mensagens$')
        .firstMatch(caminho);
    if (mensagensConversa != null) {
      final id = int.parse(mensagensConversa.group(1)!);
      if (method == 'GET') return _listarMensagens(token, id, query);
      if (method == 'POST') return _enviarMensagem(token, id, corpo);
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

    final enqueteEvento = RegExp(r'^/eventos/(\d+)/enquete$')
        .firstMatch(caminho);
    if (enqueteEvento != null) {
      final id = int.parse(enqueteEvento.group(1)!);
      if (method == 'GET') return _consultarEnquete(token, id);
      if (method == 'POST') return _criarEnquete(token, id, corpo);
    }

    final votosEnquete = RegExp(r'^/eventos/(\d+)/enquete/votos$')
        .firstMatch(caminho);
    if (method == 'PUT' && votosEnquete != null) {
      return _votarEnquete(token, int.parse(votosEnquete.group(1)!), corpo);
    }

    final melhorDiaEnquete = RegExp(r'^/eventos/(\d+)/enquete/melhor-dia$')
        .firstMatch(caminho);
    if (method == 'GET' && melhorDiaEnquete != null) {
      return _melhorDiaEnquete(token, int.parse(melhorDiaEnquete.group(1)!));
    }

    final aplicarEnquete = RegExp(
      r'^/eventos/(\d+)/enquete/aplicar-melhor-dia$',
    ).firstMatch(caminho);
    if (method == 'POST' && aplicarEnquete != null) {
      return _aplicarMelhorDia(token, int.parse(aplicarEnquete.group(1)!));
    }

    final chatEvento = RegExp(r'^/eventos/(\d+)/chat$').firstMatch(caminho);
    if (chatEvento != null) {
      final id = int.parse(chatEvento.group(1)!);
      if (method == 'GET') return _consultarChatEvento(token, id);
      if (method == 'POST') return _criarChatEvento(token, id);
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
      if (evento['status'] != 'CONFIRMADO') continue;
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

  MockResponse _listarRascunhos(String? token) {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final encontrados = <Map<String, dynamic>>[];
    for (final item in _eventos) {
      final evento = Map<String, dynamic>.from(item as Map);
      if (evento['status'] != 'RASCUNHO') continue;
      if (!_eventoVisivel(evento, meuId)) continue;
      encontrados.add(evento);
    }

    encontrados.sort((a, b) {
      final porData = (b['criadoEm'] ?? '').toString().compareTo(
        (a['criadoEm'] ?? '').toString(),
      );
      if (porData != 0) return porData;
      return (b['id'] as int).compareTo(a['id'] as int);
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

  // ---------------------------------------------------------------------
  // Chat 1:1 (Fase 6)
  // ---------------------------------------------------------------------

  MockResponse _listarConversas(String? token) {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final conversas = _conversas
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => _conversaVisivel(item, meuId))
        .map((item) => _conversaJson(item, meuId))
        .toList();

    conversas.sort((a, b) {
      final porData = (b['atualizadoEm'] ?? '').toString().compareTo(
        (a['atualizadoEm'] ?? '').toString(),
      );
      if (porData != 0) return porData;
      return (b['id'] as int).compareTo(a['id'] as int);
    });

    return MockResponse(200, {'conversas': conversas});
  }

  Future<MockResponse> _criarConversaDireta(
    String? token,
    Map<String, dynamic> corpo,
  ) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final outroId = _comoInt(corpo['usuarioId']);
    if (outroId == null || outroId <= 0) {
      return _erro(400, 'VALIDACAO', 'Dados inválidos.', [
        {'campo': 'usuarioId', 'mensagem': 'Informe um usuário válido.'},
      ]);
    }
    if (outroId == meuId) {
      return _erro(
        400,
        'NAO_PODE_SI_MESMO',
        'Você não pode conversar consigo mesmo.',
      );
    }
    if (_usuarioPorId(outroId) == null) {
      return _erro(404, 'USUARIO_NAO_ENCONTRADO', 'Usuário não encontrado.');
    }
    if (_existeBloqueio(meuId, outroId)) {
      return _erro(409, 'BLOQUEADO', 'Há um bloqueio entre vocês.');
    }
    final amizade = _amizadeDoPar(meuId, outroId);
    if (amizade == null || amizade['status'] != 'A') {
      return _erro(
        409,
        'CONVERSA_NAO_PERMITIDA',
        'Vocês precisam ser amigos para conversar.',
      );
    }

    var conversa = _conversaDoPar(meuId, outroId);
    var criada = false;
    if (conversa == null) {
      final id = _dados['proximo_conversa_id'] as int;
      _dados['proximo_conversa_id'] = id + 1;
      conversa = <String, dynamic>{
        'id': id,
        'tipo': 'DIRETA',
        'usuarioAId': meuId < outroId ? meuId : outroId,
        'usuarioBId': meuId < outroId ? outroId : meuId,
        'criadoEm': _agoraIso(),
      };
      _conversas.add(conversa);
      criada = true;
      await _salva();
    }

    return MockResponse(criada ? 201 : 200, {
      'conversa': _conversaJson(conversa, meuId),
    });
  }

  MockResponse _listarMensagens(
    String? token,
    int conversaId,
    Map<String, String>? query,
  ) {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final conversa = _conversaPorId(conversaId);
    if (conversa == null || !_conversaVisivel(conversa, meuId)) {
      return _erro(404, 'CONVERSA_NAO_ENCONTRADA', 'Conversa não encontrada.');
    }

    final afterId = _comoInt(query?['afterId']);
    final mensagens = _mensagens
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where(
          (item) =>
              item['conversaId'] == conversaId &&
              (afterId == null || (item['id'] as int) > afterId),
        )
        .map((item) => _mensagemJson(item))
        .toList();

    mensagens.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    final limitadas = mensagens.length > 200
        ? mensagens.sublist(mensagens.length - 200)
        : mensagens;

    return MockResponse(200, {
      'mensagens': limitadas,
      'ultimaId': limitadas.isEmpty ? afterId ?? 0 : limitadas.last['id'],
    });
  }

  Future<MockResponse> _enviarMensagem(
    String? token,
    int conversaId,
    Map<String, dynamic> corpo,
  ) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final conversa = _conversaPorId(conversaId);
    if (conversa == null || !_conversaVisivel(conversa, meuId)) {
      return _erro(404, 'CONVERSA_NAO_ENCONTRADA', 'Conversa não encontrada.');
    }

    final texto = (corpo['texto'] ?? '').toString().trim();
    if (texto.isEmpty || texto.length > 2000) {
      return _erro(400, 'VALIDACAO', 'Dados inválidos.', [
        {
          'campo': 'texto',
          'mensagem': 'Informe uma mensagem entre 1 e 2000 caracteres.',
        },
      ]);
    }

    if (conversa['tipo'] != 'EVENTO') {
      final outroId = _outroDaConversa(conversa, meuId);
      if (_existeBloqueio(meuId, outroId)) {
        return _erro(
          409,
          'CONVERSA_BLOQUEADA',
          'Não é possível enviar mensagens enquanto houver bloqueio.',
        );
      }
      final amizade = _amizadeDoPar(meuId, outroId);
      if (amizade == null || amizade['status'] != 'A') {
        return _erro(
          409,
          'CONVERSA_NAO_PERMITIDA',
          'Vocês precisam ser amigos para conversar.',
        );
      }
    }

    final id = _dados['proxima_mensagem_id'] as int;
    _dados['proxima_mensagem_id'] = id + 1;
    final mensagem = <String, dynamic>{
      'id': id,
      'conversaId': conversaId,
      'autorId': meuId,
      'texto': texto,
      'criadoEm': _agoraIso(),
    };
    _mensagens.add(mensagem);
    await _salva();

    return MockResponse(201, {'mensagem': _mensagemJson(mensagem)});
  }

  Map<String, dynamic> _conversaJson(Map<String, dynamic> conversa, int eu) {
    final tipo = (conversa['tipo'] ?? 'DIRETA').toString();
    final ultima = _ultimaMensagem(conversa['id'] as int);
    Map<String, dynamic>? outroJson;
    String? titulo;
    var bloqueada = false;
    var podeEnviar = true;

    if (tipo == 'EVENTO') {
      final evento = _eventoPorId(conversa['eventoId'] as int);
      titulo = evento?['titulo']?.toString();
    } else {
      final outroId = _outroDaConversa(conversa, eu);
      final outro = _usuarioPorId(outroId);
      outroJson = outro == null ? null : _publico(outro);
      bloqueada = _existeBloqueio(eu, outroId);
      final amizade = _amizadeDoPar(eu, outroId);
      podeEnviar = !bloqueada && amizade != null && amizade['status'] == 'A';
    }

    return {
      'id': conversa['id'],
      'tipo': tipo,
      'eventoId': conversa['eventoId'],
      'titulo': titulo,
      'outroUsuario': outroJson,
      'ultimaMensagem': ultima == null
          ? null
          : {
              'id': ultima['id'],
              'texto': ultima['texto'],
              'autorId': ultima['autorId'],
              'criadoEm': ultima['criadoEm'],
            },
      'criadoEm': conversa['criadoEm'],
      'atualizadoEm': ultima?['criadoEm'] ?? conversa['criadoEm'],
      'bloqueada': bloqueada,
      'podeEnviar': podeEnviar,
    };
  }

  Map<String, dynamic> _mensagemJson(Map<String, dynamic> mensagem) {
    final autor = _usuarioPorId(mensagem['autorId'] as int);
    return {
      'id': mensagem['id'],
      'conversaId': mensagem['conversaId'],
      'autor': autor == null ? null : _publico(autor),
      'texto': mensagem['texto'],
      'criadoEm': mensagem['criadoEm'],
    };
  }

  int _outroDaConversa(Map<String, dynamic> conversa, int eu) {
    return conversa['usuarioAId'] == eu
        ? conversa['usuarioBId'] as int
        : conversa['usuarioAId'] as int;
  }

  Map<String, dynamic>? _conversaDoPar(int a, int b) {
    final menor = a < b ? a : b;
    final maior = a < b ? b : a;
    for (final item in _conversas) {
      if (item['tipo'] == 'DIRETA' &&
          item['usuarioAId'] == menor &&
          item['usuarioBId'] == maior) {
        return item as Map<String, dynamic>;
      }
    }
    return null;
  }

  Map<String, dynamic>? _conversaPorId(int id) {
    for (final item in _conversas) {
      if (item['id'] == id) return item as Map<String, dynamic>;
    }
    return null;
  }

  bool _conversaVisivel(Map<String, dynamic> conversa, int eu) {
    if (conversa['tipo'] == 'EVENTO') {
      final evento = _eventoPorId(conversa['eventoId'] as int);
      return evento != null && _eventoVisivel(evento, eu);
    }
    return conversa['usuarioAId'] == eu || conversa['usuarioBId'] == eu;
  }

  Map<String, dynamic>? _conversaDoEvento(int eventoId) {
    for (final item in _conversas) {
      if (item['tipo'] == 'EVENTO' && item['eventoId'] == eventoId) {
        return item as Map<String, dynamic>;
      }
    }
    return null;
  }

  Future<MockResponse> _criarChatEvento(String? token, int eventoId) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final evento = _eventoPorId(eventoId);
    if (evento == null) {
      return _erro(404, 'EVENTO_NAO_ENCONTRADO', 'Evento não encontrado.');
    }
    if (evento['criadorId'] != meuId) {
      return _erro(
        403,
        'SEM_PERMISSAO',
        'Você não tem permissão para esta ação.',
      );
    }
    if (evento['status'] == 'CANCELADO') {
      return _erro(409, 'EVENTO_CANCELADO', 'Este evento foi cancelado.');
    }

    var conversa = _conversaDoEvento(eventoId);
    var criada = false;
    if (conversa == null) {
      final id = _dados['proximo_conversa_id'] as int;
      _dados['proximo_conversa_id'] = id + 1;
      conversa = <String, dynamic>{
        'id': id,
        'tipo': 'EVENTO',
        'eventoId': eventoId,
        'criadoEm': _agoraIso(),
      };
      _conversas.add(conversa);
      criada = true;
      await _salva();
    }

    return MockResponse(criada ? 201 : 200, {
      'conversa': _conversaJson(conversa, meuId),
    });
  }

  MockResponse _consultarChatEvento(String? token, int eventoId) {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final evento = _eventoPorId(eventoId);
    if (evento == null || !_eventoVisivel(evento, meuId)) {
      return _erro(404, 'EVENTO_NAO_ENCONTRADO', 'Evento não encontrado.');
    }

    final conversa = _conversaDoEvento(eventoId);
    if (conversa == null) {
      return _erro(
        404,
        'CHAT_NAO_ENCONTRADO',
        'Este evento ainda não tem chat.',
      );
    }
    return MockResponse(200, {'conversa': _conversaJson(conversa, meuId)});
  }

  Map<String, dynamic>? _ultimaMensagem(int conversaId) {
    Map<String, dynamic>? ultima;
    for (final item in _mensagens) {
      final mensagem = item as Map<String, dynamic>;
      if (mensagem['conversaId'] != conversaId) continue;
      if (ultima == null || (mensagem['id'] as int) > (ultima['id'] as int)) {
        ultima = mensagem;
      }
    }
    return ultima;
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
    final rascunho = _lerBoolMock(corpo['rascunho'], 'rascunho', false, erros);
    final convidadoIds = _lerConvidadoIdsMock(corpo['convidadoIds'], erros);

    if (!rascunho && inicio == null) {
      erros.add({
        'campo': 'inicioEm',
        'mensagem': 'Informe a data de início do evento.',
      });
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

    final meuId = eu['id'] as int;
    final id = _dados['proximo_evento_id'] as int;
    _dados['proximo_evento_id'] = id + 1;
    final agora = _agoraIso();

    final evento = <String, dynamic>{
      'id': id,
      'titulo': titulo,
      'descricao': descricao,
      'inicioEm': rascunho ? null : _isoMock(inicio),
      'fimEm': rascunho ? null : _isoMock(fim),
      'local': local,
      'criadorId': meuId,
      'privado': privado,
      'permitirMembrosConvidar': permitir,
      'status': rascunho ? 'RASCUNHO' : 'CONFIRMADO',
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
    if (evento['status'] == 'RASCUNHO') {
      return _erro(
        409,
        'EVENTO_NAO_CONFIRMADO',
        'O evento ainda não foi confirmado.',
      );
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

  MockResponse _consultarEnquete(String? token, int eventoId) {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final evento = _eventoPorId(eventoId);
    if (evento == null || !_eventoVisivel(evento, meuId)) {
      return _erro(404, 'EVENTO_NAO_ENCONTRADO', 'Evento não encontrado.');
    }

    final enquete = _enqueteDoEvento(eventoId);
    if (enquete == null) {
      return _erro(
        404,
        'ENQUETE_NAO_ENCONTRADA',
        'Combinação de dias não encontrada.',
      );
    }
    return MockResponse(200, _consultaEnqueteJson(enquete, meuId));
  }

  Future<MockResponse> _criarEnquete(
    String? token,
    int eventoId,
    Map<String, dynamic> corpo,
  ) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final erros = <Map<String, String>>[];
    final dataInicio = _lerDiaMock(corpo['dataInicio'], 'dataInicio', erros);
    final dataFim = _lerDiaMock(corpo['dataFim'], 'dataFim', erros);
    final diasSemana = _lerDiasSemanaMock(corpo['diasSemana'], erros);
    final horaInicio = _lerHoraMock(corpo['horaInicio'], 'horaInicio', erros);
    final horaFim = _lerHoraMock(corpo['horaFim'], 'horaFim', erros);
    final fuso = _lerOffsetMock(corpo['fusoOffsetMinutos'], erros);

    if (dataInicio != null &&
        dataFim != null &&
        dataFim.compareTo(dataInicio) < 0) {
      erros.add({
        'campo': 'dataFim',
        'mensagem': 'A data final deve ser igual ou posterior à inicial.',
      });
    }
    if (horaInicio != null &&
        horaFim != null &&
        horaFim.compareTo(horaInicio) <= 0) {
      erros.add({
        'campo': 'horaFim',
        'mensagem': 'O horário final deve ser posterior ao inicial.',
      });
    }
    if (erros.isNotEmpty) {
      return _erro(400, 'VALIDACAO', 'Dados inválidos.', erros);
    }

    final inicio = _diaUtc(dataInicio!);
    final fim = _diaUtc(dataFim!);
    final dias = <DateTime>[];
    for (
      var cursor = inicio;
      !cursor.isAfter(fim);
      cursor = cursor.add(const Duration(days: 1))
    ) {
      dias.add(cursor);
    }
    if (dias.length > 60) {
      return _erro(400, 'VALIDACAO', 'Dados inválidos.', [
        {
          'campo': 'dataFim',
          'mensagem': 'O intervalo pode ter no máximo 60 dias.',
        },
      ]);
    }

    final datas = dias
        .where((data) => diasSemana.contains(data.weekday))
        .toList();
    if (datas.isEmpty) {
      return _erro(400, 'VALIDACAO', 'Dados inválidos.', [
        {
          'campo': 'diasSemana',
          'mensagem':
              'Nenhuma data do intervalo corresponde aos dias escolhidos.',
        },
      ]);
    }

    final meuId = eu['id'] as int;
    final evento = _eventoPorId(eventoId);
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
    if (evento['status'] != 'RASCUNHO') {
      return _erro(
        409,
        'EVENTO_NAO_ESTA_EM_RASCUNHO',
        'A combinação só pode ser alterada enquanto o evento está em rascunho.',
      );
    }
    if (_enqueteDoEvento(eventoId) != null) {
      return _erro(
        409,
        'ENQUETE_EXISTENTE',
        'Este evento já tem uma combinação de dias.',
      );
    }

    final enqueteId = _dados['proximo_enquete_id'] as int;
    _dados['proximo_enquete_id'] = enqueteId + 1;
    final enquete = <String, dynamic>{
      'id': enqueteId,
      'eventoId': eventoId,
      'dataInicio': dataInicio,
      'dataFim': dataFim,
      'diasSemana': diasSemana,
      'horaInicio': horaInicio,
      'horaFim': horaFim,
      'fusoOffsetMinutos': fuso,
    };
    _enquetes.add(enquete);

    for (final data in datas) {
      final opcaoId = _dados['proximo_opcao_enquete_id'] as int;
      _dados['proximo_opcao_enquete_id'] = opcaoId + 1;
      _opcoesEnquete.add({
        'id': opcaoId,
        'enqueteId': enqueteId,
        'data': _isoDia(data),
        'horaInicio': horaInicio,
        'horaFim': horaFim,
      });
    }

    await _salva();
    return MockResponse(201, _consultaEnqueteJson(enquete, meuId));
  }

  Future<MockResponse> _votarEnquete(
    String? token,
    int eventoId,
    Map<String, dynamic> corpo,
  ) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final evento = _eventoPorId(eventoId);
    if (evento == null || !_eventoVisivel(evento, meuId)) {
      return _erro(404, 'EVENTO_NAO_ENCONTRADO', 'Evento não encontrado.');
    }
    if (evento['status'] != 'RASCUNHO') {
      return _erro(
        409,
        'EVENTO_NAO_ESTA_EM_RASCUNHO',
        'A combinação só pode ser alterada enquanto o evento está em rascunho.',
      );
    }

    final enquete = _enqueteDoEvento(eventoId);
    if (enquete == null) {
      return _erro(
        404,
        'ENQUETE_NAO_ENCONTRADA',
        'Combinação de dias não encontrada.',
      );
    }

    final entrada = corpo['votos'];
    if (entrada is! List || entrada.isEmpty) {
      return _erro(400, 'VALIDACAO', 'Dados inválidos.', [
        {
          'campo': 'votos',
          'mensagem': 'Informe ao menos um voto de disponibilidade.',
        },
      ]);
    }

    final porOpcao = <int, String>{};
    for (final item in entrada) {
      if (item is! Map) {
        return _erro(400, 'VALIDACAO', 'Dados inválidos.', [
          {'campo': 'votos', 'mensagem': 'Voto inválido.'},
        ]);
      }
      final opcaoId = _comoInt(item['opcaoId']);
      final status = (item['status'] ?? '').toString().toUpperCase();
      if (opcaoId == null || opcaoId <= 0) {
        return _erro(400, 'VALIDACAO', 'Dados inválidos.', [
          {'campo': 'votos', 'mensagem': 'Informe uma opção de data válida.'},
        ]);
      }
      if (status != 'DISPONIVEL' && status != 'INDISPONIVEL') {
        return _erro(400, 'VALIDACAO', 'Dados inválidos.', [
          {
            'campo': 'votos',
            'mensagem': 'O voto deve ser DISPONIVEL ou INDISPONIVEL.',
          },
        ]);
      }
      porOpcao[opcaoId] = status;
    }

    final enqueteId = enquete['id'] as int;
    final idsValidos = _opcoesEnquete
        .where((item) => item['enqueteId'] == enqueteId)
        .map((item) => item['id'] as int)
        .toSet();
    final invalidos = porOpcao.keys.where((id) => !idsValidos.contains(id));
    if (invalidos.isNotEmpty) {
      return _erro(400, 'VALIDACAO', 'Dados inválidos.', [
        {
          'campo': 'votos',
          'mensagem':
              'Opções inválidas para esta combinação: ${invalidos.join(', ')}.',
        },
      ]);
    }

    for (final voto in porOpcao.entries) {
      Map<String, dynamic>? existente;
      for (final item in _votosEnquete) {
        final mapa = item as Map<String, dynamic>;
        if (mapa['opcaoId'] == voto.key && mapa['usuarioId'] == meuId) {
          existente = mapa;
          break;
        }
      }
      if (existente == null) {
        _votosEnquete.add({
          'opcaoId': voto.key,
          'usuarioId': meuId,
          'status': voto.value,
        });
      } else {
        existente['status'] = voto.value;
      }
    }

    await _salva();
    return MockResponse(200, _consultaEnqueteJson(enquete, meuId));
  }

  MockResponse _melhorDiaEnquete(String? token, int eventoId) {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final evento = _eventoPorId(eventoId);
    if (evento == null || !_eventoVisivel(evento, meuId)) {
      return _erro(404, 'EVENTO_NAO_ENCONTRADO', 'Evento não encontrado.');
    }
    final enquete = _enqueteDoEvento(eventoId);
    if (enquete == null) {
      return _erro(
        404,
        'ENQUETE_NAO_ENCONTRADA',
        'Combinação de dias não encontrada.',
      );
    }

    final consulta = _consultaEnqueteJson(enquete, meuId);
    return MockResponse(200, {'melhorDia': consulta['melhorDia']});
  }

  Future<MockResponse> _aplicarMelhorDia(String? token, int eventoId) async {
    final eu = _usuarioDaSessao(token);
    if (eu == null) return _sessaoInvalida();

    final meuId = eu['id'] as int;
    final evento = _eventoPorId(eventoId);
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
    if (evento['status'] != 'RASCUNHO') {
      return _erro(
        409,
        'EVENTO_NAO_ESTA_EM_RASCUNHO',
        'A combinação só pode ser alterada enquanto o evento está em rascunho.',
      );
    }

    final enquete = _enqueteDoEvento(eventoId);
    if (enquete == null) {
      return _erro(
        404,
        'ENQUETE_NAO_ENCONTRADA',
        'Combinação de dias não encontrada.',
      );
    }

    final consulta = _consultaEnqueteJson(enquete, meuId);
    final melhor = consulta['melhorDia'];
    if (melhor is! Map || (_comoInt(melhor['disponiveis']) ?? 0) == 0) {
      return _erro(
        409,
        'SEM_DISPONIBILIDADE',
        'Nenhum participante marcou disponibilidade para a melhor data.',
      );
    }

    final data = _diaUtc(melhor['data'] as String);
    final inicio = (melhor['horaInicio'] as String).split(':');
    final fim = (melhor['horaFim'] as String).split(':');
    final offset = _comoInt(enquete['fusoOffsetMinutos']) ?? 0;

    final inicioUtc = DateTime.utc(
      data.year,
      data.month,
      data.day,
      int.parse(inicio[0]),
      int.parse(inicio[1]),
    ).subtract(Duration(minutes: offset));
    final fimUtc = DateTime.utc(
      data.year,
      data.month,
      data.day,
      int.parse(fim[0]),
      int.parse(fim[1]),
    ).subtract(Duration(minutes: offset));

    evento['inicioEm'] = _isoMock(inicioUtc);
    evento['fimEm'] = _isoMock(fimUtc);
    evento['status'] = 'CONFIRMADO';
    evento['atualizadoEm'] = _agoraIso();
    await _salva();

    return MockResponse(200, {
      'evento': _eventoJson(evento, meuId),
      ...consulta,
    });
  }

  Map<String, dynamic> _consultaEnqueteJson(
    Map<String, dynamic> enquete,
    int eu,
  ) {
    final enqueteId = enquete['id'] as int;
    final opcoes = _opcoesEnquete
        .where((item) => item['enqueteId'] == enqueteId)
        .map((item) {
          final opcao = Map<String, dynamic>.from(item as Map);
          final votos = _votosEnquete
              .where((voto) => voto['opcaoId'] == opcao['id'])
              .toList();
          var disponiveis = 0;
          var indisponiveis = 0;
          String? meuVoto;
          for (final voto in votos) {
            if (voto['status'] == 'DISPONIVEL') {
              disponiveis++;
            } else if (voto['status'] == 'INDISPONIVEL') {
              indisponiveis++;
            }
            if (voto['usuarioId'] == eu) {
              meuVoto = voto['status'] as String?;
            }
          }
          final total = disponiveis + indisponiveis;
          return <String, dynamic>{
            'id': opcao['id'],
            'data': opcao['data'],
            'horaInicio': opcao['horaInicio'],
            'horaFim': opcao['horaFim'],
            'disponiveis': disponiveis,
            'indisponiveis': indisponiveis,
            'totalVotos': total,
            'percentual': total == 0 ? 0 : (disponiveis * 100 / total).round(),
            'meuVoto': meuVoto,
          };
        })
        .toList();

    opcoes.sort((a, b) {
      final porData = (a['data'] as String).compareTo(b['data'] as String);
      if (porData != 0) return porData;
      return (a['horaInicio'] as String).compareTo(b['horaInicio'] as String);
    });

    return {
      'enquete': {
        'id': enqueteId,
        'eventoId': enquete['eventoId'],
        'dataInicio': enquete['dataInicio'],
        'dataFim': enquete['dataFim'],
        'diasSemana': enquete['diasSemana'],
        'horaInicio': enquete['horaInicio'],
        'horaFim': enquete['horaFim'],
        'fusoOffsetMinutos': enquete['fusoOffsetMinutos'],
        'opcoes': opcoes,
      },
      'melhorDia': _melhorOpcaoMock(opcoes),
    };
  }

  Map<String, dynamic>? _melhorOpcaoMock(List<Map<String, dynamic>> opcoes) {
    if (opcoes.isEmpty) return null;

    final agora = DateTime.now().toUtc();
    final hoje = DateTime.utc(agora.year, agora.month, agora.day);
    int distancia(Map<String, dynamic> opcao) {
      return _diaUtc(opcao['data'] as String).difference(hoje).inDays;
    }

    var melhor = opcoes.first;
    for (final opcao in opcoes.skip(1)) {
      final disponiveisOpcao = _comoInt(opcao['disponiveis']) ?? 0;
      final disponiveisMelhor = _comoInt(melhor['disponiveis']) ?? 0;
      if (disponiveisOpcao > disponiveisMelhor) {
        melhor = opcao;
        continue;
      }
      if (disponiveisOpcao < disponiveisMelhor) continue;

      final distanciaOpcao = distancia(opcao).abs();
      final distanciaMelhor = distancia(melhor).abs();
      if (distanciaOpcao < distanciaMelhor) {
        melhor = opcao;
        continue;
      }
      if (distanciaOpcao > distanciaMelhor) continue;

      final futuraOpcao = distancia(opcao) >= 0;
      final futuraMelhor = distancia(melhor) >= 0;
      if (futuraOpcao && !futuraMelhor) {
        melhor = opcao;
      } else if (futuraOpcao == futuraMelhor &&
          (opcao['data'] as String).compareTo(melhor['data'] as String) < 0) {
        melhor = opcao;
      }
    }
    return melhor;
  }

  Map<String, dynamic>? _enqueteDoEvento(int eventoId) {
    for (final item in _enquetes) {
      if (item['eventoId'] == eventoId) {
        return item as Map<String, dynamic>;
      }
    }
    return null;
  }

  String? _lerDiaMock(
    dynamic valor,
    String campo,
    List<Map<String, String>> erros,
  ) {
    final texto = (valor ?? '').toString().trim();
    final partes = texto.split('-');
    if (partes.length != 3 ||
        partes[0].length != 4 ||
        partes[1].length != 2 ||
        partes[2].length != 2) {
      erros.add({
        'campo': campo,
        'mensagem': 'Informe a data no formato AAAA-MM-DD.',
      });
      return null;
    }
    final data = DateTime.tryParse('${texto}T00:00:00Z');
    if (data == null || _isoDia(data) != texto) {
      erros.add({'campo': campo, 'mensagem': 'Informe uma data válida.'});
      return null;
    }
    return texto;
  }

  String? _lerHoraMock(
    dynamic valor,
    String campo,
    List<Map<String, String>> erros,
  ) {
    final texto = (valor ?? '').toString().trim();
    final partes = texto.split(':');
    if (partes.length != 2 || partes[0].length != 2 || partes[1].length != 2) {
      erros.add({
        'campo': campo,
        'mensagem': 'Informe o horário no formato HH:MM.',
      });
      return null;
    }
    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);
    if (hora == null ||
        minuto == null ||
        hora < 0 ||
        hora > 23 ||
        minuto < 0 ||
        minuto > 59) {
      erros.add({
        'campo': campo,
        'mensagem': 'Informe o horário no formato HH:MM.',
      });
      return null;
    }
    return texto;
  }

  List<int> _lerDiasSemanaMock(dynamic valor, List<Map<String, String>> erros) {
    if (valor is! List || valor.isEmpty) {
      erros.add({
        'campo': 'diasSemana',
        'mensagem': 'Selecione ao menos um dia da semana.',
      });
      return const [];
    }
    final dias = <int>[];
    for (final item in valor) {
      final dia = _comoInt(item);
      if (dia == null || dia < 1 || dia > 7) {
        erros.add({
          'campo': 'diasSemana',
          'mensagem':
              'Os dias da semana devem estar entre 1 (segunda) e 7 (domingo).',
        });
        continue;
      }
      if (!dias.contains(dia)) dias.add(dia);
    }
    dias.sort();
    return dias;
  }

  int _lerOffsetMock(dynamic valor, List<Map<String, String>> erros) {
    if (valor == null || valor == '') return 0;
    final numero = _comoInt(valor);
    if (numero == null || numero < -720 || numero > 840) {
      erros.add({
        'campo': 'fusoOffsetMinutos',
        'mensagem': 'Informe o fuso em minutos entre -720 e 840.',
      });
      return 0;
    }
    return numero;
  }

  DateTime _diaUtc(String data) => DateTime.parse('${data}T00:00:00Z');

  String _isoDia(DateTime data) =>
      data.toUtc().toIso8601String().substring(0, 10);

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
  List<dynamic> get _enquetes => _dados['enquetes'] as List<dynamic>;
  List<dynamic> get _opcoesEnquete => _dados['opcoes_enquete'] as List<dynamic>;
  List<dynamic> get _votosEnquete => _dados['votos_enquete'] as List<dynamic>;
  List<dynamic> get _conversas => _dados['conversas'] as List<dynamic>;
  List<dynamic> get _mensagens => _dados['mensagens'] as List<dynamic>;

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
