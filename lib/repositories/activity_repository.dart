import 'package:sqflite/sqflite.dart';
import '../models/domain.dart';
import '../services/impact_service.dart';

class ActivityRepository {
  final Database db;
  final DateTime Function() clock;
  final ImpactService impacts;
  ActivityRepository(this.db,
      {DateTime Function()? clock, ImpactService? impacts})
      : clock = clock ?? DateTime.now,
        impacts = impacts ?? ImpactService();
  Future<List<Activity>> catalog([DatabaseExecutor? transaction]) async {
    final executor = transaction ?? db;
    final rows =
        await executor.query('atividades', where: 'ativo = 1', orderBy: 'id');
    final bands =
        await executor.query('faixas_pontuacao', orderBy: 'quantidade_minima');
    return rows
        .map((r) => Activity(
            r['id'] as int,
            r['nome'] as String,
            r['categoria'] as String,
            r['unidade'] as String,
            r['limite_xp_diario'] as int,
            bands
                .where((b) => b['atividade_id'] == r['id'])
                .map((b) => Band(b['quantidade_minima'] as int,
                    b['quantidade_maxima'] as int?, b['xp'] as int))
                .toList()))
        .toList();
  }

  Future<Map<int, int>> today(int userId) async {
    final rows = await db.rawQuery(
        '''SELECT atividade_id, SUM(quantidade) AS total
      FROM registros WHERE usuario_id = ? AND data_local = ? GROUP BY atividade_id''',
        [userId, localDay(clock())]);
    return {for (final r in rows) r['atividade_id'] as int: r['total'] as int};
  }

  Future<int> register(
      {required int userId,
      required int activityId,
      required int quantity,
      required String operationId,
      double? watts}) async {
    if (quantity <= 0 || quantity > 2147483647) {
      throw const DomainError(
          'Informe uma quantidade inteira positiva, até 2147483647.');
    }
    if (operationId.trim().isEmpty) {
      throw const DomainError('Operação sem identificador.');
    }
    if (watts != null && (!watts.isFinite || watts <= 0)) {
      throw const DomainError('Potência inválida.');
    }
    return db.transaction((txn) async {
      final previous = await txn.query('registros',
          where: 'identificador_operacao = ?', whereArgs: [operationId]);
      if (previous.isNotEmpty) {
        final r = previous.single;
        if (r['usuario_id'] != userId ||
            r['atividade_id'] != activityId ||
            r['quantidade'] != quantity ||
            r['potencia_watts'] != watts) {
          throw const DomainError(
              'Identificador já utilizado em outra operação.');
        }
        return r['xp_concedido'] as int;
      }
      final activities = await catalog(txn);
      final matches = activities.where((a) => a.id == activityId);
      if (matches.isEmpty) throw const DomainError('Atividade indisponível.');
      final activity = matches.single;
      final now = clock();
      final rows = await txn.rawQuery(
          '''SELECT COALESCE(SUM(quantidade),0) AS quantidade,
        COALESCE(SUM(xp_concedido),0) AS xp FROM registros
        WHERE usuario_id = ? AND atividade_id = ? AND data_local = ?''',
          [userId, activityId, localDay(now)]);
      final before = rows.single['quantidade'] as int;
      final granted = rows.single['xp'] as int;
      // O total já concedido também protege contra excesso após mudanças de configuração.
      final delta = (activity.score(before + quantity) - granted)
          .clamp(0, activity.limit)
          .toInt();
      final impact = impacts.estimate(activityId, quantity, watts: watts);
      final rule = (await txn.query('configuracoes',
              where: 'chave = ?', whereArgs: ['versao_regra']))
          .single['valor'];
      await txn.insert('registros', {
        'usuario_id': userId,
        'atividade_id': activityId,
        'quantidade': quantity,
        'xp_concedido': delta,
        'co2_estimado': impact.co2,
        'kwh_estimado': impact.kwh,
        'potencia_watts': watts,
        'data_local': localDay(now),
        'criado_em': now.toUtc().toIso8601String(),
        'versao_regra': rule,
        'versao_fatores': ImpactService.version,
        'identificador_operacao': operationId
      });
      return delta;
    });
  }

  Future<Map<String, Object?>> summary(int userId) async => (await db.rawQuery(
          '''
    SELECT COALESCE(SUM(xp_concedido),0) AS xp, COUNT(*) AS acoes,
      SUM(co2_estimado) AS co2, SUM(kwh_estimado) AS kwh,
      COUNT(kwh_estimado) AS energia_calculada FROM registros WHERE usuario_id = ?''',
          [userId]))
      .single;
  Future<List<Map<String, Object?>>> history(int userId) => db.rawQuery('''
    SELECT r.*, a.nome, a.unidade FROM registros r JOIN atividades a ON a.id = r.atividade_id
    WHERE r.usuario_id = ? ORDER BY r.criado_em DESC, r.id DESC''', [userId]);
  Future<List<Map<String, Object?>>> ranking({bool weekly = false}) {
    final start = weekStart(clock());
    return db.rawQuery(
        '''SELECT u.id, u.nome,
      COALESCE(SUM(r.xp_concedido),0) AS xp,
      (SELECT COALESCE(SUM(t.xp_concedido),0) FROM registros t WHERE t.usuario_id=u.id) AS total_xp
      FROM usuarios u LEFT JOIN registros r ON r.usuario_id = u.id
      ${weekly ? 'AND r.data_local >= ? AND r.data_local < ?' : ''}
      GROUP BY u.id ORDER BY xp DESC, u.criado_em ASC, u.id ASC''',
        weekly
            ? [
                localDay(start),
                localDay(DateTime(start.year, start.month, start.day + 7))
              ]
            : []);
  }
}
