import 'package:sqflite/sqflite.dart';

import '../db.dart';
import '../models/amizade.dart';

class AmizadeDao {
  static const _statusAmigo = 'A';
  static const _statusRecebida = 'P_RECEBIDA';
  static const _statusEnviada = 'P_ENVIADA';

  Future<void> salvarAmigos(List<Amigo> amigos) async {
    final db = await BancoApp.instancia.database;
    final agora = DateTime.now().toUtc().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.delete(
        'cache_amizade',
        where: 'status = ?',
        whereArgs: [_statusAmigo],
      );

      for (final amigo in amigos) {
        await _salvaPessoa(txn, amigo.usuario, agora);
        await txn.insert('cache_amizade', {
          'id': amigo.amizadeId,
          'outro_usuario_id': amigo.usuario.id,
          'status': _statusAmigo,
          'atualizado_em': agora,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> salvarSolicitacoes(SolicitacoesAmizade solicitacoes) async {
    final db = await BancoApp.instancia.database;
    final agora = DateTime.now().toUtc().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.delete(
        'cache_amizade',
        where: 'status IN (?, ?)',
        whereArgs: [_statusRecebida, _statusEnviada],
      );

      for (final solicitacao in solicitacoes.recebidas) {
        await _salvaPessoa(txn, solicitacao.usuario, agora);
        await txn.insert('cache_amizade', {
          'id': solicitacao.id,
          'outro_usuario_id': solicitacao.usuario.id,
          'status': _statusRecebida,
          'atualizado_em': agora,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      for (final solicitacao in solicitacoes.enviadas) {
        await _salvaPessoa(txn, solicitacao.usuario, agora);
        await txn.insert('cache_amizade', {
          'id': solicitacao.id,
          'outro_usuario_id': solicitacao.usuario.id,
          'status': _statusEnviada,
          'atualizado_em': agora,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Amigo>> carregarAmigos() async {
    final db = await BancoApp.instancia.database;
    final linhas = await db.rawQuery(
      '''SELECT a.id AS amizade_id,
                p.id AS usuario_id,
                p.nome AS usuario_nome,
                p.username AS usuario_username
           FROM cache_amizade a
           JOIN cache_pessoa p ON p.id = a.outro_usuario_id
          WHERE a.status = ?
          ORDER BY p.nome''',
      [_statusAmigo],
    );

    return linhas
        .map(
          (linha) => Amigo(
            amizadeId: linha['amizade_id'] as int,
            usuario: UsuarioResumo(
              id: linha['usuario_id'] as int,
              nome: linha['usuario_nome'] as String,
              username: linha['usuario_username'] as String,
            ),
          ),
        )
        .toList();
  }

  Future<SolicitacoesAmizade> carregarSolicitacoes() async {
    final db = await BancoApp.instancia.database;
    final linhas = await db.rawQuery(
      '''SELECT a.id AS solicitacao_id,
                a.status AS status,
                p.id AS usuario_id,
                p.nome AS usuario_nome,
                p.username AS usuario_username
           FROM cache_amizade a
           JOIN cache_pessoa p ON p.id = a.outro_usuario_id
          WHERE a.status IN (?, ?)
          ORDER BY a.atualizado_em DESC''',
      [_statusRecebida, _statusEnviada],
    );

    final recebidas = <SolicitacaoAmizade>[];
    final enviadas = <SolicitacaoAmizade>[];

    for (final linha in linhas) {
      final solicitacao = SolicitacaoAmizade(
        id: linha['solicitacao_id'] as int,
        usuario: UsuarioResumo(
          id: linha['usuario_id'] as int,
          nome: linha['usuario_nome'] as String,
          username: linha['usuario_username'] as String,
        ),
      );
      if (linha['status'] == _statusRecebida) {
        recebidas.add(solicitacao);
      } else {
        enviadas.add(solicitacao);
      }
    }

    return SolicitacoesAmizade(recebidas: recebidas, enviadas: enviadas);
  }

  Future<void> limpar() async {
    final db = await BancoApp.instancia.database;
    await db.delete('cache_amizade');
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
