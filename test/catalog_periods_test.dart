import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ecohabit/core/database/app_database.dart';
import 'package:ecohabit/models/domain.dart';
import 'package:ecohabit/repositories/activity_repository.dart';
import 'package:ecohabit/repositories/auth_repository.dart';
import 'ecohabit_test.dart' show MemorySession, TestPasswords;

// Matriz independente transcrita dos requisitos aprovados.
const approved = <String, (List<int>, List<int>, int, ScoringType, String)>{
  'bicicleta': (
    [1, 6, 11, 21],
    [25, 50, 100, 150],
    150,
    ScoringType.daily,
    'MOBILIDADE'
  ),
  'caminhada': (
    [1, 3, 6, 11],
    [20, 50, 90, 130],
    130,
    ScoringType.daily,
    'MOBILIDADE'
  ),
  'carro_eletrico': (
    [1, 11, 31],
    [20, 40, 60],
    60,
    ScoringType.daily,
    'MOBILIDADE'
  ),
  'transporte_publico': (
    [1, 2, 3],
    [15, 30, 45],
    45,
    ScoringType.daily,
    'MOBILIDADE'
  ),
  'carona': ([1, 2, 3], [15, 30, 45], 45, ScoringType.daily, 'MOBILIDADE'),
  'luzes_apagadas': (
    [1, 16, 31, 61],
    [10, 25, 50, 80],
    80,
    ScoringType.daily,
    'ENERGIA'
  ),
  'aparelhos_desligados': (
    [1, 3, 5, 9],
    [15, 30, 60, 90],
    90,
    ScoringType.daily,
    'ENERGIA'
  ),
  'energia_solar': ([1, 6, 16], [20, 45, 70], 70, ScoringType.daily, 'ENERGIA'),
  'instalar_solar': ([1], [200], 200, ScoringType.unique, 'ENERGIA'),
  'garrafas_pet': (
    [1, 6, 11, 21],
    [30, 60, 100, 150],
    150,
    ScoringType.daily,
    'RECICLAGEM'
  ),
  'latinhas': (
    [1, 6, 16, 31],
    [20, 50, 90, 140],
    140,
    ScoringType.daily,
    'RECICLAGEM'
  ),
  'papel_papelao': (
    [1, 3, 6, 11],
    [20, 45, 80, 120],
    120,
    ScoringType.daily,
    'RECICLAGEM'
  ),
  'eletronicos': (
    [1, 2, 3],
    [30, 55, 80],
    80,
    ScoringType.monthly,
    'RECICLAGEM'
  ),
  'banho_reduzido': (
    [1, 4, 7, 11],
    [20, 40, 70, 100],
    100,
    ScoringType.daily,
    'AGUA'
  ),
  'agua_reutilizada': (
    [1, 6, 16, 31],
    [20, 45, 80, 120],
    120,
    ScoringType.daily,
    'AGUA'
  ),
  'vazamento_corrigido': ([1, 2], [60, 100], 100, ScoringType.monthly, 'AGUA'),
  'copos_evitados': (
    [1, 3, 6, 11],
    [15, 35, 60, 90],
    90,
    ScoringType.daily,
    'CONSUMO'
  ),
  'sacola_reutilizavel': (
    [1, 2, 3, 5],
    [20, 35, 55, 75],
    75,
    ScoringType.daily,
    'CONSUMO'
  ),
  'arvores_plantadas': (
    [1, 2, 3],
    [50, 90, 120],
    120,
    ScoringType.monthly,
    'NATUREZA'
  ),
  'criar_composteira': ([1], [150], 150, ScoringType.unique, 'NATUREZA'),
};

void main() {
  sqfliteFfiInit();
  late Database db;
  late ActivityRepository repository;
  late AuthRepository auth;
  late Account account;
  late Map<String, Activity> catalog;
  late DateTime now;
  var sequence = 0;
  Future<int> record(String code, int quantity,
      {String? operation, String? reference, int? userId}) {
    final op = operation ?? 'op-${sequence++}';
    return repository.register(
        userId: userId ?? account.id,
        activityId: catalog[code]!.id,
        quantity: quantity,
        operationId: op,
        actionReference: reference ?? op);
  }

  setUp(() async {
    db = await AppDatabase.open(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    now = DateTime(2026, 11, 10, 12);
    sequence = 0;
    repository = ActivityRepository(db, clock: () => now);
    auth = AuthRepository(db, MemorySession(), passwords: TestPasswords());
    account = await auth.register(
        'Conta de teste', 'teste@example.invalid', 'teste12345', 'teste12345');
    catalog = {for (final a in await repository.catalog()) a.code: a};
  });
  tearDown(() async {
    await db.close();
  });

  test('catálogo contém exatamente 20 códigos, seis categorias e 66 faixas',
      () async {
    expect(catalog.keys.toSet(), approved.keys.toSet());
    expect(catalog.values.map((a) => a.category).toSet().length, 6);
    expect((await db.query('faixas_pontuacao')).length, 66);
    expect(catalog['garrafas_pet']!.id, 1);
    expect(catalog['bicicleta']!.id, 2);
    expect(catalog['luzes_apagadas']!.id, 3);
  });
  for (final entry in approved.entries) {
    test('${entry.key}: todas as faixas, limites e modalidade aprovados', () {
      final a = catalog[entry.key]!, expected = entry.value;
      expect(a.limit, expected.$3);
      expect(a.type, expected.$4);
      expect(a.category, expected.$5);
      expect(a.bands.map((b) => b.min), expected.$1);
      expect(a.bands.map((b) => b.xp), expected.$2);
      expect(a.score(0), 0);
      expect(a.score(-1), 0);
      for (var i = 0; i < expected.$1.length; i++) {
        final min = expected.$1[i], xp = expected.$2[i];
        expect(a.score(min), xp);
        if (i > 0) expect(a.score(min - 1), expected.$2[i - 1]);
        final max = i < expected.$1.length - 1
            ? expected.$1[i + 1] - 1
            : a.type == ScoringType.unique
                ? 1
                : null;
        expect(a.bands[i].max, max);
        if (max != null) expect(a.score(max), xp);
      }
      expect(a.score(1000000), a.type == ScoringType.unique ? 0 : a.limit);
      a.validate();
    });
  }
  test('as 20 atividades geram registros e ranking reais com total de 775 XP',
      () async {
    for (final code in approved.keys) {
      await record(code, 1);
    }
    expect((await repository.history(account.id)).length, 20);
    expect((await repository.summary(account.id))['xp'], 775);
    expect((await repository.ranking()).single['xp'], 775);
    expect((await repository.ranking(weekly: true)).single['xp'], 775);
    expect((await repository.periodTotals(account.id)).length, 20);
  });
  test(
      'mensal soma entre dias, preserva zero XP e reinicia somente no próximo mês',
      () async {
    expect(await record('eletronicos', 1), 30);
    now = DateTime(2026, 11, 11);
    expect(await record('eletronicos', 1), 25);
    expect(await record('eletronicos', 1), 25);
    expect(await record('eletronicos', 1), 0);
    final totals = (await repository
        .periodTotals(account.id))[catalog['eletronicos']!.id]!;
    expect(totals.quantity, 4);
    expect(totals.xp, 80);
    expect(totals.records, 4);
    now = DateTime(2026, 12, 1);
    expect(await repository.periodTotals(account.id), isEmpty);
    expect(await record('eletronicos', 1), 30);
    expect((await repository.summary(account.id))['xp'], 110);
    expect(
        (await repository.history(account.id))
            .map((r) => r['chave_periodo'])
            .toSet(),
        {'2026-11', '2026-12'});
  });
  test('limites de reparos e árvores são mensais e independentes', () async {
    expect(await record('vazamento_corrigido', 1), 60);
    expect(await record('vazamento_corrigido', 1), 40);
    expect(await record('vazamento_corrigido', 1), 0);
    expect(await record('arvores_plantadas', 1), 50);
    expect(await record('arvores_plantadas', 1), 40);
    expect(await record('arvores_plantadas', 1), 30);
    expect(await record('arvores_plantadas', 20), 0);
    expect((await repository.summary(account.id))['xp'], 220);
  });
  test('meia-noite e virada de ano mantêm o XP total e a chave correta',
      () async {
    now = DateTime(2026, 12, 31, 23, 59, 59);
    await record('garrafas_pet', 4);
    await record('eletronicos', 1);
    now = DateTime(2027, 1, 1);
    expect(await record('garrafas_pet', 4), 30);
    expect(await record('eletronicos', 1), 30);
    expect((await repository.summary(account.id))['xp'], 120);
    final history = await repository.history(account.id);
    expect(
        history
            .where((r) => r['tipo_pontuacao'] == 'DIARIA')
            .map((r) => r['chave_periodo'])
            .toSet(),
        {'2026-12-31', '2027-01-01'});
    expect(
        history
            .where((r) => r['tipo_pontuacao'] == 'PERIODICA')
            .map((r) => r['chave_periodo'])
            .toSet(),
        {'2026-12', '2027-01'});
  });
  for (final code in ['instalar_solar', 'criar_composteira']) {
    test('$code: conquista única por usuário em toda a vida', () async {
      final first =
          await record(code, 1, operation: 'unique', reference: 'instalacao-a');
      expect(first, catalog[code]!.limit);
      now = DateTime(2028, 1, 1);
      expect(
          await record(code, 1, operation: 'unique', reference: 'instalacao-a'),
          first);
      await expectLater(record(code, 1), throwsA(isA<DomainError>()));
      final other = await auth.register(
          'Outra conta', 'outra@example.invalid', 'teste12345', 'teste12345');
      expect(await record(code, 1, userId: other.id), first);
      expect(
          (await repository.periodTotals(account.id))[catalog[code]!.id]!
              .completed,
          isTrue);
    });
  }
  test('conquista única não aceita quantidade 2', () async {
    await expectLater(record('instalar_solar', 2), throwsA(isA<DomainError>()));
    expect(await repository.history(account.id), isEmpty);
  });
  test('corrida entre conquistas únicas resulta em uma única concessão',
      () async {
    final result = await Future.wait(List.generate(8, (i) async {
      try {
        return await record('criar_composteira', 1, operation: 'unique-$i');
      } on DomainError {
        return 0;
      }
    }));
    expect(result.where((xp) => xp > 0).length, 1);
    expect(result.reduce((a, b) => a + b), 150);
    expect((await repository.history(account.id)).length, 1);
  });
  test('mesmo trajeto não pode ser elétrico, carona ou bicicleta', () async {
    await record('carro_eletrico', 4, reference: '  Trecho   A ');
    await expectLater(record('carona', 1, reference: 'trecho a'),
        throwsA(isA<DomainError>()));
    now = DateTime(2026, 12, 1);
    await expectLater(record('bicicleta', 4, reference: 'trecho a'),
        throwsA(isA<DomainError>()));
    expect((await repository.history(account.id)).length, 1);
  });
  test('corrida entre atividades mutuamente exclusivas preserva um só trajeto',
      () async {
    final results =
        await Future.wait(['carro_eletrico', 'carona'].map((code) async {
      try {
        return await record(code, 1, reference: 'trajeto-simultaneo');
      } on DomainError {
        return 0;
      }
    }));
    expect(results.where((xp) => xp > 0).length, 1);
    expect((await repository.history(account.id)).length, 1);
  });
  test('mesmo reparo continua bloqueado em outro mês; novo evento é permitido',
      () async {
    await record('vazamento_corrigido', 1, reference: 'reparo-a');
    now = DateTime(2026, 12, 1);
    await expectLater(record('vazamento_corrigido', 1, reference: 'reparo-a'),
        throwsA(isA<DomainError>()));
    expect(await record('vazamento_corrigido', 1, reference: 'reparo-b'), 60);
    expect((await repository.summary(account.id))['xp'], 120);
  });
  test(
      'referência obrigatória em trajetos e eventos mensais; opcional nos demais',
      () async {
    for (final code in [
      'bicicleta',
      'eletronicos',
      'vazamento_corrigido',
      'arvores_plantadas'
    ]) {
      await expectLater(
          repository.register(
              userId: account.id,
              activityId: catalog[code]!.id,
              quantity: 1,
              operationId: code),
          throwsA(isA<DomainError>()));
    }
    expect(
        await repository.register(
            userId: account.id,
            activityId: 1,
            quantity: 1,
            operationId: 'optional'),
        30);
  });
  test('idempotência compara a referência e não permite trocar a carga',
      () async {
    await record('eletronicos', 1, operation: 'same', reference: 'evento');
    expect(
        await record('eletronicos', 1,
            operation: 'same', reference: ' EVENTO '),
        30);
    await expectLater(
        record('eletronicos', 1, operation: 'same', reference: 'outro'),
        throwsA(isA<DomainError>()));
    expect((await repository.history(account.id)).length, 1);
  });
  test(
      'ranking semanal usa XP concedido no instante, inclusive de atividades mensais',
      () async {
    now = DateTime(2026, 11, 8);
    await record('eletronicos', 1);
    now = DateTime(2026, 11, 9);
    await record('eletronicos', 1);
    await record('instalar_solar', 1);
    expect((await repository.ranking()).single['xp'], 255);
    expect((await repository.ranking(weekly: true)).single['xp'], 225);
  });
  test('SQLite impõe chave de período e unicidade, além da camada Dart',
      () async {
    await record('instalar_solar', 1);
    final row =
        Map<String, Object?>.from((await repository.history(account.id)).single)
          ..remove('id')
          ..remove('nome')
          ..remove('unidade')
          ..remove('codigo')
          ..remove('categoria');
    row['identificador_operacao'] = 'sql-duplicate';
    row['referencia_acao'] = null;
    await expectLater(
        db.insert('registros', row), throwsA(isA<DatabaseException>()));
    await record('eletronicos', 1);
    final monthly = Map<String, Object?>.from((await db.query('registros',
            where: 'tipo_pontuacao = ?', whereArgs: ['PERIODICA']))
        .single)
      ..remove('id');
    monthly['identificador_operacao'] = 'wrong-period';
    monthly['chave_periodo'] = '2020-01';
    monthly['referencia_acao'] = null;
    await expectLater(
        db.insert('registros', monthly), throwsA(isA<DatabaseException>()));
    expect((await repository.history(account.id)).length, 2);
  });
  test('faixas sobrepostas ou decrescentes são rejeitadas', () async {
    await db.update('faixas_pontuacao', {'quantidade_maxima': 6},
        where: 'atividade_id = ? AND quantidade_minima = ?', whereArgs: [1, 1]);
    await expectLater(repository.catalog(), throwsA(isA<DomainError>()));
    await db.update('faixas_pontuacao', {'quantidade_maxima': 5},
        where: 'atividade_id = ? AND quantidade_minima = ?', whereArgs: [1, 1]);
    await db.update('faixas_pontuacao', {'xp': 1},
        where: 'atividade_id = ? AND quantidade_minima = ?', whereArgs: [1, 6]);
    await expectLater(repository.catalog(), throwsA(isA<DomainError>()));
  });

  Future<(Directory, String, MemorySession, Account)> legacyDatabase(
      {bool failMigration = false}) async {
    final directory =
        await Directory.systemTemp.createTemp('ecohabit_migration_');
    final path = '${directory.path}/legacy.db', session = MemorySession();
    final old = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (database, version) async {
              for (final sql in AppDatabase.schema) {
                await database.execute(sql);
              }
              await AppDatabase.seedV1(database);
            }));
    final user = await AuthRepository(old, session, passwords: TestPasswords())
        .register(
            'Legado', 'legado@example.invalid', 'teste12345', 'teste12345');
    await old.insert('registros', {
      'usuario_id': user.id,
      'atividade_id': 1,
      'quantidade': 4,
      'xp_concedido': 30,
      'co2_estimado': null,
      'kwh_estimado': null,
      'data_local': '2026-10-31',
      'criado_em': '2026-11-01T02:59:00.000Z',
      'versao_regra': 'xp-v1',
      'versao_fatores': 'impacto-v1',
      'identificador_operacao': 'legacy'
    });
    if (failMigration) {
      await old.execute(
          "CREATE TRIGGER falha_controlada BEFORE INSERT ON faixas_pontuacao BEGIN SELECT RAISE(ABORT,'falha controlada'); END");
    }
    await old.close();
    return (directory, path, session, user);
  }

  test(
      'migração v1 → v2 preserva conta, sessão, data local, registros e XP sem duplicar catálogo',
      () async {
    final (directory, path, session, user) = await legacyDatabase();
    var upgraded =
        await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    var migrated = ActivityRepository(upgraded,
        clock: () => DateTime(2026, 10, 31, 23, 59, 59));
    expect(
        (await AuthRepository(upgraded, session, passwords: TestPasswords())
                .login(user.email, 'teste12345'))
            .id,
        user.id);
    expect((await AuthRepository(upgraded, session).restore())!.id, user.id);
    final row = (await migrated.history(user.id)).single;
    expect(row['id'], 1);
    expect(row['atividade_id'], 1);
    expect(row['codigo'], 'garrafas_pet');
    expect(row['xp_concedido'], 30);
    expect(row['data_local'], '2026-10-31');
    expect(row['chave_periodo'], '2026-10-31');
    expect(row['versao_regra'], 'xp-v1');
    expect(row['criado_em'], '2026-11-01T02:59:00.000Z');
    expect(
        await migrated.register(
            userId: user.id,
            activityId: 1,
            quantity: 4,
            operationId: 'after-migration'),
        30);
    expect((await migrated.summary(user.id))['xp'], 60);
    await upgraded.close();
    upgraded = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    migrated = ActivityRepository(upgraded);
    expect((await migrated.catalog()).length, 20);
    expect((await upgraded.query('faixas_pontuacao')).length, 66);
    expect((await migrated.summary(user.id))['xp'], 60);
    expect(await upgraded.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    expect(
        (await upgraded.rawQuery('PRAGMA user_version')).single.values.single,
        2);
    await upgraded.close();
    await directory.delete(recursive: true);
  });
  test(
      'falha na migração reverte DDL, catálogo e versão sem perder os dados v1',
      () async {
    final (directory, path, session, user) =
        await legacyDatabase(failMigration: true);
    await expectLater(AppDatabase.open(factory: databaseFactoryFfi, path: path),
        throwsA(isA<DatabaseException>()));
    final old = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(version: 1));
    expect((await old.rawQuery('PRAGMA user_version')).single.values.single, 1);
    expect(
        (await old.rawQuery('PRAGMA table_info(atividades)'))
            .any((row) => row['name'] == 'codigo'),
        isFalse);
    expect((await old.query('atividades')).length, 3);
    expect((await old.query('faixas_pontuacao')).length, 12);
    expect((await old.query('registros')).single['xp_concedido'], 30);
    expect((await AuthRepository(old, session).restore())!.id, user.id);
    await old.close();
    await directory.delete(recursive: true);
  });
}
