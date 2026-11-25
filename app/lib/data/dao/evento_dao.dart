import 'package:sqflite/sqflite.dart';

import '../db.dart';
import '../models/amizade.dart';
import '../models/evento.dart';

/// Cache local dos eventos visíveis ao usuário.
///
/// O Oracle é a fonte de verdade; este DAO só sustenta leitura rápida e o
/// fallback quando a API está indisponível.
class EventoDao {
  Future<void> salvarEventos(List<Evento> eventos, {int? usuarioId}) async {
    final db = await BancoApp.instancia.database;
    final agora = DateTime.now().toUtc().millisecondsSinceEpoch;
    final ids = eventos
        .map((evento) => evento.id)
        .whereType<int>()
        .toList(growable: false);

    await db.transaction((txn) async {
      if (ids.isEmpty) {
        await txn.delete('cache_convidado');
        await txn.delete('cache_evento');
      } else {
        final marcadores = List.filled(ids.length, '?').join(',');
        final removidos = await txn.query(
          'cache_evento',
          columns: ['id'],
          where: 'id NOT IN ($marcadores)',
          whereArgs: ids,
        );
        for (final linha in removidos) {
          await txn.delete(
            'cache_convidado',
            where: 'evento_id = ?',
            whereArgs: [linha['id']],
          );
        }
        await txn.delete(
          'cache_evento',
          where: 'id NOT IN ($marcadores)',
          whereArgs: ids,
        );
      }

      for (final evento in eventos) {
        await _salvarEvento(txn, evento, agora);
      }
    });
  }

  Future<void> salvarEvento(Evento evento, {int? usuarioId}) async {
    final db = await BancoApp.instancia.database;
    final agora = DateTime.now().toUtc().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await _salvarEvento(txn, evento, agora);
      if (evento.id != null) {
        await txn.delete(
          'cache_convidado',
          where: 'evento_id = ?',
          whereArgs: [evento.id],
        );
      }
      await _salvarConvidados(txn, evento, agora);
    });
  }

  Future<List<Evento>> carregarEventos({int? usuarioId}) async {
    final db = await BancoApp.instancia.database;
    final linhas = await db.rawQuery('''SELECT e.*,
                p.nome AS criador_nome,
                p.username AS criador_username,
                l.latitude AS local_latitude,
                l.longitude AS local_longitude
           FROM cache_evento e
           LEFT JOIN cache_pessoa p ON p.id = e.criador_id
           LEFT JOIN cache_local l ON l.id = e.local_id
          ORDER BY CASE WHEN e.inicio_em IS NULL THEN 1 ELSE 0 END,
                   e.inicio_em ASC,
                   e.id ASC''');

    final convidados = await _carregarConvidados();
    return linhas
        .map((linha) => _montaEvento(linha, convidados, usuarioId))
        .toList();
  }

  Future<Evento?> carregarEvento(int id, {int? usuarioId}) async {
    final eventos = await carregarEventos(usuarioId: usuarioId);
    for (final evento in eventos) {
      if (evento.id == id) return evento;
    }
    return null;
  }

  Future<void> limpar() async {
    final db = await BancoApp.instancia.database;
    await db.transaction((txn) async {
      await txn.delete('cache_convidado');
      await txn.delete('cache_evento');
      await txn.delete('cache_local');
    });
  }

  Future<Map<int, List<ConvidadoEvento>>> _carregarConvidados() async {
    final db = await BancoApp.instancia.database;
    final linhas = await db.rawQuery('''SELECT c.*,
                p.nome AS usuario_nome,
                p.username AS usuario_username
           FROM cache_convidado c
           LEFT JOIN cache_pessoa p ON p.id = c.usuario_id
          ORDER BY CASE WHEN c.papel = 'CRIADOR' THEN 0 ELSE 1 END,
                   p.nome''');

    final porEvento = <int, List<ConvidadoEvento>>{};
    for (final linha in linhas) {
      final eventoId = linha['evento_id'] as int?;
      final usuarioId = linha['usuario_id'] as int?;
      if (eventoId == null || usuarioId == null) continue;

      final usuario = UsuarioResumo(
        id: usuarioId,
        nome: (linha['usuario_nome'] ?? 'Usuário').toString(),
        username: (linha['usuario_username'] ?? '').toString(),
      );
      porEvento
          .putIfAbsent(eventoId, () => [])
          .add(
            ConvidadoEvento(
              usuario: usuario,
              papel: (linha['papel'] ?? 'CONVIDADO').toString(),
              rsvp: RsvpStatus.fromApi(linha['rsvp']),
            ),
          );
    }
    return porEvento;
  }

  Evento _montaEvento(
    Map<String, dynamic> linha,
    Map<int, List<ConvidadoEvento>> convidadosPorEvento,
    int? usuarioId,
  ) {
    final base = Evento.fromMap(linha);
    final criadorId = base.criadorId;
    final criadorNome = linha['criador_nome'] as String?;
    final criadorUsername = linha['criador_username'] as String?;
    final criador = criadorId == null || criadorNome == null
        ? null
        : UsuarioResumo(
            id: criadorId,
            nome: criadorNome,
            username: criadorUsername ?? '',
          );

    final convidados =
        convidadosPorEvento[base.id] ?? const <ConvidadoEvento>[];
    var vou = 0;
    var talvez = 0;
    var semResposta = 0;
    RsvpStatus? meuRsvp;

    for (final convidado in convidados) {
      switch (convidado.rsvp) {
        case RsvpStatus.vou:
          vou++;
          break;
        case RsvpStatus.talvez:
          talvez++;
          break;
        case null:
          semResposta++;
          break;
      }
      if (convidado.usuario.id == usuarioId) {
        meuRsvp = convidado.rsvp;
      }
    }

    final souCriador = criadorId != null && criadorId == usuarioId;
    return base.copyWith(
      criador: criador,
      convidados: convidados,
      contagem: ContagemRsvp(
        vou: vou,
        talvez: talvez,
        semResposta: semResposta,
      ),
      meuRsvp: meuRsvp,
      souCriador: souCriador,
      podeConvidar: souCriador || base.permitirMembrosConvidar,
    );
  }

  Future<void> _salvarEvento(Transaction txn, Evento evento, int agora) async {
    final id = evento.id;
    if (id == null) return;

    final local = evento.local;
    if (local != null && local.id != null) {
      await txn.insert('cache_local', {
        ...local.toMap(),
        'atualizado_em': agora,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final criador = evento.criador;
    if (criador != null) {
      await _salvaPessoa(txn, criador, agora);
    }

    await txn.insert('cache_evento', {
      ...evento.toMap(),
      'atualizado_em': agora,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _salvarConvidados(
    Transaction txn,
    Evento evento,
    int agora,
  ) async {
    final eventoId = evento.id;
    if (eventoId == null) return;

    for (final convidado in evento.convidados) {
      await _salvaPessoa(txn, convidado.usuario, agora);
      await txn.insert('cache_convidado', {
        'evento_id': eventoId,
        'usuario_id': convidado.usuario.id,
        'convidado_por': convidado.convidadoPor?.id,
        'papel': convidado.papel,
        'rsvp': convidado.rsvp?.api,
        'atualizado_em': agora,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _salvaPessoa(
    Transaction txn,
    UsuarioResumo usuario,
    int agora,
  ) async {
    await txn.insert('cache_pessoa', {
      'id': usuario.id,
      'nome': usuario.nome,
      'username': usuario.username,
      'atualizado_em': agora,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
