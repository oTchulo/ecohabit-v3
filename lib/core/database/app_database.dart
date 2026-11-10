import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const version = 1;
  static Future<Database> open({DatabaseFactory? factory, String? path}) async {
    final f = factory ?? databaseFactory;
    return f.openDatabase(
        path ?? p.join(await f.getDatabasesPath(), 'ecohabit.db'),
        options: OpenDatabaseOptions(
            version: version,
            onConfigure: (db) async {
              await db.execute('PRAGMA foreign_keys = ON');
              final result = await db.rawQuery('PRAGMA foreign_keys');
              if (result.first.values.first != 1) {
                throw StateError('SQLite sem integridade referencial.');
              }
            },
            onCreate: (db, version) async {
              for (final sql in schema) {
                await db.execute(sql);
              }
              await seed(db);
            },
            onUpgrade: (db, oldVersion, newVersion) async {
              // Adicionar migrações incrementais aqui ao criar uma versão > 1.
              throw StateError(
                  'Migração não definida: $oldVersion → $newVersion');
            },
            onOpen: (db) async {
              if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
                throw StateError('Banco com referências inválidas.');
              }
            }));
  }

  static const schema = [
    '''CREATE TABLE usuarios (
      id INTEGER PRIMARY KEY, nome TEXT NOT NULL CHECK(length(trim(nome))>0),
      email TEXT NOT NULL COLLATE NOCASE UNIQUE, senha_hash TEXT NOT NULL,
      senha_salt TEXT NOT NULL, senha_iteracoes INTEGER NOT NULL CHECK(senha_iteracoes>0),
      bairro TEXT, criado_em TEXT NOT NULL)''',
    '''CREATE TABLE atividades (id INTEGER PRIMARY KEY, nome TEXT NOT NULL,
      categoria TEXT NOT NULL, unidade TEXT NOT NULL, ods INTEGER NOT NULL,
      limite_xp_diario INTEGER NOT NULL CHECK(limite_xp_diario>=0),
      ativo INTEGER NOT NULL DEFAULT 1 CHECK(ativo IN (0,1)))''',
    '''CREATE TABLE faixas_pontuacao (id INTEGER PRIMARY KEY,
      atividade_id INTEGER NOT NULL REFERENCES atividades(id),
      quantidade_minima INTEGER NOT NULL CHECK(quantidade_minima>0),
      quantidade_maxima INTEGER CHECK(quantidade_maxima>=quantidade_minima),
      xp INTEGER NOT NULL CHECK(xp>=0), UNIQUE(atividade_id, quantidade_minima))''',
    '''CREATE TABLE registros (id INTEGER PRIMARY KEY,
      usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
      atividade_id INTEGER NOT NULL REFERENCES atividades(id),
      quantidade INTEGER NOT NULL CHECK(typeof(quantidade)='integer' AND quantidade>0),
      xp_concedido INTEGER NOT NULL CHECK(xp_concedido>=0),
      co2_estimado REAL CHECK(co2_estimado>=0), kwh_estimado REAL CHECK(kwh_estimado>=0),
      potencia_watts REAL CHECK(potencia_watts>0),
      data_local TEXT NOT NULL, criado_em TEXT NOT NULL, versao_regra TEXT NOT NULL,
      versao_fatores TEXT NOT NULL, identificador_operacao TEXT NOT NULL UNIQUE)''',
    'CREATE INDEX registros_usuario_dia ON registros(usuario_id, data_local, atividade_id)',
    'CREATE INDEX registros_semana ON registros(data_local, usuario_id)',
    'CREATE TABLE configuracoes (chave TEXT PRIMARY KEY, valor TEXT NOT NULL)',
    '''CREATE TABLE recuperacao (usuario_id INTEGER PRIMARY KEY REFERENCES usuarios(id),
      codigo_hash TEXT NOT NULL, codigo_salt TEXT NOT NULL, iteracoes INTEGER NOT NULL)''',
  ];
  static Future<void> seed(DatabaseExecutor db) async {
    final names = [
      'Reciclagem de garrafas',
      'Bicicleta',
      'Economia de energia'
    ];
    final categories = ['Reciclagem', 'Mobilidade', 'Energia'];
    final units = ['garrafas', 'km', 'minutos'];
    for (var i = 0; i < 3; i++) {
      await db.insert('atividades', {
        'id': i + 1,
        'nome': names[i],
        'categoria': categories[i],
        'unidade': units[i],
        'ods': i == 2 ? 7 : 11,
        'limite_xp_diario': i == 2 ? 100 : 200
      });
      final bounds = i == 2 ? [1, 16, 31, 61] : [1, 6, 11, 21];
      final xp = i == 0
          ? [30, 60, 100, 150]
          : i == 1
              ? [25, 50, 100, 150]
              : [10, 25, 50, 80];
      for (var j = 0; j < 4; j++) {
        await db.insert('faixas_pontuacao', {
          'atividade_id': i + 1,
          'quantidade_minima': bounds[j],
          'quantidade_maxima': j == 3 ? null : bounds[j + 1] - 1,
          'xp': xp[j]
        });
      }
    }
    await db
        .insert('configuracoes', {'chave': 'versao_regra', 'valor': 'xp-v1'});
  }
}
