import '../models/pessoa.dart';
import '../db.dart';

class PessoaDao {
  Future<int> insert(Pessoa pessoa) async {
    final db = await BancoApp.instancia.database;

    return await db.insert('cache_pessoa', pessoa.toMap());
  }

  Future<List<Pessoa>> getAll() async {
    final db = await BancoApp.instancia.database;
    final List<Map<String, dynamic>> maps = await db.query('cache_pessoa');

    return maps.map((map) => Pessoa.fromMap(map)).toList();
  }

  Future<int> update(Pessoa pessoa) async {
    final db = await BancoApp.instancia.database;

    return await db.update(
      'cache_pessoa',
      pessoa.toMap(),
      where: 'id = ?',
      whereArgs: [pessoa.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await BancoApp.instancia.database;
    
    return await db.delete(
      'cache_pessoa',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}