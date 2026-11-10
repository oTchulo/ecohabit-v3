import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ecohabit/core/database/app_database.dart';
import 'package:ecohabit/models/domain.dart';
import 'package:ecohabit/repositories/activity_repository.dart';
import 'package:ecohabit/repositories/auth_repository.dart';
import 'package:ecohabit/services/impact_service.dart';
import 'package:ecohabit/services/password_service.dart';

class MemorySession implements SessionStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

// Mesma implementação PBKDF2; custo menor somente nos testes de integração.
class TestPasswords extends PasswordService {
  @override
  Future<String> derive(String password, String salt,
          [int rounds = PasswordService.iterations]) =>
      super.derive(password, salt, 1000);
}

void main() {
  sqfliteFfiInit();
  late Database db;
  late AuthRepository auth;
  late ActivityRepository repository;
  late DateTime now;
  late MemorySession session;
  Future<Account> user([String email = 'ana@example.com']) =>
      auth.register('Ana Silva', email, 'senha1234', 'senha1234');
  Future<int> record(int uid, int quantity, String operation,
          {int activity = 1}) =>
      repository.register(
          userId: uid,
          activityId: activity,
          quantity: quantity,
          actionReference: operation,
          operationId: operation);
  setUp(() async {
    db = await AppDatabase.open(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    session = MemorySession();
    auth = AuthRepository(db, session, passwords: TestPasswords());
    now = DateTime(2026, 11, 9, 12);
    repository = ActivityRepository(db, clock: () => now);
  });
  tearDown(() async {
    await db.close();
  });

  test('cadastro, hash com salt e início sem XP', () async {
    final account = await user();
    expect(account.name, 'Ana Silva');
    final row = (await db.query('usuarios')).single;
    expect(row['senha_hash'], isNot('senha1234'));
    expect(row['senha_salt'], isNotEmpty);
    expect((await repository.summary(account.id))['xp'], 0);
    expect(Level.forXp(0).number, 1);
    expect((await auth.restore())!.id, account.id);
  });
  test('e-mail único sem distinguir maiúsculas e espaços', () async {
    await user();
    await expectLater(user(' ANA@example.com '), throwsA(isA<DomainError>()));
    expect((await db.query('usuarios')).length, 1);
  });
  test('validação de nome, e-mail, senha e confirmação', () async {
    for (final values in [
      ['', 'a@b.com', '12345678', '12345678'],
      ['Ana', 'errado', '12345678', '12345678'],
      ['Ana', 'a@b.com', 'curta', 'curta'],
      ['Ana', 'a@b.com', '12345678', 'diferente']
    ]) {
      await expectLater(
          auth.register(values[0], values[1], values[2], values[3]),
          throwsA(isA<DomainError>()));
    }
    expect(await db.query('usuarios'), isEmpty);
  });
  test('login válido, inválido, sessão e logout', () async {
    final account = await user();
    await auth.logout();
    expect(await auth.restore(), isNull);
    expect((await auth.login('ANA@example.com', 'senha1234')).id, account.id);
    await expectLater(auth.login('ana@example.com', 'incorreta'),
        throwsA(isA<DomainError>()));
    await expectLater(auth.login('ninguem@example.com', 'senha1234'),
        throwsA(isA<DomainError>()));
  });
  test('alteração de senha exige senha atual', () async {
    final account = await user();
    await expectLater(
        auth.changePassword(account, 'errada', 'nova12345', 'nova12345'),
        throwsA(isA<DomainError>()));
    await auth.changePassword(account, 'senha1234', 'nova12345', 'nova12345');
    await expectLater(
        auth.login(account.email, 'senha1234'), throwsA(isA<DomainError>()));
    expect((await auth.login(account.email, 'nova12345')).id, account.id);
  });
  test('recuperação exige código secreto, rotaciona e impede reutilização',
      () async {
    final account = await user();
    final code = auth.lastRecoveryCode!;
    await expectLater(
        auth.recover(account.email, 'errado', 'nova12345', 'nova12345'),
        throwsA(isA<DomainError>()));
    final nextCode =
        await auth.recover(account.email, code, 'nova12345', 'nova12345');
    expect(nextCode, isNot(code));
    expect(await auth.restore(), isNull);
    await expectLater(
        auth.recover(account.email, code, 'senha1234', 'senha1234'),
        throwsA(isA<DomainError>()));
    expect((await auth.login(account.email, 'nova12345')).id, account.id);
    expect(
        (await db.query('recuperacao')).single['codigo_hash'], isNot(nextCode));
  });
  test('todos os limites das faixas', () async {
    final catalog = await repository.catalog();
    const quantities = [0, 1, 5, 6, 10, 11, 20, 21, 10000];
    expect(quantities.map(catalog[0].score),
        [0, 30, 30, 60, 60, 100, 100, 150, 150]);
    expect(quantities.map(catalog[1].score),
        [0, 25, 25, 50, 50, 100, 100, 150, 150]);
    expect([0, 1, 15, 16, 30, 31, 60, 61, 10000].map(catalog[2].score),
        [0, 10, 10, 25, 25, 50, 50, 80, 80]);
  });
  test('múltiplos registros acumulam 30 + 30 + 40 + 0 XP', () async {
    final u = await user();
    expect(await record(u.id, 4, 'a'), 30);
    expect(await record(u.id, 4, 'b'), 30);
    expect(await record(u.id, 4, 'c'), 40);
    expect(await record(u.id, 2, 'd'), 0);
    expect((await repository.history(u.id)).length, 4);
    expect((await repository.today(u.id))[1], 14);
    expect((await repository.summary(u.id))['xp'], 100);
  });
  test('limite configurável e faixas sem bônus inventados', () async {
    final u = await user();
    await db.update('atividades', {'limite_xp': 50},
        where: 'id = ?', whereArgs: [1]);
    expect(await record(u.id, 21, 'a'), 50);
    expect(await record(u.id, 100, 'b'), 0);
    expect(await record(u.id, 100, 'c', activity: 2), 150);
    expect(await record(u.id, 100, 'd', activity: 3), 80);
  });
  test('virada de dia reinicia quantidade e preserva XP', () async {
    final u = await user();
    now = DateTime(2026, 11, 9, 23, 59, 59);
    expect(await record(u.id, 4, 'a'), 30);
    now = DateTime(2026, 11, 10);
    expect(await repository.today(u.id), isEmpty);
    expect(await record(u.id, 4, 'b'), 30);
    expect((await repository.summary(u.id))['xp'], 60);
    final history = await repository.history(u.id);
    expect(history.map((r) => r['data_local']).toSet(),
        {'2026-11-09', '2026-11-10'});
  });
  test('idempotência e conflito entre operações', () async {
    final u = await user();
    expect(await record(u.id, 4, 'same'), 30);
    expect(await record(u.id, 4, 'same'), 30);
    expect((await repository.history(u.id)).length, 1);
    await expectLater(record(u.id, 5, 'same'), throwsA(isA<DomainError>()));
  });
  test('registros concorrentes não concedem XP duplicado', () async {
    final u = await user();
    final xp =
        await Future.wait(List.generate(10, (i) => record(u.id, 1, '$i')));
    expect(xp.reduce((a, b) => a + b), 60);
    expect((await repository.today(u.id))[1], 10);
    await Future.wait(List.generate(5, (_) => record(u.id, 1, 'duplicate')));
    expect((await repository.history(u.id)).length, 11);
    expect((await repository.summary(u.id))['xp'], 100);
  });
  test('isolamento entre usuários e atividades', () async {
    final a = await user(), b = await user('b@example.com');
    expect(await record(a.id, 4, 'a'), 30);
    expect(await record(b.id, 4, 'b'), 30);
    expect(await record(a.id, 4, 'c', activity: 2), 25);
    expect((await repository.summary(a.id))['xp'], 55);
  });
  test('quantidade inválida, atividade inexistente e integridade', () async {
    final u = await user();
    for (final q in [0, -1, 2147483648]) {
      await expectLater(record(u.id, q, '$q'), throwsA(isA<DomainError>()));
    }
    await expectLater(
        record(u.id, 1, 'bad', activity: 999), throwsA(isA<DomainError>()));
    await expectLater(record(999, 1, 'fk'), throwsA(isA<DatabaseException>()));
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    expect(await db.query('registros'), isEmpty);
  });
  test('níveis e progresso incluindo nível máximo', () {
    expect(
        [0, 199, 200, 499, 500, 999, 1000, 1999, 2000, 9999]
            .map((xp) => Level.forXp(xp).number),
        [1, 1, 2, 2, 3, 3, 4, 4, 5, 5]);
    expect(Level.forXp(350).progress(350), .5);
    expect(Level.forXp(9999).progress(9999), 1);
  });
  test('ranking geral, semana de segunda a domingo e desempate', () async {
    final a = await user(), b = await user('b@example.com');
    now = DateTime(2026, 11, 8, 23, 59);
    await record(a.id, 21, 'prev');
    now = DateTime(2026, 11, 9);
    await record(b.id, 4, 'current');
    expect((await repository.ranking()).first['id'], a.id);
    expect((await repository.ranking(weekly: true)).first['id'], b.id);
    await record(a.id, 4, 'tie');
    expect((await repository.ranking(weekly: true)).first['id'], a.id);
    now = DateTime(2026, 11, 16);
    expect(
        (await repository.ranking(weekly: true)).map((r) => r['xp']), [0, 0]);
  });
  test('ranking vazio', () async {
    expect(await repository.ranking(), isEmpty);
  });
  test('impacto com potência informada e fatores versionados', () async {
    final u = await user();
    await repository.register(
        userId: u.id,
        activityId: 3,
        quantity: 60,
        operationId: 'energy',
        watts: 10);
    final row = (await repository.history(u.id)).single;
    expect(row['kwh_estimado'], closeTo(.01, 1e-10));
    expect(row['co2_estimado'], isNull);
    expect(row['versao_fatores'], ImpactService.version);
    expect(row['potencia_watts'], 10);
    expect(ImpactService().estimate('garrafas_pet', 20).co2, isNull);
    expect(ImpactService().estimate('bicicleta', 20).co2, isNull);
    expect(ImpactService().estimate('luzes_apagadas', 60).kwh, isNull);
  });
  test('persistência após fechar e reabrir SQLite', () async {
    final directory = await Directory.systemTemp.createTemp('ecohabit_test_');
    final path = '${directory.path}/persist.db';
    final disk =
        await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    final diskAuth = AuthRepository(disk, session, passwords: TestPasswords());
    final u = await diskAuth.register(
        'Ana', 'persist@example.com', 'senha1234', 'senha1234');
    await ActivityRepository(disk).register(
        userId: u.id, activityId: 1, quantity: 4, operationId: 'disk');
    await disk.close();
    final reopened =
        await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    expect((await ActivityRepository(reopened).summary(u.id))['xp'], 30);
    expect((await AuthRepository(reopened, session).restore())!.email,
        'persist@example.com');
    await reopened.close();
    await directory.delete(recursive: true);
  });
  test('PBKDF2-SHA256 corresponde a vetor conhecido', () async {
    final hash = await PasswordService().derive('password', 'c2FsdA==', 1);
    expect(hash, 'Eg-2z_z4syxD5yJSVsT4N6hlSMkszDVICAWYfLcL4Xs=');
  });
}
