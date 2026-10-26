import '../models/pessoa.dart';
import '../db.dart';

class PessoaDao {
  Future<int> insert(Pessoa pessoa) async {
    final db = await BancoApp.instancia.database;

    return await db.insert('pessoa', pessoa.toMap());
  }

  Future<List<Pessoa>> getAll() async {
    final db = await BancoApp.instancia.database;
    final List<Map<String, dynamic>> maps = await db.query('pessoa');

    return maps.map((map) => Pessoa.fromMap(map)).toList();
  }

  Future<int> update(Pessoa pessoa) async {
    final db = await BancoApp.instancia.database;

    return await db.update(
      'pessoa',
      pessoa.toMap(),
      where: 'id = ?',
      whereArgs: [pessoa.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await BancoApp.instancia.database;
    
    return await db.delete(
      'pessoa',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}