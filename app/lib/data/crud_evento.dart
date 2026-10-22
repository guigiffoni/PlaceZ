import 'db.dart';
import 'modelo_evento.dart';

class CrudEvento {
  final BancoApp _bdProvedor = BancoApp.instancia;

  // CREATE
  Future<int> inserir(Evento evento) async {
    final db = await _bdProvedor.database;

    return await db.insert('evento', evento.toMap());
  }

  // READ TUDO
  Future<List<Evento>> getTudo() async {
    final db = await _bdProvedor.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'evento', 
      orderBy: 'data_hora_inicio ASC'
    );

    return List.generate(maps.length, (index) => Evento.fromMap(maps[index]));
  }

  // READ APENAS UM
  Future<Evento?> getPorId(int id) async {
    final db = await _bdProvedor.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'event', 
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return null;
    }

    return Evento.fromMap(maps[0]);
  }

  // UPDATE
  Future atualizar(Evento evento) async {
    final db = await _bdProvedor.database;

    return await db.update(
      'evento', 
      evento.toMap(),
      where: 'id = ?',
      whereArgs: [evento.id],
    );
  }

  Future deletar(int id) async {
    final db = await _bdProvedor.database;

    return await db.delete(
      'evento',
      where: 'id = ?',
      whereArgs: [id]
    );
  }
}