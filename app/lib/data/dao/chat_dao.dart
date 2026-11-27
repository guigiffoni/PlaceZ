import 'package:sqflite/sqflite.dart';

import '../db.dart';
import '../models/conversa.dart';

/// Cache local das conversas e mensagens recentes.
class ChatDao {
  Future<void> salvarConversas(List<Conversa> conversas) async {
    final db = await BancoApp.instancia.database;
    await db.transaction((txn) async {
      await txn.delete('cache_conversa');
      for (final conversa in conversas) {
        await txn.insert(
          'cache_conversa',
          conversa.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Conversa>> carregarConversas() async {
    final db = await BancoApp.instancia.database;
    final linhas = await db.query(
      'cache_conversa',
      orderBy: 'atualizado_em DESC, id DESC',
    );
    return linhas.map(Conversa.fromMap).toList();
  }

  Future<void> salvarMensagens(List<Mensagem> mensagens) async {
    if (mensagens.isEmpty) return;
    final db = await BancoApp.instancia.database;
    await db.transaction((txn) async {
      for (final mensagem in mensagens) {
        await txn.insert(
          'cache_mensagem',
          mensagem.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Mensagem>> carregarMensagens(int conversaId) async {
    final db = await BancoApp.instancia.database;
    final linhas = await db.query(
      'cache_mensagem',
      where: 'conversa_id = ?',
      whereArgs: [conversaId],
      orderBy: 'id ASC',
      limit: 200,
    );
    return linhas.map(Mensagem.fromMap).toList();
  }

  Future<void> apagarConversa(int conversaId) async {
    final db = await BancoApp.instancia.database;
    await db.transaction((txn) async {
      await txn.delete(
        'cache_mensagem',
        where: 'conversa_id = ?',
        whereArgs: [conversaId],
      );
      await txn.delete(
        'cache_conversa',
        where: 'id = ?',
        whereArgs: [conversaId],
      );
    });
  }

  Future<void> limpar() async {
    final db = await BancoApp.instancia.database;
    await db.transaction((txn) async {
      await txn.delete('cache_mensagem');
      await txn.delete('cache_conversa');
    });
  }
}
