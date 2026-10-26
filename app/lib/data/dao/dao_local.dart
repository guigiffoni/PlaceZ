import '../models/local.dart';
import '../db.dart';

class DaoLocal {
  Future<int> insert(Local local) async {
    final db = await BancoApp.instancia.database;

    return await db.insert('local', local.toMap());
  }

  Future<List<Local>> getAll() async {
    final db = await BancoApp.instancia.database;
    final List<Map<String, dynamic>> maps = await db.query('local');

    return maps.map((map) => Local.fromMap(map)).toList();
  }

  Future<int> update(Local local) async {
    final db = await BancoApp.instancia.database;

    return await db.update(
      'local',
      local.toMap(),
      where: 'id = ?',
      whereArgs: [local.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await BancoApp.instancia.database;
    
    return await db.delete(
      'local',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}