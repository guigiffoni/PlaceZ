import '../models/evento.dart';
import '../db.dart';

class EventoDao {
  Future<int> insert(Evento evento) async {
    final db = await BancoApp.instancia.database;

    return await db.insert('evento', evento.toMap());
  }

  Future<List<Evento>> getAll() async {
    final db = await BancoApp.instancia.database;
    final List<Map<String, dynamic>> maps = await db.query('evento');

    return maps.map((map) => Evento.fromMap(map)).toList();
  }

  Future<List<Map<String, dynamic>>> getEventosComDetalhes() async {
    final db = await BancoApp.instancia.database;

    return await db.rawQuery(
      '''SELECT e.*, l.nome as nome_local, p.nome as nome_criador
      FROM evento e
      LEFT JOIN local l ON e.id_local = l.id
      LEFT JOIN pessoa p ON e.criado_por = p.id;'''
    );
  }

  Future<int> update(Evento evento) async {
    final db = await BancoApp.instancia.database;

    return await db.update(
      'evento',
      evento.toMap(),
      where: 'id = ?',
      whereArgs: [evento.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await BancoApp.instancia.database;
    
    return await db.delete(
      'evento',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}