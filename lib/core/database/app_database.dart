import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../constants/activity_catalog.dart';

class AppDatabase {
  static const version = 2;
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
              await seedV1(db);
              await migrateToV2(db);
            },
            onUpgrade: (db, oldVersion, newVersion) async {
              if (oldVersion == 1 && newVersion == 2) {
                await migrateToV2(db);
              } else {
                throw StateError(
                    'Migração não definida: $oldVersion → $newVersion');
              }
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
  static Future<void> seedV1(DatabaseExecutor db) async {
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

  /// Executada na transação de versão do sqflite: falhas revertem toda a migração.
  static Future<void> migrateToV2(DatabaseExecutor db) async {
    for (final statement in [
      "ALTER TABLE atividades ADD COLUMN codigo TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE atividades ADD COLUMN tipo_pontuacao TEXT NOT NULL DEFAULT 'DIARIA' CHECK(tipo_pontuacao IN ('DIARIA','PERIODICA','UNICA'))",
      "ALTER TABLE atividades ADD COLUMN periodo_pontuacao TEXT NOT NULL DEFAULT 'DIA' CHECK(periodo_pontuacao IN ('DIA','MES','VIDA'))",
      'ALTER TABLE atividades ADD COLUMN limite_xp INTEGER NOT NULL DEFAULT 0 CHECK(limite_xp>=0)',
      "ALTER TABLE atividades ADD COLUMN versao_regra TEXT NOT NULL DEFAULT 'xp-v2'",
      "ALTER TABLE atividades ADD COLUMN grupo_acao TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE registros ADD COLUMN tipo_pontuacao TEXT NOT NULL DEFAULT 'DIARIA' CHECK(tipo_pontuacao IN ('DIARIA','PERIODICA','UNICA'))",
      "ALTER TABLE registros ADD COLUMN periodo_pontuacao TEXT NOT NULL DEFAULT 'DIA' CHECK(periodo_pontuacao IN ('DIA','MES','VIDA'))",
      "ALTER TABLE registros ADD COLUMN chave_periodo TEXT NOT NULL DEFAULT ''",
      'ALTER TABLE registros ADD COLUMN referencia_acao TEXT CHECK(referencia_acao IS NULL OR length(referencia_acao) BETWEEN 1 AND 120)',
      "ALTER TABLE registros ADD COLUMN grupo_acao TEXT NOT NULL DEFAULT ''",
      "UPDATE atividades SET codigo = 'legado_' || id, limite_xp = limite_xp_diario, ativo = 0",
      "UPDATE atividades SET codigo = 'garrafas_pet' WHERE id = 1",
      "UPDATE atividades SET codigo = 'bicicleta' WHERE id = 2",
      "UPDATE atividades SET codigo = 'luzes_apagadas' WHERE id = 3",
      'CREATE UNIQUE INDEX atividades_codigo ON atividades(codigo)',
    ]) {
      await db.execute(statement);
    }
    for (final entry in sustainableCatalog) {
      final existing = await db
          .query('atividades', where: 'codigo = ?', whereArgs: [entry.code]);
      final values = <String, Object?>{
        'codigo': entry.code, 'nome': entry.name, 'categoria': entry.category,
        'unidade': entry.unit, 'ods': entry.ods, 'ativo': 1,
        'tipo_pontuacao': entry.type.databaseValue,
        'periodo_pontuacao': entry.type.period, 'limite_xp': entry.limit,
        // Coluna v1 mantida por compatibilidade de schema; leituras v2 usam limite_xp.
        'limite_xp_diario': entry.type.period == 'DIA' ? entry.limit : 0,
        'versao_regra': 'xp-v2', 'grupo_acao': entry.actionGroup
      };
      final int id;
      if (existing.isEmpty) {
        id = await db.insert('atividades', values);
      } else {
        id = existing.single['id'] as int;
        await db.update('atividades', values, where: 'id = ?', whereArgs: [id]);
      }
      await db.delete('faixas_pontuacao',
          where: 'atividade_id = ?', whereArgs: [id]);
      for (final band in entry.bands) {
        await db.insert('faixas_pontuacao', {
          'atividade_id': id,
          'quantidade_minima': band.min,
          'quantidade_maxima': band.max,
          'xp': band.xp
        });
      }
    }
    // Datas e XP históricos permanecem intactos. O período v1 era sempre diário.
    await db.execute(
        'UPDATE registros SET chave_periodo = data_local, grupo_acao = (SELECT grupo_acao FROM atividades WHERE id = registros.atividade_id)');
    await db.update('configuracoes', {'valor': 'xp-v2'},
        where: 'chave = ?', whereArgs: ['versao_regra']);
    for (final statement in [
      'CREATE INDEX registros_periodo ON registros(usuario_id, atividade_id, chave_periodo)',
      "CREATE UNIQUE INDEX registros_conquista_unica ON registros(usuario_id, atividade_id) WHERE tipo_pontuacao = 'UNICA'",
      'CREATE UNIQUE INDEX registros_acao_unica ON registros(usuario_id, grupo_acao, referencia_acao) WHERE referencia_acao IS NOT NULL',
      '''CREATE TRIGGER registros_validar_periodo BEFORE INSERT ON registros
        WHEN (NEW.tipo_pontuacao='DIARIA' AND (NEW.periodo_pontuacao!='DIA' OR NEW.chave_periodo!=NEW.data_local))
          OR (NEW.tipo_pontuacao='PERIODICA' AND (NEW.periodo_pontuacao!='MES' OR NEW.chave_periodo!=substr(NEW.data_local,1,7)))
          OR (NEW.tipo_pontuacao='UNICA' AND (NEW.periodo_pontuacao!='VIDA' OR NEW.chave_periodo!='VIDA' OR NEW.quantidade!=1))
        BEGIN SELECT RAISE(ABORT, 'Periodo ou conquista invalida'); END''',
    ]) {
      await db.execute(statement);
    }
  }
}
