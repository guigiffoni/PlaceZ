import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class BancoApp {
  static final BancoApp instancia = BancoApp._();
  BancoApp._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }

    _db = await _initDB();

    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'placez.db');

    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        // Tabela de pessoas
        await db.execute(
          '''CREATE TABLE IF NOT EXISTS pessoa(
            id    INTEGER PRIMARY KEY,
            nome  TEXT NOT NULL,
          );'''
        );

        // Tabela de locais
        await db.execute(
          '''CREATE TABLE IF NOT EXISTS local(
            id          INTEGER PRIMARY KEY,
            nome        TEXT,
            endereco    TEXT,
            numero      INTEGER,
            complemento TEXT
          );'''
        );

        // Tabela de eventos
        await db.execute(
          '''CREATE TABLE IF NOT EXISTS evento(
            id                INTEGER PRIMARY KEY,
            titulo            TEXT NOT NULL,
            descricao         TEXT,
            data_hora_inicio  INTEGER,
            data_hora_fim     INTEGER,
            criado_em         INTEGER DEFAULT unixepoch(),
            id_local          INTEGER,
            criado_por        INTEGER,
            FOREIGN KEY(id_local) REFERENCES local(id),
            FOREIGN KEY(criado_por) REFERENCES pessoa(id)
          );'''
        );

        // precisamos implementar os grupos!
        // await db.execute(sql)

        // Tabela N:N entre pessoas e locais
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

