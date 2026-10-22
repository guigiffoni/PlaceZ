import 'package:app/data/modelo_evento.dart';

import 'db.dart';


abstract class Identifiable {
  int? get id;
}

enum OrderByType { asc, desc }

class CrudGenerico<T extends Identifiable> {
  final String nomeTabela;
  final T Function(Map<String, dynamic> map) fromMap;
  final Map<String, dynamic> Function(T item) toMap;


  final BancoApp _dbProvider = BancoApp.instancia;

  CrudGenerico({
    required this.nomeTabela,
    required this.fromMap,
    required this.toMap,
  });

  Future<int> inserir(T item) async {
    final db = await _dbProvider.database;

    return await db.insert(nomeTabela, toMap(item));
  }

  Future<List<T>> getTudo({String? orderBy, OrderByType? type}) async {
    final db = await _dbProvider.database;
    final List<Map<String, dynamic>> maps = await db.query(
      nomeTabela,
      orderBy: '$orderBy = $type',
    );

    return List.generate(maps.length, (index) => fromMap(maps[index]));
  }

  Future<T?> getPorId(int id) async {
    final db = await _dbProvider.database;
    final List<Map<String, dynamic>> maps = await db.query(
      nomeTabela,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return null;
    }

    return fromMap(maps[0]);
  }

  Future atualizar(T item) async {
    final db = await _dbProvider.database;

    return await db.update(
      nomeTabela, 
      toMap(item),
      where: 'id = ?',
      whereArgs: [item.id]
    );
  }
}