import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class BancoApp {
  static final BancoApp instancia = BancoApp._();
  BancoApp._();

  static const int versaoAtual = 2;

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
      version: versaoAtual,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _criarTabelas(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Fase 0: o SQLite é recriado do zero. Não há migração dos
        // eventos locais da versão 1, pois o Oracle passa a ser a verdade.
        await _recriar(db);
      },
      onDowngrade: (db, oldVersion, newVersion) async {
        await _recriar(db);
      },
    );
  }

  Future<void> _recriar(Database db) async {
    const tabelas = [
      // Tabelas legadas da versão 1.
      'pessoa_local',
      'evento',
      'local',
      'pessoa',
      // Tabelas de cache da versão 2.
      'cache_convidado',
      'cache_ranking_pessoas',
      'cache_mensagem',
      'cache_conversa',
      'cache_amizade',
      'cache_evento',
      'cache_local',
      'cache_pessoa',
      'sync_meta',
    ];

    for (final tabela in tabelas) {
      await db.execute('DROP TABLE IF EXISTS $tabela');
    }

    await _criarTabelas(db);
  }

  Future<void> _criarTabelas(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS cache_pessoa(
        id            INTEGER PRIMARY KEY,
        nome          TEXT NOT NULL,
        username      TEXT,
        atualizado_em INTEGER NOT NULL DEFAULT 0
      );''');

    await db.execute('''CREATE TABLE IF NOT EXISTS cache_amizade(
        id               INTEGER PRIMARY KEY,
        outro_usuario_id INTEGER NOT NULL,
        status           TEXT NOT NULL,
        atualizado_em    INTEGER NOT NULL DEFAULT 0
      );''');

    // Mantida para a seleção de local existente que ainda acompanha o
    // fluxo opcional de mapa/Nominatim. Não é fonte de verdade.
    await db.execute('''CREATE TABLE IF NOT EXISTS cache_local(
        id                INTEGER PRIMARY KEY,
        nome              TEXT,
        endereco          TEXT,
        numero            INTEGER,
        complemento       TEXT,
        nota              REAL,
        latitude          REAL,
        longitude         REAL,
        categoria         TEXT,
        distancia_metros  REAL,
        atualizado_em     INTEGER NOT NULL DEFAULT 0
      );''');

    await db.execute('''CREATE TABLE IF NOT EXISTS cache_evento(
        id                        INTEGER PRIMARY KEY,
        titulo                    TEXT NOT NULL,
        descricao                 TEXT,
        inicio_em                 INTEGER,
        fim_em                    INTEGER,
        local_id                  INTEGER,
        criador_id                INTEGER,
        privado                   INTEGER NOT NULL DEFAULT 1,
        permitir_membros_convidar INTEGER NOT NULL DEFAULT 0,
        status                    TEXT NOT NULL DEFAULT 'CONFIRMADO',
        criado_em                 INTEGER NOT NULL DEFAULT 0,
        atualizado_em             INTEGER NOT NULL DEFAULT 0,
        local_nome                TEXT,
        local_endereco            TEXT,
        local_categoria           TEXT,
        local_distancia_metros    REAL
      );''');

    await db.execute('''CREATE TABLE IF NOT EXISTS cache_convidado(
        evento_id     INTEGER NOT NULL,
        usuario_id    INTEGER NOT NULL,
        convidado_por INTEGER,
        papel         TEXT NOT NULL DEFAULT 'CONVIDADO',
        rsvp          TEXT,
        atualizado_em INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (evento_id, usuario_id)
      );''');

    await db.execute('''CREATE TABLE IF NOT EXISTS cache_conversa(
        id                INTEGER PRIMARY KEY,
        tipo              TEXT NOT NULL,
        evento_id         INTEGER,
        titulo            TEXT,
        outro_usuario_id  INTEGER,
        ultima_mensagem   TEXT,
        atualizado_em     INTEGER NOT NULL DEFAULT 0
      );''');

    await db.execute('''CREATE TABLE IF NOT EXISTS cache_mensagem(
        id          INTEGER PRIMARY KEY,
        conversa_id INTEGER NOT NULL,
        autor_id    INTEGER NOT NULL,
        texto       TEXT NOT NULL,
        criado_em   INTEGER NOT NULL
      );''');

    await db.execute('''CREATE TABLE IF NOT EXISTS cache_ranking_pessoas(
        usuario_id INTEGER PRIMARY KEY,
        nome       TEXT NOT NULL,
        contagem   INTEGER NOT NULL,
        ordem      INTEGER NOT NULL
      );''');

    await db.execute('''CREATE TABLE IF NOT EXISTS sync_meta(
        chave TEXT PRIMARY KEY,
        valor TEXT NOT NULL
      );''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS ix_cache_evento_inicio ON cache_evento(inicio_em);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS ix_cache_evento_local ON cache_evento(local_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS ix_cache_convidado_usuario ON cache_convidado(usuario_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS ix_cache_mensagem_conversa ON cache_mensagem(conversa_id, id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS ix_cache_pessoa_nome ON cache_pessoa(nome);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS ix_cache_local_nome ON cache_local(nome);',
    );
  }
}
