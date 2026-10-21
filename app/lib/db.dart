import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class BancoSqlite {
  late Database db;

  Future open() async {
    var dbPath = await getDatabasesPath();
    String path = join(dbPath, 'teste.db');

    db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          '''CREATE TABLE IF NOT EXISTS evento(
            id          INTEGER PRIMARY KEY,
            titulo      TEXT NOT NULL,
            marcado_em  INTEGER,
            criado_em   INTEGER DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(id_local) REFERENCES local(id),
            FOREIGN KEY(criado_por) REFERENCES pessoa(id)
          );'''
        );

        // precisamos implementar os grupos!
        // await db.execute(sql)

        await db.execute(
          '''CREATE TABLE IF NOT EXISTS pessoa(
            id    INTEGER PRIMARY KEY,
            nome  TEXT NOT NULL,
          );'''
        );

        await db.execute(
          '''CREATE TABLE IF NOT EXISTS local(
            id          INTEGER PRIMARY KEY,
            nome        TEXT,
            endereco    TEXT,
            numero      INTEGER,
            complemento TEXT
          );'''
        );

        await db.execute(
          '''CREATE TABLE IF NOT EXISTS pessoa_local(
            id_pessoa INTEGER NOT NULL,
            id_local  INTEGER NOT NULL,
            PRIMARY KEY (id_pessoa, id_local),
            FOREIGN KEY (id_pessoa) REFERENCES pessoa(id) ON DELETE CASCADE,
            FOREIGN KEY (id_local) REFERENCES local(id) ON DELETE CASCADE
          )'''
        );
      },
    );
  }
}

