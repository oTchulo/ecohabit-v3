import 'dart:math';

class Account {
  final int id;
  final String name, email;
  const Account(this.id, this.name, this.email);
  factory Account.fromMap(Map<String, Object?> row) =>
      Account(row['id'] as int, row['nome'] as String, row['email'] as String);
}

class Band {
  final int min;
  final int? max;
  final int xp;
  const Band(this.min, this.max, this.xp);
}

class Activity {
  final int id, limit;
  final String name, category, unit, code, ruleVersion, actionGroup;
  final ScoringType type;
  final int ods;
  final List<Band> bands;
  const Activity(
      this.id, this.name, this.category, this.unit, this.limit, this.bands,
      {required this.code,
      required this.type,
      required this.actionGroup,
      this.ruleVersion = 'xp-v2',
      this.ods = 11});
  bool get requiresActionReference =>
      actionGroup == 'TRAJETO' || type == ScoringType.monthly;
  String periodKey(DateTime date) => switch (type) {
        ScoringType.daily => localDay(date),
        ScoringType.monthly => localDay(date).substring(0, 7),
        ScoringType.unique => 'VIDA',
      };
  void validate() {
    if (code.isEmpty || limit <= 0 || bands.isEmpty || bands.first.min != 1) {
      throw const DomainError(
          'Catálogo inconsistente: código, limite ou faixas inválidos.');
    }
    for (var i = 0; i < bands.length; i++) {
      final band = bands[i];
      if (band.xp <= 0 ||
          (band.max != null && band.max! < band.min) ||
          (i > 0 &&
              (bands[i - 1].max == null ||
                  band.min != bands[i - 1].max! + 1 ||
                  band.xp < bands[i - 1].xp))) {
        throw const DomainError(
            'Catálogo inconsistente: faixas devem ser contínuas e XP crescente.');
      }
    }
    if (type == ScoringType.unique) {
      if (bands.length != 1 || bands.single.min != 1 || bands.single.max != 1) {
        throw const DomainError(
            'Conquistas únicas devem aceitar apenas uma instalação.');
      }
    } else if (bands.last.max != null) {
      throw const DomainError(
          'A última faixa deve abranger todas as quantidades superiores.');
    }
  }

  int score(int quantity) {
    if (quantity <= 0) return 0;
    for (final band in bands) {
      if (quantity >= band.min && (band.max == null || quantity <= band.max!)) {
        return min(limit, band.xp);
      }
    }
    return 0;
  }

  int additional(int before, int quantity, {int? granted}) =>
      max(0, score(before + quantity) - (granted ?? score(before)));
}

enum ScoringType {
  daily('DIARIA', 'DIA', 'Diária'),
  monthly('PERIODICA', 'MES', 'Mensal'),
  unique('UNICA', 'VIDA', 'Conquista única');

  final String databaseValue, period, label;
  const ScoringType(this.databaseValue, this.period, this.label);
  static ScoringType parse(String value) =>
      values.firstWhere((type) => type.databaseValue == value);
}

class PeriodTotals {
  final int quantity, xp, records;
  const PeriodTotals({this.quantity = 0, this.xp = 0, this.records = 0});
  bool get completed => records > 0;
}

class Level {
  final int number, threshold;
  final String name;
  const Level(this.number, this.name, this.threshold);
  static const all = [
    Level(1, 'Iniciante Verde', 0),
    Level(2, 'Amigo da Natureza', 200),
    Level(3, 'Protetor Ambiental', 500),
    Level(4, 'Guardião Verde', 1000),
    Level(5, 'Mestre Sustentável', 2000),
  ];
  static Level forXp(int xp) => all.lastWhere((l) => xp >= l.threshold);
  double progress(int xp) => number == 5
      ? 1
      : ((xp - threshold) / (all[number].threshold - threshold))
          .clamp(0, 1)
          .toDouble();
}

String localDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime weekStart(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday + 1);

class DomainError implements Exception {
  final String message;
  const DomainError(this.message);
  @override
  String toString() => message;
}
