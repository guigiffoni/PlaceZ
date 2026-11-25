import 'package:sqflite/sqflite.dart';

import '../db.dart';
import '../models/ranking_pessoa.dart';

/// Cache da ordem dos chips de pessoas do calendário.
class RankingPessoasDao {
  Future<void> salvar(List<PessoaRanking> pessoas) async {
    final db = await BancoApp.instancia.database;

    await db.transaction((txn) async {
      await txn.delete('cache_ranking_pessoas');
      for (var ordem = 0; ordem < pessoas.length; ordem++) {
        final pessoa = pessoas[ordem];
        await txn.insert('cache_ranking_pessoas', {
          'usuario_id': pessoa.usuarioId,
          'nome': pessoa.nome,
          'contagem': pessoa.contagem,
          'ordem': ordem,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<PessoaRanking>> carregar() async {
    final db = await BancoApp.instancia.database;
    final linhas = await db.query(
      'cache_ranking_pessoas',
      orderBy: 'ordem ASC',
    );
    return linhas.map(PessoaRanking.fromMap).toList();
  }

  Future<void> limpar() async {
    final db = await BancoApp.instancia.database;
    await db.delete('cache_ranking_pessoas');
  }
}
